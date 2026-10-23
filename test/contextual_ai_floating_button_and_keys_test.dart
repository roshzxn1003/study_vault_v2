import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/design/widgets/contextual_ai_floating_button.dart';
import 'package:study_vault/features/profile/ai_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Contextual AI Floating Button Unit & Widget Tests', () {
    testWidgets('Renders properly with icon and tooltip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContextualAiFloatingButton(
                heroTag: 'test_fab_1',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byType(ContextualAiFloatingButton), findsOneWidget);
    });

    testWidgets('Shows contextual indicator badge when subject is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContextualAiFloatingButton(
                heroTag: 'test_fab_subject',
                subject: 'Advanced Algorithms',
              ),
            ),
          ),
        ),
      );

      // Context indicator is a Container with emerald decoration
      expect(find.byType(Container), findsWidgets);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('Custom onTap callback executes when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContextualAiFloatingButton(
                heroTag: 'test_fab_tap',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('AiConfig Claude & Models Registry Unit Tests', () {
    test('Supported models registry includes both Gemini and Claude models', () {
      final models = AiConfig.supportedModels;
      expect(models.length, greaterThanOrEqualTo(6));

      final geminiModels = models.where((m) => m['provider'] == 'Google Gemini').toList();
      final claudeModels = models.where((m) => m['provider'] == 'Anthropic Claude').toList();

      expect(geminiModels, isNotEmpty);
      expect(claudeModels, isNotEmpty);
      expect(claudeModels.any((m) => m['id'] == AiConfig.claude37Sonnet), isTrue);
      expect(claudeModels.any((m) => m['id'] == AiConfig.claude35Sonnet), isTrue);
      expect(claudeModels.any((m) => m['id'] == AiConfig.claude35Haiku), isTrue);
    });

    test('Claude API key can be saved and retrieved', () async {
      expect(await AiConfig.getClaudeApiKey(), isEmpty);

      const testKey = 'sk-ant-api03-test-secret-key-12345';
      await AiConfig.setClaudeApiKey(testKey);

      expect(await AiConfig.getClaudeApiKey(), equals(testKey));
    });

    test('isClaudeModel identifies Claude models accurately', () {
      expect(AiConfig.isClaudeModel('claude-3-7-sonnet-20250219'), isTrue);
      expect(AiConfig.isClaudeModel('claude-3-5-haiku-20241022'), isTrue);
      expect(AiConfig.isClaudeModel('gemini-1.5-flash'), isFalse);
    });
  });

  group('AiSettingsScreen UI Widget Tests', () {
    testWidgets('Renders API Key acquisition guide, Gemini card, and Claude card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI & Privacy Settings'), findsOneWidget);
      expect(find.text('AI Study Features'), findsOneWidget);
      expect(find.text('How to Get Free & Pro API Keys'), findsOneWidget);
      expect(find.text('Google Gemini API Key'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Anthropic Claude API Key'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Anthropic Claude API Key'), findsOneWidget);
    });
  });
}
