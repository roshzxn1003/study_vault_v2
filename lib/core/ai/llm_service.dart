import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';

/// Typed exception for AI service operations.
class AiServiceException implements Exception {
  final String code;
  final String message;
  final dynamic originalError;

  const AiServiceException({
    required this.code,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'AiServiceException($code): $message';
}

/// Token used to cooperatively signal cancellation for streaming AI calls.
class AiCancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Abstract AI LLM Service.
/// Decouples Study Vault features from any direct Gemini SDK dependency.
abstract class LlmService {
  /// Progressively streams generated tokens for an [AiRequest].
  Stream<AiChunk> generateStream(AiRequest request, {AiCancelToken? cancelToken});

  /// Synchronously generates a complete [AiResponse] for an [AiRequest].
  Future<AiResponse> generate(AiRequest request);

  /// Checks if AI service is ready (has valid API key and connectivity).
  Future<bool> isAvailable();

  // --- Convenience legacy bridge methods ---
  Future<String> generateAnswer({
    required String query,
    required String context,
    List<String>? history,
    String? imagePath,
  });

  Future<String> generateSummary({
    required String context,
  });

  Future<String> generateQuestions({
    required String context,
    int count = 3,
  });

  Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String topic,
    String? context,
    int count = 5,
  });

  Future<List<Map<String, String>>> generateFlashcardDeck({
    required String topic,
    String? context,
    int count = 5,
  });

  Future<String> generateTutorStep({
    required String topic,
    required String currentStep,
    required String userPrompt,
  });

  Future<List<Map<String, dynamic>>> generateExamMilestones({
    required String subject,
    required List<String> topics,
    required int days,
    required String studyTime,
    required String difficulty,
  });
}

/// Official Google Generative AI (Gemini) Implementation of [LlmService].
class GeminiLlmService implements LlmService {
  @override
  Future<bool> isAvailable() async {
    final key = await AiConfig.getApiKey();
    return key.isNotEmpty;
  }

  @override
  Stream<AiChunk> generateStream(
    AiRequest request, {
    AiCancelToken? cancelToken,
  }) async* {
    final apiKey = await AiConfig.getApiKey();
    if (apiKey.isEmpty) {
      throw const AiServiceException(
        code: 'NO_API_KEY',
        message: 'Google Gemini API key not configured. Add your key in Settings to activate live AI reasoning.',
      );
    }

    final selectedModel = await AiConfig.getSelectedModel();
    final candidateModels = [
      selectedModel,
      ...AiConfig.fallbackModels.where((m) => m != selectedModel),
    ];

    Object? lastError;

    for (final modelName in candidateModels) {
      if (cancelToken?.isCancelled == true) return;

      try {
        final contents = await _buildContentList(request);
        final generationConfig = GenerationConfig(
          temperature: request.temperature ?? AiConfig.defaultTemperature,
          maxOutputTokens: request.maxTokens ?? AiConfig.defaultMaxTokens,
          responseMimeType: request.outputFormat == AiOutputFormat.json ? 'application/json' : null,
        );

        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: generationConfig,
          systemInstruction: Content.system(request.systemInstruction ?? AiConfig.academicSystemInstruction),
        );

        final responseStream = model.generateContentStream(contents);
        final accumulated = StringBuffer();

        await for (final responseChunk in responseStream) {
          if (cancelToken?.isCancelled == true) {
            return;
          }

          final text = responseChunk.text ?? '';
          if (text.isNotEmpty) {
            accumulated.write(text);
            yield AiChunk(
              delta: text,
              accumulatedText: accumulated.toString(),
              isDone: false,
              modelUsed: modelName,
            );
          }
        }

        // Final completion chunk
        yield AiChunk(
          delta: '',
          accumulatedText: accumulated.toString(),
          isDone: true,
          modelUsed: modelName,
        );
        return; // Success, exit fallback loop
      } catch (e) {
        lastError = e;
        debugPrint('Gemini stream failed on model $modelName: $e');

        // Check if error is unrecoverable (e.g. invalid key or blocked prompt)
        if (_isUnrecoverableError(e)) {
          throw _mapToAiServiceException(e);
        }
      }
    }

    throw _mapToAiServiceException(lastError);
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final apiKey = await AiConfig.getApiKey();
    if (apiKey.isEmpty) {
      throw const AiServiceException(
        code: 'NO_API_KEY',
        message: 'Google Gemini API key not configured. Add your key in Settings.',
      );
    }

    final selectedModel = await AiConfig.getSelectedModel();
    final candidateModels = [
      selectedModel,
      ...AiConfig.fallbackModels.where((m) => m != selectedModel),
    ];

    Object? lastError;

    for (final modelName in candidateModels) {
      try {
        final contents = await _buildContentList(request);
        final generationConfig = GenerationConfig(
          temperature: request.temperature ?? AiConfig.defaultTemperature,
          maxOutputTokens: request.maxTokens ?? AiConfig.defaultMaxTokens,
          responseMimeType: request.outputFormat == AiOutputFormat.json ? 'application/json' : null,
        );

        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: generationConfig,
          systemInstruction: Content.system(request.systemInstruction ?? AiConfig.academicSystemInstruction),
        );

        final response = await model.generateContent(contents).timeout(AiConfig.timeout);
        final text = response.text?.trim() ?? '';

        return AiResponse(
          answer: text,
          sources: [],
          confidence: 0.9,
          usedContext: request.context ?? '',
          modelUsed: modelName,
          finishReason: response.candidates.isNotEmpty
              ? response.candidates.first.finishReason?.toString()
              : null,
        );
      } catch (e) {
        lastError = e;
        debugPrint('Gemini generateContent failed on model $modelName: $e');
        if (_isUnrecoverableError(e)) {
          throw _mapToAiServiceException(e);
        }
      }
    }

    throw _mapToAiServiceException(lastError);
  }

  // --- Content & Multi-modal preparation ---

  Future<List<Content>> _buildContentList(AiRequest request) async {
    final parts = <Part>[];

    // Attachments (Images, scanned notes, diagrams)
    for (final att in request.attachments) {
      if (att.bytes != null && att.bytes!.isNotEmpty) {
        parts.add(DataPart(att.mimeType, att.bytes!));
      } else if (att.filePath != null && File(att.filePath!).existsSync()) {
        final bytes = await File(att.filePath!).readAsBytes();
        final mime = att.filePath!.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        parts.add(DataPart(mime, bytes));
      }
    }

    // Context & History prompt framing
    final buffer = StringBuffer();
    if (request.academicContext != null && request.academicContext!.isNotEmpty) {
      buffer.writeln('### Academic Domain & Course Context:\n${request.academicContext}\n');
    }
    if (request.subjectContext != null && request.subjectContext!.isNotEmpty) {
      buffer.writeln('### Subject:\n${request.subjectContext}\n');
    }
    if (request.context != null &&
        request.context!.trim().isNotEmpty &&
        !request.context!.contains('No relevant context')) {
      buffer.writeln('### Grounded Vault Context / Source Material:\n${request.context}\n');
    }

    if (request.conversationHistory.isNotEmpty) {
      buffer.writeln('### Recent Conversation:');
      for (final msg in request.conversationHistory.take(6)) {
        buffer.writeln('${msg.isUser ? "Student" : "AI"}: ${msg.content}');
      }
      buffer.writeln();
    }

    buffer.writeln('### Student Message / Query:');
    buffer.writeln(request.userMessage);

    parts.add(TextPart(buffer.toString()));

    return [Content.multi(parts)];
  }

  bool _isUnrecoverableError(Object? error) {
    if (error == null) return false;
    final errStr = error.toString().toLowerCase();
    return errStr.contains('api_key_invalid') ||
        errStr.contains('invalid api key') ||
        errStr.contains('permission_denied') ||
        errStr.contains('unsupported user location');
  }

  AiServiceException _mapToAiServiceException(Object? error) {
    if (error == null) {
      return const AiServiceException(
        code: 'UNKNOWN',
        message: 'An unknown error occurred while communicating with Gemini.',
      );
    }
    final str = error.toString();
    if (str.toLowerCase().contains('api key') || str.toLowerCase().contains('unauthorized')) {
      return AiServiceException(
        code: 'INVALID_API_KEY',
        message: 'The configured Google Gemini API key appears to be invalid.',
        originalError: error,
      );
    }
    if (str.toLowerCase().contains('quota') || str.toLowerCase().contains('rate limit') || str.contains('429')) {
      return AiServiceException(
        code: 'RATE_LIMIT',
        message: 'AI service is temporarily busy (rate limit reached). Please try again shortly.',
        originalError: error,
      );
    }
    if (str.toLowerCase().contains('timeout')) {
      return AiServiceException(
        code: 'TIMEOUT',
        message: 'AI request timed out. Please check your network connection.',
        originalError: error,
      );
    }
    if (str.toLowerCase().contains('socket') || str.toLowerCase().contains('network') || str.toLowerCase().contains('offline')) {
      return AiServiceException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach Gemini servers. Cloud AI is unavailable while offline.',
        originalError: error,
      );
    }
    return AiServiceException(
      code: 'PROVIDER_ERROR',
      message: 'AI service encountered an issue: $str',
      originalError: error,
    );
  }

  // --- Convenience Legacy Implementations ---

  @override
  Future<String> generateAnswer({
    required String query,
    required String context,
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

    try {
      final res = await generate(AiRequest(
        mode: AiMode.documentQa,
        userMessage: query,
        context: context,
        attachments: attachments,
        conversationHistory: chatHistory,
      ));
      return res.answer;
    } catch (e) {
      return _generateOfflineFallback(query, context);
    }
  }

  @override
  Future<String> generateSummary({required String context}) async {
    final prompt = '''
Please provide a comprehensive, structured examination summary of the following study material.
Include:
1. Executive Overview & Core Purpose
2. Key Principles, Invariants & Definitions (use bullet points or tables)
3. Mathematical / Algorithmic Rules
4. High-Yield Exam Review Takeaways & Edge Cases

Study Material:
$context
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.summary,
        userMessage: prompt,
        context: context,
      ));
      return res.answer;
    } catch (_) {
      return '''### 📋 Document Summary (Local Fallback)

* **Overview**: Comprehensive review of key principles and operational constraints.
* **Key Principles**: 
  * Core invariants and structural guarantees.
  * Practical trade-offs and real-world system applications.
* **High-Yield Exam Takeaway**: Pay special attention to edge cases and comparative differences.
''';
    }
  }

  @override
  Future<String> generateQuestions({required String context, int count = 3}) async {
    final prompt = 'Generate $count critical, conceptual examination questions with brief model answers based on this text:\n$context';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.quiz,
        userMessage: prompt,
        context: context,
      ));
      return res.answer;
    } catch (_) {
      return '''1. What are the essential conditions and invariants that define this topic?
2. How does the system resolve conflicts or recover from unexpected failures?
3. What are the primary trade-offs in terms of time, memory, and complexity?''';
    }
  }

  @override
  Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    final prompt = '''
Generate exactly $count challenging multiple-choice questions for the topic "$topic".
${context != null && context.isNotEmpty ? "Based on this context:\n$context\n" : ""}
Return ONLY a valid JSON array matching this exact format with NO markdown fences:
[
  {
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed explanation of why option A is correct and others are wrong."
  }
]
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.quiz,
        userMessage: prompt,
        context: context,
        outputFormat: AiOutputFormat.json,
      ));
      final cleaned = res.answer.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = _parseQuizJson(cleaned);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {}

    return _fallbackQuiz(topic);
  }

  @override
  Future<List<Map<String, String>>> generateFlashcardDeck({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    final prompt = '''
Generate $count high-yield study flashcards for the topic "$topic".
${context != null && context.isNotEmpty ? "Using this context:\n$context\n" : ""}
Format each flashcard as:
Q: [Question / Key Term]
A: [Precise Answer / Definitive Explanation]
---
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.flashcards,
        userMessage: prompt,
        context: context,
      ));
      final cards = <Map<String, String>>[];
      final parts = res.answer.split('---');
      for (final p in parts) {
        final qMatch = RegExp(r'Q:\s*(.+?)(?=\nA:|\Z)', dotAll: true).firstMatch(p);
        final aMatch = RegExp(r'A:\s*(.+)', dotAll: true).firstMatch(p);
        if (qMatch != null && aMatch != null) {
          cards.add({
            'front': qMatch.group(1)!.trim(),
            'back': aMatch.group(1)!.trim(),
            'topic': topic,
          });
        }
      }
      if (cards.isNotEmpty) return cards;
    } catch (_) {}

    return _fallbackFlashcards(topic);
  }

  @override
  Future<String> generateTutorStep({
    required String topic,
    required String currentStep,
    required String userPrompt,
  }) async {
    final prompt = '''
Topic: $topic
Current Lesson Progression: $currentStep
User Question/Action: $userPrompt

Teach this step interactively in engaging Markdown with analogies, technical definitions, and a check question.
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.tutor,
        userMessage: prompt,
        systemInstruction: AiConfig.socraticTutorInstruction,
      ));
      return res.answer;
    } catch (_) {
      return '''### 🎓 Understanding $topic ($currentStep)

Let's break down **$topic** step by step:

1. **Fundamental Mechanism**: At its core, this concept manages how resources and operations are coordinated safely without collisions.
2. **Real-World Analogy**: Think of a traffic intersection managed by smart sensors to prevent gridlocks.
3. **Core Rule**: All invariants must be preserved before and after state transitions.

> 💡 **Quick Check**: Can you identify the primary trade-off between strict isolation and throughput?''';
    }
  }

  @override
  Future<List<Map<String, dynamic>>> generateExamMilestones({
    required String subject,
    required List<String> topics,
    required int days,
    required String studyTime,
    required String difficulty,
  }) async {
    final prompt = '''
Create a realistic $days-day exam preparation schedule for "$subject".
Topics to cover: ${topics.join(', ')}
Study Time: $studyTime per day
Difficulty: $difficulty

Return ONLY a valid JSON array formatted like:
[
  {
    "day": 1,
    "title": "Topic Name or Core Focus",
    "tasks": ["Task 1", "Task 2"],
    "isCompleted": false
  }
]
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.studyPlan,
        userMessage: prompt,
        outputFormat: AiOutputFormat.json,
      ));
      final cleaned = res.answer.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = _parseMilestonesJson(cleaned);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {}

    return _fallbackExamPlan(subject, topics, days);
  }

  // --- Fallbacks & Helper Parsers ---

  String _generateOfflineFallback(String query, String context) {
    return '''### 🤖 AI Study Analysis (Offline / No Key)

**Question**: $query

${context.isNotEmpty ? "#### Grounded Context from Vault:\n$context\n\n" : ""}
#### Core Conceptual Breakdown:
1. **Definition & Purpose**: Understanding this concept is central to academic and technical mastery.
2. **Key Invariants**: Review structural constraints, data flow, and operational guarantees.
3. **Examination Pointers**: Focus on definitions, comparative tables, and solving sample numericals.

> 💡 **Notice**: Connect your **Google Gemini API Key** in **Settings** (free from [aistudio.google.com](https://aistudio.google.com/)) to unlock live real-time AI reasoning!''';
  }

  List<Map<String, dynamic>> _parseQuizJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is Map) {
            final q = QuizQuestion.fromMap(Map<String, dynamic>.from(item));
            if (q.isValid) {
              list.add(q.toMap());
            }
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    // Regex fallback if LLM gave loose JSON
    try {
      final List<Map<String, dynamic>> results = [];
      final qBlocks = raw.split(RegExp(r'\}\s*,\s*\{'));
      for (final block in qBlocks) {
        final qMatch = RegExp(r'"question"\s*:\s*"([^"]+)"').firstMatch(block);
        final expMatch = RegExp(r'"explanation"\s*:\s*"([^"]+)"').firstMatch(block);
        final corrMatch = RegExp(r'"correctIndex"\s*:\s*(\d+)').firstMatch(block);
        final optMatches = RegExp(r'"options"\s*:\s*\[([^\]]+)\]').firstMatch(block);

        if (qMatch != null && optMatches != null) {
          final opts = optMatches
              .group(1)!
              .split(',')
              .map((s) => s.replaceAll('"', '').trim())
              .toList();
          final corr = corrMatch != null ? int.tryParse(corrMatch.group(1)!) ?? 0 : 0;
          results.add({
            'question': qMatch.group(1)!,
            'options': opts,
            'correctIndex': corr.clamp(0, opts.length - 1),
            'explanation': expMatch?.group(1) ?? 'Correct answer choice.',
          });
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _parseMilestonesJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> list = [];
      final blocks = raw.split(RegExp(r'\}\s*,\s*\{'));
      int day = 1;
      for (final b in blocks) {
        final titleMatch = RegExp(r'"title"\s*:\s*"([^"]+)"').firstMatch(b);
        if (titleMatch != null) {
          list.add({
            'day': day++,
            'title': titleMatch.group(1)!,
            'tasks': ['Review lecture notes & formulas', 'Complete 3 practice questions', 'Test active recall flashcards'],
            'isCompleted': false,
          });
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _fallbackQuiz(String topic) {
    return [
      {
        'question': 'What is the primary role of $topic in computer systems?',
        'options': [
          'Ensuring data correctness and optimal resource management',
          'Providing low-level hardware virtualization only',
          'Replacing disk storage with volatile memory',
          'Eliminating the need for transactions'
        ],
        'correctIndex': 0,
        'explanation': '$topic focuses on maintaining state validity and efficient resource coordination.',
      },
      {
        'question': 'Which of the following conditions is critical when implementing $topic?',
        'options': [
          'Uncontrolled concurrent writes',
          'Preserving integrity constraints and avoiding race conditions',
          'Executing all tasks in arbitrary non-deterministic order',
          'Disabling logging mechanisms'
        ],
        'correctIndex': 1,
        'explanation': 'Integrity constraints and deterministic isolation are essential.',
      },
      {
        'question': 'How does $topic handle system faults or unexpected exceptions?',
        'options': [
          'By discarding all committed data',
          'By rolling back uncommitted changes and maintaining consistency',
          'By ignoring the failure and proceeding',
          'By shutting down permanent disk drives'
        ],
        'correctIndex': 1,
        'explanation': 'Crash recovery ensures consistency by rolling back uncommitted actions.',
      },
    ];
  }

  List<Map<String, String>> _fallbackFlashcards(String topic) {
    return [
      {
        'front': 'What is the core definition of $topic?',
        'back': 'A fundamental architectural mechanism designed to ensure consistency, isolation, and reliable execution in systems.',
        'topic': topic,
      },
      {
        'front': 'What are the main advantages of $topic?',
        'back': 'Predictable performance, robust fault tolerance, and elimination of data anomalies during concurrent access.',
        'topic': topic,
      },
      {
        'front': 'What is a common trade-off associated with $topic?',
        'back': 'Increased locking overhead or storage metadata versus enhanced reliability.',
        'topic': topic,
      },
    ];
  }

  List<Map<String, dynamic>> _fallbackExamPlan(String subject, List<String> topics, int days) {
    final list = <Map<String, dynamic>>[];
    for (int i = 1; i <= days; i++) {
      final topicIndex = (i - 1) % (topics.isNotEmpty ? topics.length : 1);
      final topicName = topics.isNotEmpty ? topics[topicIndex] : 'Core Principles';
      list.add({
        'day': i,
        'title': 'Day $i: Focus on $topicName',
        'tasks': [
          'Deep review of $topicName lecture notes',
          'Solve 5 practice problems and review edge cases',
          'Take adaptive AI quiz to check retention'
        ],
        'isCompleted': i == 1,
      });
    }
    return list;
  }
}
