import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/llm_service.dart';

/// Anthropic Claude implementation of [LlmService].
/// Provides streaming and non-streaming inference via the Anthropic Messages API.
class ClaudeLlmService implements LlmService {
  final http.Client _httpClient;
  static const String _anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String _anthropicVersion = '2023-06-01';

  ClaudeLlmService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  Future<bool> isAvailable() async {
    final key = await AiConfig.getClaudeApiKey();
    return key.trim().isNotEmpty;
  }

  @override
  Stream<AiChunk> generateStream(
    AiRequest request, {
    AiCancelToken? cancelToken,
  }) async* {
    final apiKey = await AiConfig.getClaudeApiKey();
    if (apiKey.isEmpty) {
      throw const AiServiceException(
        code: 'NO_CLAUDE_KEY',
        message: 'Anthropic Claude API key not configured. Add your key in Settings to activate Claude.',
      );
    }

    String modelName = request.modelOverride ?? AiConfig.claude35Sonnet;
    if (!AiConfig.isClaudeModel(modelName)) {
      modelName = AiConfig.claude35Sonnet;
    }

    final systemPrompt = request.systemInstruction ??
        (request.mode == AiMode.tutor
            ? AiConfig.socraticTutorInstruction
            : AiConfig.academicSystemInstruction);

    final messages = await _buildClaudeMessages(request);

    final payload = {
      'model': modelName,
      'max_tokens': request.maxTokens ?? AiConfig.defaultMaxTokens,
      'temperature': request.temperature ?? AiConfig.defaultTemperature,
      'system': systemPrompt,
      'messages': messages,
      'stream': true,
    };

    final httpRequest = http.Request('POST', Uri.parse(_anthropicEndpoint));
    httpRequest.headers.addAll({
      'x-api-key': apiKey,
      'anthropic-version': _anthropicVersion,
      'content-type': 'application/json',
      'accept': 'text/event-stream',
    });
    httpRequest.body = jsonEncode(payload);

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient.send(httpRequest);
    } catch (e) {
      throw AiServiceException(
        code: 'NETWORK_ERROR',
        message: 'Unable to connect to Anthropic Claude servers: $e',
        originalError: e,
      );
    }

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw _parseAnthropicError(streamedResponse.statusCode, errorBody);
    }

    final accumulated = StringBuffer();
    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (cancelToken?.isCancelled == true) {
        return;
      }

      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;

      final dataStr = trimmed.substring(5).trim();
      if (dataStr.isEmpty || dataStr == '[DONE]') continue;

      try {
        final json = jsonDecode(dataStr) as Map<String, dynamic>;
        final type = json['type'] as String?;

        if (type == 'content_block_delta') {
          final delta = json['delta'] as Map<String, dynamic>?;
          if (delta != null && delta['type'] == 'text_delta') {
            final text = delta['text'] as String? ?? '';
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
        } else if (type == 'message_stop') {
          break;
        } else if (type == 'error') {
          final errObj = json['error'] as Map<String, dynamic>?;
          throw AiServiceException(
            code: errObj?['type'] ?? 'CLAUDE_ERROR',
            message: errObj?['message'] ?? 'Error received from Claude stream',
          );
        }
      } catch (e) {
        if (e is AiServiceException) rethrow;
        debugPrint('ClaudeLlmService: error parsing SSE line: $e');
      }
    }

    // Final completion chunk
    yield AiChunk(
      delta: '',
      accumulatedText: accumulated.toString(),
      isDone: true,
      modelUsed: modelName,
    );
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final apiKey = await AiConfig.getClaudeApiKey();
    if (apiKey.isEmpty) {
      throw const AiServiceException(
        code: 'NO_CLAUDE_KEY',
        message: 'Anthropic Claude API key not configured. Add your key in Settings.',
      );
    }

    String modelName = request.modelOverride ?? AiConfig.claude35Sonnet;
    if (!AiConfig.isClaudeModel(modelName)) {
      modelName = AiConfig.claude35Sonnet;
    }

    final systemPrompt = request.systemInstruction ??
        (request.mode == AiMode.tutor
            ? AiConfig.socraticTutorInstruction
            : AiConfig.academicSystemInstruction);

    final messages = await _buildClaudeMessages(request);

    final payload = {
      'model': modelName,
      'max_tokens': request.maxTokens ?? AiConfig.defaultMaxTokens,
      'temperature': request.temperature ?? AiConfig.defaultTemperature,
      'system': systemPrompt,
      'messages': messages,
      'stream': false,
    };

    final response = await _httpClient.post(
      Uri.parse(_anthropicEndpoint),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw _parseAnthropicError(response.statusCode, response.body);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final contentList = data['content'] as List<dynamic>? ?? [];
    final textBuffer = StringBuffer();

    for (final item in contentList) {
      if (item is Map && item['type'] == 'text') {
        textBuffer.write(item['text'] ?? '');
      }
    }

    return AiResponse(
      answer: textBuffer.toString(),
      sources: const [],
      confidence: 1.0,
      usedContext: request.context ?? '',
      modelUsed: modelName,
    );
  }

  Future<List<Map<String, dynamic>>> _buildClaudeMessages(AiRequest request) async {
    final messages = <Map<String, dynamic>>[];

    // Add prior conversation history (keep most recent 8 messages)
    final recentHistory = request.conversationHistory.length > 8
        ? request.conversationHistory.sublist(request.conversationHistory.length - 8)
        : request.conversationHistory;
    for (final msg in recentHistory) {
      messages.add({
        'role': msg.role == 'assistant' ? 'assistant' : 'user',
        'content': msg.content,
      });
    }

    // Prepare current user content
    final contentParts = <Map<String, dynamic>>[];

    // Include multimodal image attachments if present
    for (final attachment in request.attachments) {
      try {
        List<int>? bytes;
        if (attachment.bytes != null) {
          bytes = attachment.bytes;
        } else if (attachment.filePath != null) {
          final file = File(attachment.filePath!);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        }
        if (bytes != null) {
          final base64Image = base64Encode(bytes);
          final mediaType = attachment.mimeType;
          contentParts.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Image,
            },
          });
        }
      } catch (e) {
        debugPrint('ClaudeLlmService: error encoding image attachment: $e');
      }
    }

    // Assemble text content with context
    final promptBuffer = StringBuffer();
    if (request.academicContext != null && request.academicContext!.isNotEmpty) {
      promptBuffer.writeln('Academic Grounding:\n${request.academicContext}\n');
    }
    if (request.context != null && request.context!.isNotEmpty) {
      promptBuffer.writeln('Study Vault Materials:\n${request.context}\n');
    }
    promptBuffer.write(request.userMessage);

    contentParts.add({
      'type': 'text',
      'text': promptBuffer.toString(),
    });

    messages.add({
      'role': 'user',
      'content': contentParts,
    });

    return messages;
  }

  AiServiceException _parseAnthropicError(int statusCode, String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final err = json['error'] as Map<String, dynamic>?;
      final type = err?['type'] as String? ?? 'ERROR';
      final message = err?['message'] as String? ?? responseBody;

      if (statusCode == 429 || type == 'rate_limit_error') {
        return AiServiceException(
          code: 'RATE_LIMIT',
          message: 'Anthropic rate limit reached. Auto-failover will engage.',
          originalError: responseBody,
        );
      }
      if (statusCode == 529 || statusCode == 503 || type == 'overloaded_error') {
        return AiServiceException(
          code: 'SERVICE_OVERLOADED',
          message: 'Anthropic servers are currently overloaded. Auto-failover will engage.',
          originalError: responseBody,
        );
      }
      if (statusCode == 401 || type == 'authentication_error') {
        return AiServiceException(
          code: 'INVALID_API_KEY',
          message: 'The Anthropic Claude API key is invalid or unauthorized.',
          originalError: responseBody,
        );
      }
      return AiServiceException(
        code: type,
        message: message,
        originalError: responseBody,
      );
    } catch (_) {
      return AiServiceException(
        code: 'HTTP_$statusCode',
        message: 'Anthropic API returned status $statusCode: $responseBody',
        originalError: responseBody,
      );
    }
  }

  // --- Convenience Implementations ---

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
    } catch (_) {
      return 'I encountered an issue generating an answer with Claude. Please verify your connection or fallback to Gemini.';
    }
  }

  @override
  Future<String> generateSummary({required String context}) async {
    final prompt = '''
Please provide a comprehensive, structured examination summary of the following study material.
Include:
1. Executive Overview & Core Purpose
2. Key Principles, Invariants & Definitions (use tables or bullet points)
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
      return '''### 📋 Document Summary (Claude Fallback)

* **Overview**: Review of core concepts and principles.
* **Key Principles**: Structural invariants and design trade-offs.
* **High-Yield Exam Takeaway**: Pay special attention to edge cases and definitions.
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
    "question": "Question text here",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed explanation of why option A is correct and why other options are distractors."
  }
]
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.quiz,
        userMessage: prompt,
        outputFormat: AiOutputFormat.json,
      ));
      final cleaned = res.answer.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [
        {
          'question': 'Which of the following best represents a core concept in $topic?',
          'options': ['Fundamental Invariant', 'Arbitrary Constraint', 'Unverified Assumption', 'Deprecated Protocol'],
          'correctIndex': 0,
          'explanation': 'Fundamental invariants define the theoretical baseline for $topic.',
        }
      ];
    }
  }

  @override
  Future<List<Map<String, String>>> generateFlashcardDeck({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    final prompt = '''
Generate $count high-yield flashcards for the topic "$topic".
${context != null && context.isNotEmpty ? "Based on this context:\n$context\n" : ""}
Return ONLY a valid JSON array matching this format with NO markdown fences:
[
  {
    "front": "Clear question or term",
    "back": "Concise answer with key principle"
  }
]
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.quiz,
        userMessage: prompt,
        outputFormat: AiOutputFormat.json,
      ));
      final cleaned = res.answer.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [
        {'front': 'Core Principle of $topic', 'back': 'Essential definition and operational invariant.'}
      ];
    }
  }

  @override
  Future<String> generateTutorStep({
    required String topic,
    required String currentStep,
    required String userPrompt,
  }) async {
    final prompt = '''
Topic: $topic
Current Step: $currentStep
User said: "$userPrompt"

Continue the Socratic study interaction. Maintain high pedagogical clarity.
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.tutor,
        userMessage: prompt,
        systemInstruction: AiConfig.socraticTutorInstruction,
      ));
      return res.answer;
    } catch (_) {
      return 'Let us review the fundamental principle of $topic. What is your understanding of its core invariant?';
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
Create a realistic $days-day study roadmap for $subject.
Topics to cover: ${topics.join(', ')}
Daily study time: $studyTime
Target difficulty: $difficulty

Return ONLY a JSON array with NO markdown fences:
[
  {
    "day": 1,
    "title": "Milestone title",
    "description": "Specific learning objectives",
    "tasks": ["Task 1", "Task 2"]
  }
]
''';
    try {
      final res = await generate(AiRequest(
        mode: AiMode.quiz,
        userMessage: prompt,
        outputFormat: AiOutputFormat.json,
      ));
      final cleaned = res.answer.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [
        {
          'day': 1,
          'title': 'Core Foundations of $subject',
          'description': 'Master key terms and definitions',
          'tasks': ['Review introductory chapters', 'Complete active recall flashcards']
        }
      ];
    }
  }
}
