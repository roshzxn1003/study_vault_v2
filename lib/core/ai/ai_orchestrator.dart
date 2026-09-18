import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/citation_builder.dart';
import 'package:study_vault/core/ai/context_builder.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/ai/prompt_engine.dart';
import 'package:study_vault/core/ai/retriever.dart';
import 'package:study_vault/core/ai/semantic_search_service.dart';
import 'package:study_vault/features/documents/domain/services/document_processor.dart';

/// Central AI Orchestrator coordinating Retrieval (RAG), Context Assembly,
/// Prompt Engineering, LLM Generation, and Source Grounding.
class AiOrchestrator {
  final LlmService _llm;
  final Retriever _retriever;
  final DocumentProcessor? documentProcessor;
  final SemanticSearchService? searchService;

  AiOrchestrator(
    this._llm,
    this._retriever, {
    this.documentProcessor,
    this.searchService,
  });

  /// Progressively streams answers with RAG context and page citations.
  Stream<AiChunk> askStream(
    AiRequest request, {
    AiCancelToken? cancelToken,
    String? currentUserId,
  }) async* {
    final aiEnabled = await AiConfig.isAiEnabled();
    if (!aiEnabled) {
      yield const AiChunk(
        delta: "AI study features are currently disabled in Settings.",
        accumulatedText: "AI study features are currently disabled in Settings.",
        isDone: true,
      );
      return;
    }

    final userId = currentUserId ?? _resolveCurrentUserId();
    final vaultContextAllowed = await AiConfig.isVaultContextEnabled();

    List<RetrievedChunk> retrievedChunks = [];
    List<AiSource> sources = [];
    String contextText = request.context ?? '';

    // Step 1: Perform RAG retrieval if vault context is enabled and no explicit context was forced
    if (vaultContextAllowed && (request.context == null || request.context!.isEmpty)) {
      try {
        retrievedChunks = await _retriever.retrieve(RetrievalQuery(
          queryText: request.userMessage,
          userId: userId,
          workspaceId: request.workspaceContext,
          subjectId: request.subjectContext,
          topK: 4,
        ));

        if (retrievedChunks.isNotEmpty) {
          contextText = ContextBuilder.buildContextFromChunks(retrievedChunks);
          sources = CitationBuilder.buildCitations(retrievedChunks);
        }
      } catch (e) {
        debugPrint('RAG retrieval failed during stream orchestration: $e');
      }
    }

    // Step 2: Build mode-specific prompt using PromptEngine
    final systemPrompt = _buildSystemPromptForMode(request.mode, contextText, sources.isNotEmpty);
    final enrichedRequest = request.copyWith(
      context: contextText,
      systemInstruction: systemPrompt,
    );

    // Step 3: Stream tokens from LLM and attach verified citations to the final chunk
    final stream = _llm.generateStream(enrichedRequest, cancelToken: cancelToken);

    await for (final chunk in stream) {
      if (chunk.isDone) {
        yield AiChunk(
          delta: chunk.delta,
          accumulatedText: chunk.accumulatedText,
          isDone: true,
          sources: sources,
          modelUsed: chunk.modelUsed,
        );
      } else {
        yield chunk;
      }
    }
  }

  /// Synchronously processes an AI request with full RAG pipeline.
  Future<AiResponse> ask(AiRequest request, {String? currentUserId}) async {
    final aiEnabled = await AiConfig.isAiEnabled();
    if (!aiEnabled) {
      return AiResponse(
        answer: "AI study features are currently disabled in Settings.",
        sources: [],
        confidence: 0.0,
        usedContext: '',
      );
    }

    final userId = currentUserId ?? _resolveCurrentUserId();
    final vaultContextAllowed = await AiConfig.isVaultContextEnabled();

    List<RetrievedChunk> retrievedChunks = [];
    List<AiSource> sources = [];
    String contextText = request.context ?? '';

    if (vaultContextAllowed && (request.context == null || request.context!.isEmpty)) {
      try {
        retrievedChunks = await _retriever.retrieve(RetrievalQuery(
          queryText: request.userMessage,
          userId: userId,
          workspaceId: request.workspaceContext,
          subjectId: request.subjectContext,
          topK: 4,
        ));

        if (retrievedChunks.isNotEmpty) {
          contextText = ContextBuilder.buildContextFromChunks(retrievedChunks);
          sources = CitationBuilder.buildCitations(retrievedChunks);
        }
      } catch (e) {
        debugPrint('RAG retrieval failed during synchronous orchestration: $e');
      }
    }

    final systemPrompt = _buildSystemPromptForMode(request.mode, contextText, sources.isNotEmpty);
    final enrichedRequest = request.copyWith(
      context: contextText,
      systemInstruction: systemPrompt,
    );

    final rawResponse = await _llm.generate(enrichedRequest);

    return AiResponse(
      answer: rawResponse.answer,
      sources: sources,
      confidence: sources.isNotEmpty ? sources.first.similarity : 0.8,
      usedContext: contextText,
      modelUsed: rawResponse.modelUsed,
      finishReason: rawResponse.finishReason,
    );
  }

  /// Generates a structured multiple-choice quiz on a topic or material.
  Future<QuizSet> generateQuiz(
    String topic, {
    String? materialId,
    String? subjectId,
    int count = 5,
    String difficulty = 'medium',
  }) async {
    final userId = _resolveCurrentUserId();
    String context = '';
    final sources = <String>[];

    try {
      final chunks = await _retriever.retrieve(RetrievalQuery(
        queryText: topic,
        userId: userId,
        materialId: materialId,
        subjectId: subjectId,
        topK: 4,
      ));
      if (chunks.isNotEmpty) {
        context = ContextBuilder.buildContextFromChunks(chunks);
        sources.addAll(chunks.map((c) => '${c.materialTitle} (p. ${c.pageNumber})'));
      }
    } catch (_) {}

    final prompt = PromptEngine.buildQuizPrompt(
      topic: topic,
      context: context,
      count: count,
      difficulty: difficulty,
    );

    final response = await _llm.generate(AiRequest(
      mode: AiMode.quiz,
      userMessage: prompt,
      context: context,
      outputFormat: AiOutputFormat.json,
    ));

    final questions = _parseQuizJsonSafely(response.answer, difficulty);

    return QuizSet(
      id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      topic: topic,
      title: 'Practice Quiz: $topic',
      questions: questions,
      sources: sources.toSet().toList(),
    );
  }

  /// Generates an editable active-recall flashcard deck.
  Future<List<FlashcardItem>> generateFlashcards(
    String topic, {
    String? materialId,
    int count = 5,
    String difficulty = 'medium',
  }) async {
    final userId = _resolveCurrentUserId();
    String context = '';

    try {
      final chunks = await _retriever.retrieve(RetrievalQuery(
        queryText: topic,
        userId: userId,
        materialId: materialId,
        topK: 4,
      ));
      if (chunks.isNotEmpty) {
        context = ContextBuilder.buildContextFromChunks(chunks);
      }
    } catch (_) {}

    final prompt = PromptEngine.buildFlashcardsPrompt(
      topic: topic,
      context: context,
      count: count,
      difficulty: difficulty,
    );

    final response = await _llm.generate(AiRequest(
      mode: AiMode.flashcards,
      userMessage: prompt,
      context: context,
      outputFormat: AiOutputFormat.json,
    ));

    return _parseFlashcardsJsonSafely(response.answer, topic, difficulty);
  }

  /// Generates an exam study plan roadmap.
  Future<StudyPlan> generateStudyPlan({
    required String subject,
    required List<String> topics,
    required int days,
    required String dailyStudyTime,
    String? difficulty,
  }) async {
    final prompt = PromptEngine.buildStudyPlanPrompt(
      subject: subject,
      topics: topics,
      days: days,
      dailyStudyTime: dailyStudyTime,
      difficulty: difficulty,
    );

    final response = await _llm.generate(AiRequest(
      mode: AiMode.studyPlan,
      userMessage: prompt,
      outputFormat: AiOutputFormat.json,
    ));

    final items = _parseStudyPlanJsonSafely(response.answer, days, topics);

    return StudyPlan(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      title: '$days-Day Revision Plan: $subject',
      subject: subject,
      items: items,
      totalDays: days,
    );
  }

  /// Suggests organizational metadata for an imported file or note.
  Future<SmartOrganizationSuggestion> suggestOrganization(
    String documentContent, {
    String? rawFileName,
    List<String> existingSubjects = const [],
    List<String> existingFolders = const [],
    List<String> existingLabels = const [],
  }) async {
    final prompt = PromptEngine.buildOrganizationPrompt(
      documentContent: documentContent,
      rawFileName: rawFileName,
      existingSubjects: existingSubjects,
      existingFolders: existingFolders,
      existingLabels: existingLabels,
    );

    try {
      final response = await _llm.generate(AiRequest(
        mode: AiMode.classify,
        userMessage: prompt,
        outputFormat: AiOutputFormat.json,
      ));

      final cleaned = response.answer.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        return SmartOrganizationSuggestion.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('AI organization suggestion parsing fallback: $e');
    }

    // Heuristic Fallback if offline or parsing failed
    final title = rawFileName != null && rawFileName.isNotEmpty
        ? rawFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ')
        : 'Study Note';

    return SmartOrganizationSuggestion(
      suggestedTitle: title,
      suggestedSubject: existingSubjects.isNotEmpty ? existingSubjects.first : 'General Studies',
      suggestedFolder: existingFolders.isNotEmpty ? existingFolders.first : null,
      suggestedLabels: ['Notes'],
      confidence: 0.7,
      rationale: 'Generated from document naming and structure.',
    );
  }

  /// Triggers background document indexing via [DocumentProcessor].
  Future<void> indexMaterial(String materialId) async {
    if (documentProcessor != null) {
      await documentProcessor!.processDocument(materialId);
    }
  }

  // --- Legacy Interface Compatibility ---

  Future<AiResponse> askQuestion({
    required String query,
    required String mode,
    List<String>? history,
    String? imagePath,
  }) async {
    final attachments = <AiAttachment>[];
    if (imagePath != null && imagePath.isNotEmpty) {
      attachments.add(AiAttachment(
        filePath: imagePath,
        mimeType: imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg',
      ));
    }

    final chatHistory = history?.map((h) => AiChatMessage(role: 'user', content: h)).toList() ?? [];

    AiMode aiMode = AiMode.documentQa;
    if (mode == 'summarize') aiMode = AiMode.summary;
    if (mode == 'tutor') aiMode = AiMode.tutor;
    if (mode == 'quiz') aiMode = AiMode.quiz;
    if (mode == 'explain') aiMode = AiMode.explain;

    return ask(AiRequest(
      mode: aiMode,
      userMessage: query,
      attachments: attachments,
      conversationHistory: chatHistory,
    ));
  }

  // --- Helper Methods ---

  String _resolveCurrentUserId() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    return 'guest';
  }

  String _buildSystemPromptForMode(AiMode mode, String context, bool hasGroundedSources) {
    if (mode == AiMode.tutor) {
      return AiConfig.socraticTutorInstruction;
    }
    return AiConfig.academicSystemInstruction;
  }

  List<QuizQuestion> _parseQuizJsonSafely(String raw, String defaultDifficulty) {
    try {
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        final list = <QuizQuestion>[];
        for (final item in decoded) {
          if (item is Map) {
            final q = QuizQuestion.fromMap(Map<String, dynamic>.from(item));
            if (q.isValid) {
              list.add(q);
            }
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return [
      QuizQuestion(
        question: "What is the primary architectural principle governing this topic?",
        options: [
          "Preserving data invariants and consistent state transitions",
          "Ignoring race conditions during asynchronous execution",
          "Eliminating memory management overhead permanently",
          "Replacing transactional recovery with volatile storage",
        ],
        correctIndex: 0,
        explanation: "Maintaining state validity and invariants is fundamental to this domain.",
        difficulty: defaultDifficulty,
      ),
    ];
  }

  List<FlashcardItem> _parseFlashcardsJsonSafely(String raw, String topic, String difficulty) {
    try {
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        final list = <FlashcardItem>[];
        for (final item in decoded) {
          if (item is Map) {
            final card = FlashcardItem.fromMap(Map<String, dynamic>.from(item));
            if (card.isValid) {
              list.add(card);
            }
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    return [
      FlashcardItem(
        front: "What is the fundamental mechanism of $topic?",
        back: "A foundational architecture ensuring data consistency, isolation, and reliable execution.",
        topic: topic,
        difficulty: difficulty,
      ),
    ];
  }

  List<StudyPlanItem> _parseStudyPlanJsonSafely(String raw, int totalDays, List<String> topics) {
    try {
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        final list = <StudyPlanItem>[];
        for (final item in decoded) {
          if (item is Map) {
            list.add(StudyPlanItem.fromMap(Map<String, dynamic>.from(item)));
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    final list = <StudyPlanItem>[];
    for (int i = 1; i <= totalDays; i++) {
      final topic = topics.isNotEmpty ? topics[(i - 1) % topics.length] : 'Core Principles';
      list.add(StudyPlanItem(
        day: i,
        topic: topic,
        goal: 'Review $topic lecture notes and formulas',
        suggestedActivity: 'Solve 3 practice problems and review edge cases',
        revisionCheckpoint: 'Active recall check on $topic invariants',
        isCompleted: i == 1,
      ));
    }
    return list;
  }
}
