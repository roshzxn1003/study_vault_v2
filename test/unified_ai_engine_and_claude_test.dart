import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/claude_llm_service.dart';
import 'package:study_vault/core/ai/llm_service.dart';
import 'package:study_vault/core/ai/unified_smart_llm_service.dart';
import 'package:study_vault/features/ai/ai_screen.dart';

class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;
  _FakeHttpClient(this.onSend);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => onSend(request);
}



void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ClaudeLlmService Unit Tests', () {
    test('isAvailable returns false when Claude key is empty', () async {
      final service = ClaudeLlmService();
      expect(await service.isAvailable(), isFalse);
    });

    test('isAvailable returns true when Claude key is set', () async {
      await AiConfig.setClaudeApiKey('sk-ant-api03-test-key');
      final service = ClaudeLlmService();
      expect(await service.isAvailable(), isTrue);
    });

    test('Throws NO_CLAUDE_KEY if streaming without key', () async {
      final service = ClaudeLlmService();
      expect(
        () => service.generateStream(const AiRequest(mode: AiMode.documentQa, userMessage: 'Test')).first,
        throwsA(isA<AiServiceException>().having((e) => e.code, 'code', 'NO_CLAUDE_KEY')),
      );
    });

    test('Streams SSE tokens accurately via mock client', () async {
      await AiConfig.setClaudeApiKey('sk-ant-api03-test-key');

      final fakeClient = _FakeHttpClient((request) async {
        final ssePayload = 'event: content_block_delta\n'
            'data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello "}}\n\n'
            'event: content_block_delta\n'
            'data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Claude!"}}\n\n'
            'event: message_stop\n'
            'data: {"type": "message_stop"}\n\n';

        final stream = Stream.value(utf8.encode(ssePayload));
        return http.StreamedResponse(stream, 200);
      });

      final service = ClaudeLlmService(httpClient: fakeClient);
      final chunks = await service
          .generateStream(const AiRequest(mode: AiMode.documentQa, userMessage: 'Hello'))
          .map((c) => c.delta)
          .toList();

      expect(chunks, contains('Hello '));
      expect(chunks, contains('Claude!'));
    });
  });

  group('UnifiedSmartLlmService Routing & Failover Tests', () {
    test('Routes to Gemini when request has image attachments', () async {
      final unified = UnifiedSmartLlmService(
        geminiService: GeminiLlmService(),
        claudeService: ClaudeLlmService(),
      );

      await AiConfig.setApiKey('AIzaSyTestGemini');
      await AiConfig.setClaudeApiKey('sk-ant-test-claude');

      final result = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        userMessage: 'Explain this diagram',
        attachments: [
          AiAttachment(filePath: '/tmp/test.png', mimeType: 'image/png'),
        ],
      ));

      expect(result.provider, equals(LlmProvider.gemini));
    });

    test('Routes to Claude for mathematical proofs and calculus questions', () async {
      final unified = UnifiedSmartLlmService(
        geminiService: GeminiLlmService(),
        claudeService: ClaudeLlmService(),
      );

      await AiConfig.setApiKey('AIzaSyTestGemini');
      await AiConfig.setClaudeApiKey('sk-ant-test-claude');

      final result = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        userMessage: 'Prove by induction that 1 + 2 + ... + n = n(n+1)/2',
      ));

      expect(result.provider, equals(LlmProvider.claude));
      expect(result.model, equals(AiConfig.claude37Sonnet));
    });

    test('Routes to Claude for structured quiz mode', () async {
      final unified = UnifiedSmartLlmService(
        geminiService: GeminiLlmService(),
        claudeService: ClaudeLlmService(),
      );

      await AiConfig.setApiKey('AIzaSyTestGemini');
      await AiConfig.setClaudeApiKey('sk-ant-test-claude');

      final result = await unified.resolveEngine(const AiRequest(
        mode: AiMode.quiz,
        userMessage: 'Generate quiz on sorting algorithms',
      ));

      expect(result.provider, equals(LlmProvider.claude));
      expect(result.model, equals(AiConfig.claude35Sonnet));
    });

    test('Honors explicit model override', () async {
      final unified = UnifiedSmartLlmService(
        geminiService: GeminiLlmService(),
        claudeService: ClaudeLlmService(),
      );

      final geminiResult = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: 'gemini-2.0-flash',
        userMessage: 'Test',
      ));
      expect(geminiResult.provider, equals(LlmProvider.gemini));
      expect(geminiResult.model, equals('gemini-2.0-flash'));

      final claudeResult = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: AiConfig.claude35Haiku,
        userMessage: 'Test',
      ));
      expect(claudeResult.provider, equals(LlmProvider.claude));
      expect(claudeResult.model, equals(AiConfig.claude35Haiku));
    });
  });

  group('AIScreen Multi-Model Selector Widget Tests', () {
    testWidgets('Model picker displays Auto-Router, Gemini and Claude options', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AIScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the model selector pill in the AppBar (defaults to Gemini 3.5 Flash-Lite)
      expect(find.text('Gemini 3.5 Flash-Lite'), findsOneWidget);
      await tester.tap(find.text('Gemini 3.5 Flash-Lite'));
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('Select AI Model'), findsOneWidget);
      expect(find.text('Auto-Router (Gemini + Claude)'), findsOneWidget);
      expect(find.text('Gemini 3.8 Flash'), findsOneWidget);

      // Scroll to view Claude models
      await tester.scrollUntilVisible(
        find.text('Claude 3.7 Sonnet'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Claude 3.7 Sonnet'), findsOneWidget);
    });
  });
}
