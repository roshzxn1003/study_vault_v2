import 'dart:typed_data';

/// The operation mode for an AI query or study action.
enum AiMode {
  tutor,
  documentQa,
  summary,
  quiz,
  flashcards,
  studyPlan,
  classify,
  organize,
  explain,
}

/// The desired output format from the AI provider.
enum AiOutputFormat {
  text,
  markdown,
  json,
  structuredSchema,
}

/// Task type for text and document embeddings.
enum AiEmbeddingTaskType {
  retrievalQuery,
  retrievalDocument,
  semanticSimilarity,
  classification,
  clustering,
}

/// Summary length / depth option.
enum SummaryDepth {
  quick,
  detailed,
  examRevision,
  keyPoints,
}

/// Typed representation of an attachment (image, diagram, scan) passed to multimodal AI.
class AiAttachment {
  final String? filePath;
  final String mimeType;
  final Uint8List? bytes;
  final String? label;

  const AiAttachment({
    this.filePath,
    required this.mimeType,
    this.bytes,
    this.label,
  });
}

/// Represents an individual message in an AI conversation session.
class AiChatMessage {
  final String? id;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final List<AiSource>? sources;
  final DateTime createdAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';

  AiChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.sources,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'role': role,
        'content': content,
        'sources': sources?.map((s) => s.toMap()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) => AiChatMessage(
        id: map['id'],
        role: map['role'] ?? 'user',
        content: map['content'] ?? '',
        sources: map['sources'] != null
            ? (map['sources'] as List)
                .map((s) => AiSource.fromMap(Map<String, dynamic>.from(s)))
                .toList()
            : null,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Typed source citation referencing user study material.
class AiSource {
  final String fileId;
  final String fileName;
  final int pageNumber;
  final String chunkId;
  final double similarity;
  final String? snippet;

  AiSource({
    required this.fileId,
    required this.fileName,
    required this.pageNumber,
    required this.chunkId,
    required this.similarity,
    this.snippet,
  });

  Map<String, dynamic> toMap() => {
        'file_id': fileId,
        'file_name': fileName,
        'page_number': pageNumber,
        'id': chunkId,
        'similarity': similarity,
        if (snippet != null) 'snippet': snippet,
      };

  factory AiSource.fromMap(Map<String, dynamic> map) {
    return AiSource(
      fileId: map['file_id'] ?? map['material_id'] ?? '',
      fileName: map['file_name'] ?? map['title'] ?? 'Unknown Document',
      pageNumber: map['page_number'] ?? 0,
      chunkId: map['id'] ?? map['chunk_id'] ?? '',
      similarity: (map['similarity'] as num?)?.toDouble() ?? 0.0,
      snippet: map['snippet'] ?? map['content'],
    );
  }
}

/// Fully-typed input request passed to LLM and Orchestrator.
class AiRequest {
  final AiMode mode;
  final String userMessage;
  final String? context;
  final List<AiAttachment> attachments;
  final String? workspaceContext;
  final String? subjectContext;
  final String? academicContext;
  final List<AiChatMessage> conversationHistory;
  final AiOutputFormat outputFormat;
  final String? systemInstruction;
  final int? maxTokens;
  final double? temperature;

  const AiRequest({
    required this.mode,
    required this.userMessage,
    this.context,
    this.attachments = const [],
    this.workspaceContext,
    this.subjectContext,
    this.academicContext,
    this.conversationHistory = const [],
    this.outputFormat = AiOutputFormat.markdown,
    this.systemInstruction,
    this.maxTokens,
    this.temperature,
  });

  AiRequest copyWith({
    AiMode? mode,
    String? userMessage,
    String? context,
    List<AiAttachment>? attachments,
    String? workspaceContext,
    String? subjectContext,
    String? academicContext,
    List<AiChatMessage>? conversationHistory,
    AiOutputFormat? outputFormat,
    String? systemInstruction,
    int? maxTokens,
    double? temperature,
  }) {
    return AiRequest(
      mode: mode ?? this.mode,
      userMessage: userMessage ?? this.userMessage,
      context: context ?? this.context,
      attachments: attachments ?? this.attachments,
      workspaceContext: workspaceContext ?? this.workspaceContext,
      subjectContext: subjectContext ?? this.subjectContext,
      academicContext: academicContext ?? this.academicContext,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      outputFormat: outputFormat ?? this.outputFormat,
      systemInstruction: systemInstruction ?? this.systemInstruction,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }
}

/// Progressive token/content chunk emitted during streaming responses.
class AiChunk {
  final String delta;
  final String accumulatedText;
  final bool isDone;
  final List<AiSource>? sources;
  final String? modelUsed;

  const AiChunk({
    required this.delta,
    required this.accumulatedText,
    this.isDone = false,
    this.sources,
    this.modelUsed,
  });
}

/// Complete aggregated AI response returned on synchronous or completed calls.
class AiResponse {
  final String answer;
  final List<AiSource> sources;
  final double confidence;
  final String usedContext;
  final String modelUsed;
  final String? finishReason;

  AiResponse({
    required this.answer,
    required this.sources,
    required this.confidence,
    required this.usedContext,
    this.modelUsed = 'gemini-1.5-flash',
    this.finishReason,
  });
}

/// Typed input for embedding generation.
class AiEmbeddingInput {
  final String text;
  final AiEmbeddingTaskType taskType;
  final String? title;

  const AiEmbeddingInput({
    required this.text,
    this.taskType = AiEmbeddingTaskType.retrievalDocument,
    this.title,
  });
}

/// Structured Multiple-Choice Quiz Question.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty;
  final List<String> sources;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.difficulty = 'medium',
    this.sources = const [],
  });

  bool get isValid =>
      question.trim().isNotEmpty &&
      options.length == 4 &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      explanation.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
        'difficulty': difficulty,
        'sources': sources,
      };

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'] as List? ?? [];
    final opts = rawOptions.map((e) => e.toString().trim()).toList();
    final rawIndex = (map['correctIndex'] as num?)?.toInt() ?? 0;
    return QuizQuestion(
      question: map['question']?.toString().trim() ?? '',
      options: opts,
      correctIndex: rawIndex.clamp(0, opts.isNotEmpty ? opts.length - 1 : 0),
      explanation: map['explanation']?.toString().trim() ?? '',
      difficulty: map['difficulty']?.toString().trim() ?? 'medium',
      sources: (map['sources'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Set of generated quiz questions for a topic/material.
class QuizSet {
  final String id;
  final String topic;
  final String title;
  final List<QuizQuestion> questions;
  final List<String> sources;
  final DateTime createdAt;

  QuizSet({
    required this.id,
    required this.topic,
    required this.title,
    required this.questions,
    this.sources = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'topic': topic,
        'title': title,
        'questions': questions.map((q) => q.toMap()).toList(),
        'sources': sources,
        'created_at': createdAt.toIso8601String(),
      };

  factory QuizSet.fromMap(Map<String, dynamic> map) {
    final rawQuestions = map['questions'] as List? ?? [];
    return QuizSet(
      id: map['id']?.toString() ?? '',
      topic: map['topic']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map((q) => QuizQuestion.fromMap(q))
          .toList(),
      sources: (map['sources'] as List?)?.map((s) => s.toString()).toList() ?? [],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}

/// Typed high-yield Flashcard item.
class FlashcardItem {
  final String? id;
  final String front;
  final String back;
  final String topic;
  final String difficulty;
  final String? sourceReference;

  const FlashcardItem({
    this.id,
    required this.front,
    required this.back,
    required this.topic,
    this.difficulty = 'medium',
    this.sourceReference,
  });

  bool get isValid => front.trim().isNotEmpty && back.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'front': front,
        'back': back,
        'topic': topic,
        'difficulty': difficulty,
        if (sourceReference != null) 'source_reference': sourceReference,
      };

  factory FlashcardItem.fromMap(Map<String, dynamic> map) => FlashcardItem(
        id: map['id'],
        front: map['front'] ?? '',
        back: map['back'] ?? '',
        topic: map['topic'] ?? '',
        difficulty: map['difficulty'] ?? 'medium',
        sourceReference: map['source_reference'],
      );
}

/// Individual day in an AI Study Plan.
class StudyPlanItem {
  final int day;
  final String topic;
  final String goal;
  final String suggestedActivity;
  final String revisionCheckpoint;
  final bool isCompleted;

  const StudyPlanItem({
    required this.day,
    required this.topic,
    required this.goal,
    required this.suggestedActivity,
    required this.revisionCheckpoint,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'day': day,
        'topic': topic,
        'goal': goal,
        'suggestedActivity': suggestedActivity,
        'revisionCheckpoint': revisionCheckpoint,
        'isCompleted': isCompleted,
      };

  factory StudyPlanItem.fromMap(Map<String, dynamic> map) => StudyPlanItem(
        day: (map['day'] as num?)?.toInt() ?? 1,
        topic: map['topic']?.toString() ?? '',
        goal: map['goal']?.toString() ?? '',
        suggestedActivity: map['suggestedActivity']?.toString() ??
            map['tasks']?.toString() ??
            '',
        revisionCheckpoint: map['revisionCheckpoint']?.toString() ?? '',
        isCompleted: map['isCompleted'] == true,
      );
}

/// Overall AI Study Plan roadmap.
class StudyPlan {
  final String id;
  final String title;
  final String subject;
  final List<StudyPlanItem> items;
  final int totalDays;
  final DateTime createdAt;

  StudyPlan({
    required this.id,
    required this.title,
    required this.subject,
    required this.items,
    required this.totalDays,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subject': subject,
        'items': items.map((i) => i.toMap()).toList(),
        'totalDays': totalDays,
        'created_at': createdAt.toIso8601String(),
      };

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] ?? map['days']) as List? ?? [];
    return StudyPlan(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => StudyPlanItem.fromMap(i))
          .toList(),
      totalDays: (map['totalDays'] as num?)?.toInt() ?? rawItems.length,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}

/// AI Smart Organization Suggestion for newly imported files or unfiled notes.
class SmartOrganizationSuggestion {
  final String suggestedTitle;
  final String suggestedSubject;
  final String? suggestedFolder;
  final List<String> suggestedLabels;
  final double confidence;
  final String rationale;

  const SmartOrganizationSuggestion({
    required this.suggestedTitle,
    required this.suggestedSubject,
    this.suggestedFolder,
    this.suggestedLabels = const [],
    this.confidence = 0.85,
    this.rationale = 'Based on document header and conceptual analysis.',
  });

  Map<String, dynamic> toMap() => {
        'suggestedTitle': suggestedTitle,
        'suggestedSubject': suggestedSubject,
        'suggestedFolder': suggestedFolder,
        'suggestedLabels': suggestedLabels,
        'confidence': confidence,
        'rationale': rationale,
      };

  factory SmartOrganizationSuggestion.fromMap(Map<String, dynamic> map) =>
      SmartOrganizationSuggestion(
        suggestedTitle: map['suggestedTitle'] ?? 'Study Notes',
        suggestedSubject: map['suggestedSubject'] ?? 'General Studies',
        suggestedFolder: map['suggestedFolder'],
        suggestedLabels: (map['suggestedLabels'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.8,
        rationale: map['rationale'] ?? '',
      );
}
