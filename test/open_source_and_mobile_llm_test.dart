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
import 'package:study_vault/core/ai/open_source_llm_service.dart';
import 'package:study_vault/core/ai/unified_smart_llm_service.dart';
import 'package:study_vault/features/profile/ai_settings_screen.dart';

class _MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;
  _MockHttpClient(this.onSend);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => onSend(request);
}

class _OfflineGeminiService extends GeminiLlmService {
  @override
  Future<bool> isAvailable() async => false;
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

  group('AiConfig Open-Source & Mobile Registry Tests', () {
    test('isOpenSourceModel correctly identifies mobile and local open models', () {
      expect(AiConfig.isOpenSourceModel(AiConfig.gemma2_2b), isTrue);
      expect(AiConfig.isOpenSourceModel(AiConfig.llama32_3b), isTrue);
      expect(AiConfig.isOpenSourceModel(AiConfig.llama32_1b), isTrue);
      expect(AiConfig.isOpenSourceModel(AiConfig.qwen25_15b), isTrue);
      expect(AiConfig.isOpenSourceModel(AiConfig.deepseekR1_15b), isTrue);
      expect(AiConfig.isOpenSourceModel(AiConfig.ollamaLocal), isTrue);
      expect(AiConfig.isOpenSourceModel('llama-3.1-8b-instruct'), isTrue);
      expect(AiConfig.isOpenSourceModel('qwen-2.5-7b'), isTrue);
      expect(AiConfig.isOpenSourceModel('mistral-7b-instruct'), isTrue);

      // Should not match proprietary cloud models
      expect(AiConfig.isOpenSourceModel(AiConfig.primaryModel), isFalse);
      expect(AiConfig.isOpenSourceModel(AiConfig.claude35Sonnet), isFalse);
    });

    test('isOllamaModel matches local node models', () {
      expect(AiConfig.isOllamaModel(AiConfig.ollamaLocal), isTrue);
      expect(AiConfig.isOllamaModel('ollama:llama3.2:3b'), isTrue);
      expect(AiConfig.isOllamaModel(AiConfig.gemma2_2b), isFalse);
    });

    test('supportedModels includes all 5 mobile models and Ollama node', () {
      final ids = AiConfig.supportedModels.map((m) => m['id']).toSet();
      expect(ids.contains(AiConfig.gemma2_2b), isTrue);
      expect(ids.contains(AiConfig.llama32_3b), isTrue);
      expect(ids.contains(AiConfig.llama32_1b), isTrue);
      expect(ids.contains(AiConfig.qwen25_15b), isTrue);
      expect(ids.contains(AiConfig.deepseekR1_15b), isTrue);
      expect(ids.contains(AiConfig.ollamaLocal), isTrue);
    });

    test('Ollama endpoint and model SharedPreferences persistence', () async {
      expect(await AiConfig.getOllamaEndpoint(), equals(AiConfig.defaultOllamaEndpoint));
      expect(await AiConfig.getOllamaSelectedModel(), equals(AiConfig.defaultOllamaModel));

      await AiConfig.setOllamaEndpoint('http://192.168.1.120:11434');
      await AiConfig.setOllamaSelectedModel('llama3.2:3b');
      await AiConfig.setOpenSourceCloudApiKey('gsk_test123');

      expect(await AiConfig.getOllamaEndpoint(), equals('http://192.168.1.120:11434'));
      expect(await AiConfig.getOllamaSelectedModel(), equals('llama3.2:3b'));
      expect(await AiConfig.getOpenSourceCloudApiKey(), equals('gsk_test123'));
    });

    test('testOllamaConnection detects live node and parses models', () async {
      final mockClient = _MockHttpClient((request) async {
        expect(request.url.path, equals('/api/tags'));
        final jsonResponse = jsonEncode({
          'models': [
            {'name': 'gemma2:2b', 'size': 1400000000},
            {'name': 'llama3.2:3b', 'size': 2100000000},
          ]
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonResponse)),
          200,
        );
      });

      final result = await AiConfig.testOllamaConnection(
        'http://192.168.1.50:11434',
        client: mockClient,
      );

      expect(result.isConnected, isTrue);
      expect(result.models, contains('gemma2:2b'));
      expect(result.models, contains('llama3.2:3b'));
    });
  });

  group('OpenSourceLlmService Stream & Generation Tests', () {
    test('isAvailable is always true (with mobile edge synthesizer fallback)', () async {
      final service = OpenSourceLlmService();
      expect(await service.isAvailable(), isTrue);
    });

    test('Streams SSE tokens from OpenAI/Ollama compatible endpoint', () async {
      final sseBody = 'data: {"choices": [{"delta": {"content": "Gemma "}}]}\n\n'
          'data: {"choices": [{"delta": {"content": "2 (2B) "}}]}\n\n'
          'data: {"choices": [{"delta": {"content": "Mobile!"}}]}\n\n'
          'data: [DONE]\n\n';

      final mockClient = _MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(sseBody)),
          200,
        );
      });

      final service = OpenSourceLlmService(httpClient: mockClient);
      final chunks = await service
          .generateStream(const AiRequest(
            mode: AiMode.documentQa,
            modelOverride: AiConfig.gemma2_2b,
            userMessage: 'Explain Newton second law',
          ))
          .map((c) => c.delta)
          .toList();

      expect(chunks, contains('Gemma '));
      expect(chunks, contains('2 (2B) '));
      expect(chunks, contains('Mobile!'));
    });

    test('Non-streaming generate parses response choices', () async {
      final responseBody = jsonEncode({
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': 'Newton second law states F = ma.',
            }
          }
        ]
      });

      final mockClient = _MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(responseBody)),
          200,
        );
      });

      final service = OpenSourceLlmService(httpClient: mockClient);
      final res = await service.generate(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: AiConfig.llama32_3b,
        userMessage: 'Define F=ma',
      ));

      expect(res.answer, contains('Newton second law states F = ma.'));
      expect(res.modelUsed, equals('llama3.2:3b'));
    });

    test('Engages on-device edge synthesizer when network fails', () async {
      // Mock client that throws network failure
      final failingClient = _MockHttpClient((request) async {
        throw Exception('Network unreachable / Connection refused');
      });

      final service = OpenSourceLlmService(httpClient: failingClient);
      final res = await service.generate(const AiRequest(
        mode: AiMode.summary,
        modelOverride: AiConfig.gemma2_2b,
        userMessage: 'Quantum Harmonic Oscillator',
        context: 'Potential energy V(x) = 1/2 k x^2.',
      ));

      expect(res.answer, contains('Mobile Open-Source Engine'));
      expect(res.answer, contains('Academic Synthesis'));
      expect(res.answer, contains('Core Overview'));
    });

    test('Generates structured JSON quiz via edge synthesizer fallback', () async {
      final failingClient = _MockHttpClient((request) async {
        throw Exception('Offline');
      });

      final service = OpenSourceLlmService(httpClient: failingClient);
      final quiz = await service.generateQuizQuestions(
        topic: 'Binary Search Trees',
        count: 1,
      );

      expect(quiz.isNotEmpty, isTrue);
      expect(quiz.first['question'], isNotNull);
      expect(quiz.first['options'], isNotNull);
      expect(quiz.first['correctIndex'], equals(0));
    });

    test('Generates flashcard deck via edge synthesizer fallback', () async {
      final failingClient = _MockHttpClient((request) async {
        throw Exception('Offline');
      });

      final service = OpenSourceLlmService(httpClient: failingClient);
      final deck = await service.generateFlashcardDeck(
        topic: 'Thermodynamics',
        count: 2,
      );

      expect(deck.isNotEmpty, isTrue);
      expect(deck.first['front'], isNotNull);
      expect(deck.first['back'], isNotNull);
    });
  });

  group('UnifiedSmartLlmService Open-Source Integration Tests', () {
    test('Routes explicit open-source models to LlmProvider.openSource', () async {
      final unified = UnifiedSmartLlmService(
        geminiService: GeminiLlmService(),
        claudeService: ClaudeLlmService(),
        openSourceService: OpenSourceLlmService(),
      );

      final gemmaRes = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: AiConfig.gemma2_2b,
        userMessage: 'Test Gemma',
      ));
      expect(gemmaRes.provider, equals(LlmProvider.openSource));
      expect(gemmaRes.model, equals(AiConfig.gemma2_2b));

      final llamaRes = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: AiConfig.llama32_3b,
        userMessage: 'Test Llama',
      ));
      expect(llamaRes.provider, equals(LlmProvider.openSource));
      expect(llamaRes.model, equals(AiConfig.llama32_3b));

      final ollamaRes = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: AiConfig.ollamaLocal,
        userMessage: 'Test Ollama',
      ));
      expect(ollamaRes.provider, equals(LlmProvider.openSource));
      expect(ollamaRes.model, equals(AiConfig.ollamaLocal));
    });

    test('Auto-Router falls back to open-source edge model when offline and no keys set', () async {
      final unified = UnifiedSmartLlmService(
        geminiService: _OfflineGeminiService(),
        claudeService: ClaudeLlmService(),
        openSourceService: OpenSourceLlmService(),
      );

      final autoRes = await unified.resolveEngine(const AiRequest(
        mode: AiMode.documentQa,
        modelOverride: 'auto',
        userMessage: 'Study session',
      ));

      expect(autoRes.provider, equals(LlmProvider.openSource));
      expect(autoRes.model, equals(AiConfig.gemma2_2b));
    });
  });

  group('AiSettingsScreen Mobile Open-Source UI Tests', () {
    testWidgets('Renders Mobile & Open-Source AI Engine Card and Preset Chips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Card Header
      expect(find.text('Mobile & Open-Source AI Engine'), findsOneWidget);

      // Verify Presets are present
      expect(find.text('⚡ Gemma 2 (2B)'), findsOneWidget);
      expect(find.text('🦙 Llama 3.2 (3B)'), findsOneWidget);
      expect(find.text('🪶 Llama 3.2 (1B)'), findsOneWidget);
      expect(find.text('🌐 Qwen 2.5 (1.5B)'), findsOneWidget);
      expect(find.text('🧠 DeepSeek-R1 (1.5B)'), findsOneWidget);
      expect(find.text('💻 Ollama Local Node'), findsOneWidget);

      // Verify Ollama Network Fields
      expect(find.text('Ollama Local Network Link (PC over Wi-Fi)'), findsOneWidget);
      expect(find.text('Ping Local Node'), findsOneWidget);
      expect(find.text('Save Node'), findsOneWidget);

      // Verify Cloud Open-Weights Key Section
      expect(find.text('Save Cloud Open-Weights Key'), findsOneWidget);
    });

    testWidgets('Tapping a preset chip updates active model and shows confirmation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Gemma 2 preset
      final gemmaChip = find.text('⚡ Gemma 2 (2B)');
      expect(gemmaChip, findsOneWidget);
      await tester.tap(gemmaChip);
      await tester.pumpAndSettle();

      // Verify model was set in AiConfig
      expect(await AiConfig.getSelectedModel(), equals(AiConfig.gemma2_2b));
    });
  });
}
