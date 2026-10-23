import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/claude_llm_service.dart';
import 'package:study_vault/core/ai/llm_service.dart';

enum LlmProvider { gemini, claude }

/// Unified AI Engine that combines Google Gemini and Anthropic Claude.
///
/// Features:
/// 1. Manual Model Selection: Honors explicit user model choices (Gemini 1.5/2.0 Flash, Claude 3.7/3.5).
/// 2. Smart Auto-Routing: Intelligently routes image/PDF tasks to Gemini and code/math/quiz tasks to Claude.
/// 3. Zero-Downtime Failover: Automatically switches between providers if rate limits (429) or server errors (503/529) occur.
class UnifiedSmartLlmService implements LlmService {
  final GeminiLlmService geminiService;
  final ClaudeLlmService claudeService;

  UnifiedSmartLlmService({
    required this.geminiService,
    required this.claudeService,
  });

  @override
  Future<bool> isAvailable() async {
    final hasGemini = await geminiService.isAvailable();
    final hasClaude = await claudeService.isAvailable();
    return hasGemini || hasClaude;
  }

  /// Selects the optimal provider and model identifier for a given request.
  Future<({LlmProvider provider, String model})> resolveEngine(AiRequest request) async {
    final explicitModel = request.modelOverride;

    // 1. Explicit model selection (Not 'auto')
    if (explicitModel != null && explicitModel.isNotEmpty && explicitModel != 'auto') {
      if (AiConfig.isClaudeModel(explicitModel)) {
        return (provider: LlmProvider.claude, model: explicitModel);
      } else {
        return (provider: LlmProvider.gemini, model: explicitModel);
      }
    }

    // 2. Auto-Router Mode: Check available credentials
    final hasGemini = await geminiService.isAvailable();
    final hasClaude = await claudeService.isAvailable();

    if (hasClaude && !hasGemini) {
      return (provider: LlmProvider.claude, model: AiConfig.claude35Sonnet);
    }
    if (hasGemini && !hasClaude) {
      return (provider: LlmProvider.gemini, model: AiConfig.primaryModel);
    }
    if (!hasGemini && !hasClaude) {
      // Default fallback when running offline or awaiting setup
      return (provider: LlmProvider.gemini, model: AiConfig.primaryModel);
    }

    // 3. Both providers available: apply intelligent task heuristics
    // A) Multimodal vision attachments or very large document context -> Gemini (1M context + native vision)
    if (request.attachments.isNotEmpty || (request.context?.length ?? 0) > 80000) {
      return (provider: LlmProvider.gemini, model: AiConfig.primaryModel);
    }

    // B) Structured Quiz generation or Flashcard decks -> Claude Sonnet (precision structured JSON)
    if (request.mode == AiMode.quiz || request.outputFormat == AiOutputFormat.json) {
      return (provider: LlmProvider.claude, model: AiConfig.claude35Sonnet);
    }

    // C) Mathematical derivations, algorithms, or code synthesis -> Claude 3.7 / 3.5 Sonnet
    final query = request.userMessage.toLowerCase();
    final isMathOrCode = query.contains('prove') ||
        query.contains('algorithm') ||
        query.contains('code') ||
        query.contains('calculus') ||
        query.contains('derivative') ||
        query.contains('equation') ||
        query.contains('solve') ||
        query.contains('proof');

    if (isMathOrCode) {
      return (provider: LlmProvider.claude, model: AiConfig.claude37Sonnet);
    }

    // D) Default: Gemini Primary Model (Fast, responsive everyday study tutor)
    return (provider: LlmProvider.gemini, model: AiConfig.primaryModel);
  }

  @override
  Stream<AiChunk> generateStream(
    AiRequest request, {
    AiCancelToken? cancelToken,
  }) async* {
    final resolved = await resolveEngine(request);
    final primaryProvider = resolved.provider;
    final primaryModel = resolved.model;

    LlmService primaryService = primaryProvider == LlmProvider.claude ? claudeService : geminiService;
    LlmService backupService = primaryProvider == LlmProvider.claude ? geminiService : claudeService;
    String backupModel = primaryProvider == LlmProvider.claude ? AiConfig.primaryModel : AiConfig.claude35Sonnet;

    final primaryReq = request.copyWith(modelOverride: primaryModel);
    bool receivedAnyChunk = false;

    Stream<AiChunk>? primaryStream;
    try {
      primaryStream = primaryService.generateStream(primaryReq, cancelToken: cancelToken);
    } catch (e) {
      debugPrint('Primary provider ($primaryProvider) immediate failure: $e');
    }

    if (primaryStream != null) {
      bool failoverEngaged = false;
      final iterator = StreamIterator(primaryStream);

      try {
        while (await iterator.moveNext()) {
          if (cancelToken?.isCancelled == true) return;
          receivedAnyChunk = true;
          yield iterator.current;
        }
      } catch (e) {
        debugPrint('Primary provider ($primaryProvider) error during stream: $e');
        if (!receivedAnyChunk && _isFailoverCandidate(e)) {
          failoverEngaged = true;
        } else {
          rethrow;
        }
      } finally {
        await iterator.cancel();
      }

      if (!failoverEngaged) return;
    }

    // Attempt automatic failover if no chunks have been emitted yet
    final canBackup = await backupService.isAvailable();
    if (canBackup) {
      debugPrint('UnifiedSmartLlmService: Engaging auto-failover to backup ($backupModel)...');
      final failoverNotice = '[⚡ Auto-failover: Switched to $backupModel backup due to provider rate limit]\n\n';
      yield AiChunk(
        delta: failoverNotice,
        accumulatedText: failoverNotice,
        isDone: false,
        modelUsed: backupModel,
      );

      final backupReq = request.copyWith(modelOverride: backupModel);
      final backupStream = backupService.generateStream(backupReq, cancelToken: cancelToken);

      await for (final chunk in backupStream) {
        if (cancelToken?.isCancelled == true) return;
        yield AiChunk(
          delta: chunk.delta,
          accumulatedText: failoverNotice + chunk.accumulatedText,
          isDone: chunk.isDone,
          modelUsed: backupModel,
        );
      }
      return;
    }

    // If backup unavailable, rethrow original error
    throw const AiServiceException(
      code: 'PROVIDER_ERROR',
      message: 'Primary AI provider encountered an issue and no secondary provider API key is configured.',
    );
  }

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final resolved = await resolveEngine(request);
    final primaryProvider = resolved.provider;
    final primaryModel = resolved.model;

    LlmService primaryService = primaryProvider == LlmProvider.claude ? claudeService : geminiService;
    LlmService backupService = primaryProvider == LlmProvider.claude ? geminiService : claudeService;
    String backupModel = primaryProvider == LlmProvider.claude ? AiConfig.primaryModel : AiConfig.claude35Sonnet;

    final primaryReq = request.copyWith(modelOverride: primaryModel);

    try {
      return await primaryService.generate(primaryReq);
    } catch (e) {
      debugPrint('Primary provider ($primaryProvider) generate error: $e');
      if (_isFailoverCandidate(e) && await backupService.isAvailable()) {
        debugPrint('UnifiedSmartLlmService: Engaging failover for non-stream generate...');
        final backupReq = request.copyWith(modelOverride: backupModel);
        final backupRes = await backupService.generate(backupReq);
        return AiResponse(
          answer: '[⚡ Handled via $backupModel failover]\n\n${backupRes.answer}',
          sources: backupRes.sources,
          confidence: backupRes.confidence,
          usedContext: backupRes.usedContext,
          modelUsed: backupModel,
          finishReason: backupRes.finishReason,
        );
      }
      rethrow;
    }
  }

  bool _isFailoverCandidate(Object error) {
    if (error is AiServiceException) {
      final code = error.code.toUpperCase();
      return code.contains('RATE_LIMIT') ||
          code.contains('QUOTA') ||
          code.contains('OVERLOAD') ||
          code.contains('503') ||
          code.contains('529') ||
          code.contains('429');
    }
    final str = error.toString().toLowerCase();
    return str.contains('429') ||
        str.contains('rate limit') ||
        str.contains('quota') ||
        str.contains('overloaded') ||
        str.contains('503') ||
        str.contains('529');
  }

  // --- Convenience Implementations ---

  @override
  Future<String> generateAnswer({
    required String query,
    required String context,
    List<String>? history,
    String? imagePath,
  }) async {
    final resolved = await resolveEngine(AiRequest(
      mode: AiMode.documentQa,
      userMessage: query,
      context: context,
    ));
    final service = resolved.provider == LlmProvider.claude ? claudeService : geminiService;
    return service.generateAnswer(
      query: query,
      context: context,
      history: history,
      imagePath: imagePath,
    );
  }

  @override
  Future<String> generateSummary({required String context}) async {
    // Automatically favor Claude for deep structured summary if available, else Gemini
    final hasClaude = await claudeService.isAvailable();
    final service = hasClaude ? claudeService : geminiService;
    return service.generateSummary(context: context);
  }

  @override
  Future<String> generateQuestions({required String context, int count = 3}) async {
    final hasClaude = await claudeService.isAvailable();
    final service = hasClaude ? claudeService : geminiService;
    return service.generateQuestions(context: context, count: count);
  }

  @override
  Future<List<Map<String, dynamic>>> generateQuizQuestions({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    // Favor Claude for structured quiz JSON if available
    final hasClaude = await claudeService.isAvailable();
    final service = hasClaude ? claudeService : geminiService;
    return service.generateQuizQuestions(topic: topic, context: context, count: count);
  }

  @override
  Future<List<Map<String, String>>> generateFlashcardDeck({
    required String topic,
    String? context,
    int count = 5,
  }) async {
    final hasClaude = await claudeService.isAvailable();
    final service = hasClaude ? claudeService : geminiService;
    return service.generateFlashcardDeck(topic: topic, context: context, count: count);
  }

  @override
  Future<String> generateTutorStep({
    required String topic,
    required String currentStep,
    required String userPrompt,
  }) async {
    final hasClaude = await claudeService.isAvailable();
    final service = hasClaude ? claudeService : geminiService;
    return service.generateTutorStep(topic: topic, currentStep: currentStep, userPrompt: userPrompt);
  }

  @override
  Future<List<Map<String, dynamic>>> generateExamMilestones({
    required String subject,
    required List<String> topics,
    required int days,
    required String studyTime,
    required String difficulty,
  }) async {
    final hasClaude = await claudeService.isAvailable();
    final service = hasClaude ? claudeService : geminiService;
    return service.generateExamMilestones(
      subject: subject,
      topics: topics,
      days: days,
      studyTime: studyTime,
      difficulty: difficulty,
    );
  }
}
