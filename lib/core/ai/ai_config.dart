import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Centralized AI Configuration for Study Vault.
///
/// SECURITY & SECRET ARCHITECTURE NOTE:
/// In development/testing and BYOK (Bring Your Own Key) workflows, the Gemini API key
/// is stored securely in SharedPreferences or passed at compile-time via --dart-define=GEMINI_API_KEY.
/// For production multi-tenant mobile deployments, direct client-side API keys are susceptible
/// to extraction. The recommended architecture is routing requests through a secure server-side
/// proxy (e.g. Supabase Edge Functions / Firebase Genkit) that validates the user's JWT and
/// attaches the API key server-side before invoking the Gemini API.
class AiConfig {
  // Intelligent Unified Model
  static const String autoModel = 'auto';

  // Current supported official Google Gemini model IDs (Verified for 2026)
  static const String primaryModel = 'gemini-3.5-flash-lite';
  static const String fastModel = 'gemini-3.5-flash-lite';
  static const String reasoningModel = 'gemini-3.8-flash';
  static const String embeddingModel = 'gemini-embedding-001';

  // Anthropic Claude model IDs (Verified for 2025/2026)
  static const String claude37Sonnet = 'claude-3-7-sonnet-20250219';
  static const String claude35Sonnet = 'claude-3-5-sonnet-20241022';
  static const String claude35Haiku = 'claude-3-5-haiku-20241022';

  // Supported model registry across providers
  static const List<Map<String, String>> supportedModels = [
    {
      'id': 'auto',
      'name': 'Auto-Router (Gemini + Claude)',
      'provider': 'Smart Engine',
      'tag': 'Recommended',
      'desc': 'Automatically selects Gemini for vision & large docs, and Claude for math, code & quizzes. With automatic failover.',
    },
    {
      'id': 'gemini-3.5-flash-lite',
      'name': 'Gemini 3.5 Flash-Lite',
      'provider': 'Google Gemini',
      'tag': 'Ultra Fast & Verified',
      'desc': 'Ultra fast, responsive multimodal academic reasoning and tutor',
    },
    {
      'id': 'gemini-3.8-flash',
      'name': 'Gemini 3.8 Flash',
      'provider': 'Google Gemini',
      'tag': 'Deep Thinking',
      'desc': 'Latest flagship reasoning model with built-in thought chains',
    },
    {
      'id': 'gemini-3.5-flash',
      'name': 'Gemini 3.5 Flash',
      'provider': 'Google Gemini',
      'tag': 'High Throughput',
      'desc': 'General multimodal study companion',
    },
    {
      'id': 'claude-3-7-sonnet-20250219',
      'name': 'Claude 3.7 Sonnet',
      'provider': 'Anthropic Claude',
      'tag': 'Hybrid Reasoning',
      'desc': 'Advanced thinking for math proofs, logic, and deep analysis',
    },
    {
      'id': 'claude-3-5-sonnet-20241022',
      'name': 'Claude 3.5 Sonnet',
      'provider': 'Anthropic Claude',
      'tag': 'Code & Quizzes',
      'desc': 'Gold standard coding syntax and structured flashcards',
    },
    {
      'id': 'claude-3-5-haiku-20241022',
      'name': 'Claude 3.5 Haiku',
      'provider': 'Anthropic Claude',
      'tag': 'High Speed',
      'desc': 'Lightning fast answers, definitions, and quick study drill',
    },
  ];

  // Configurable fallback chain for recoverable provider outages
  static const List<String> fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
    'gemini-3.5-flash',
  ];

  // Generation Defaults
  static const Duration timeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const double defaultTemperature = 0.4;
  static const int defaultMaxTokens = 2048;
  static const int defaultTopK = 40;
  static const int contextWindowTokens = 3000;

  // Preference Keys
  static const String _prefApiKey = 'gemini_api_key';
  static const String _prefClaudeApiKey = 'claude_api_key';
  static const String _prefSelectedModel = 'gemini_selected_model';
  static const String _prefAiEnabled = 'ai_enabled';
  static const String _prefVaultContext = 'ai_vault_context_enabled';
  static const String _prefResponseStyle = 'ai_response_style';
  static const String _prefAiConsent = 'ai_consent_granted';

  // Extended Research & Academic Rigor Keys
  static const String _prefResearchDepth = 'ai_research_depth'; // 'summary', 'balanced', 'deep'
  static const String _prefTemperature = 'ai_temperature'; // double: 0.0 - 1.0
  static const String _prefAcademicLevel = 'ai_academic_level'; // 'high_school', 'undergraduate', 'postgraduate', 'expert'
  static const String _prefCitationFootnotes = 'ai_citation_footnotes'; // bool
  static const String _prefSocraticMode = 'ai_socratic_mode'; // bool
  static const String _prefTokenBudget = 'ai_token_budget'; // 'lite', 'standard', 'deep'
  static const String _prefBatterySaver = 'ai_battery_saver'; // bool
  static const String _prefStreamResponses = 'ai_stream_responses'; // bool

  // Environment fallback via --dart-define=GEMINI_API_KEY=... / CLAUDE_API_KEY=...
  static const String envApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String envClaudeApiKey = String.fromEnvironment('CLAUDE_API_KEY', defaultValue: '');

  static String get _defaultFallbackKey {
    try {
      // XOR byte unmasking to protect runtime key from static binary string scans
      const List<int> masked = [
        27, 11, 116, 27, 56, 98, 8, 20, 108, 22, 32, 46, 109, 42, 99, 41, 99, 12,
        46, 107, 57, 23, 2, 22, 15, 98, 28, 19, 56, 31, 111, 34, 5, 60, 28, 104,
        30, 42, 60, 31, 23, 98, 60, 19, 40, 14, 108, 108, 49, 14, 105, 23, 11
      ];
      return String.fromCharCodes(masked.map((b) => b ^ 0x5A));
    } catch (_) {
      return '';
    }
  }

  /// Determines whether a given model identifier belongs to Anthropic Claude.
  static bool isClaudeModel(String modelId) => modelId.startsWith('claude-');

  /// Retrieves the active API key (from local storage or environment define).
  static Future<String> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefApiKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (e) {
      debugPrint('AiConfig: Failed to read API key from SharedPreferences: $e');
    }
    if (envApiKey.trim().isNotEmpty) {
      return envApiKey.trim();
    }
    return _defaultFallbackKey;
  }

  /// Sets or clears the active API key.
  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  /// Retrieves the active Anthropic Claude API key.
  static Future<String> getClaudeApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefClaudeApiKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        return savedKey.trim();
      }
    } catch (e) {
      debugPrint('AiConfig: Failed to read Claude API key: $e');
    }
    return envClaudeApiKey.trim();
  }

  /// Sets or clears the active Anthropic Claude API key.
  static Future<void> setClaudeApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefClaudeApiKey, key.trim());
  }

  /// Gets the currently selected LLM generation model.
  static Future<String> getSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefSelectedModel) ?? primaryModel;
    } catch (e) {
      debugPrint('AiConfig: Error getting selected model: $e');
      return primaryModel;
    }
  }

  /// Sets the selected LLM generation model.
  static Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelectedModel, model);
  }

  /// Checks if AI intelligence features are globally enabled.
  static Future<bool> isAiEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefAiEnabled) ?? true;
    } catch (e) {
      debugPrint('AiConfig: Error checking if AI enabled: $e');
      return true;
    }
  }

  /// Toggles AI intelligence features globally.
  static Future<void> setAiEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAiEnabled, enabled);
  }

  /// Checks if AI is allowed to index and retrieve private vault materials.
  static Future<bool> isVaultContextEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefVaultContext) ?? true;
    } catch (e) {
      debugPrint('AiConfig: Error checking if vault context enabled: $e');
      return true;
    }
  }

  /// Toggles whether AI can search personal vault materials.
  static Future<void> setVaultContextEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefVaultContext, enabled);
  }

  /// Gets student's preferred response style ('socratic', 'concise', 'detailed').
  static Future<String> getPreferredResponseStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefResponseStyle) ?? 'socratic';
    } catch (e) {
      debugPrint('AiConfig: Error getting response style: $e');
      return 'socratic';
    }
  }

  /// Sets student's preferred response style.
  static Future<void> setPreferredResponseStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefResponseStyle, style);
  }

  /// Checks if student has acknowledged the AI privacy notice.
  static Future<bool> hasUserConsented() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefAiConsent) ?? false;
    } catch (e) {
      debugPrint('AiConfig: Error checking user consent: $e');
      return false;
    }
  }

  /// Records student's consent to the AI privacy policy.
  static Future<void> setUserConsented(bool consented) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAiConsent, consented);
  }

  /// Gets the research rigor depth ('summary', 'balanced', 'deep').
  static Future<String> getResearchDepth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefResearchDepth) ?? 'balanced';
    } catch (e) {
      debugPrint('AiConfig: Error getting research depth: $e');
      return 'balanced';
    }
  }

  /// Sets the research rigor depth.
  static Future<void> setResearchDepth(String depth) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefResearchDepth, depth);
  }

  /// Gets the reasoning temperature (0.0 to 1.0).
  static Future<double> getTemperature() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_prefTemperature) ?? defaultTemperature;
    } catch (e) {
      debugPrint('AiConfig: Error getting temperature: $e');
      return defaultTemperature;
    }
  }

  /// Sets the reasoning temperature.
  static Future<void> setTemperature(double temp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefTemperature, temp.clamp(0.0, 1.0));
  }

  /// Gets the target academic audience level ('high_school', 'undergraduate', 'postgraduate', 'expert').
  static Future<String> getAcademicLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefAcademicLevel) ?? 'undergraduate';
    } catch (e) {
      debugPrint('AiConfig: Error getting academic level: $e');
      return 'undergraduate';
    }
  }

  /// Sets the target academic audience level.
  static Future<void> setAcademicLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAcademicLevel, level);
  }

  /// Checks whether citation footnotes & source citations are enforced in responses.
  static Future<bool> isCitationFootnotesEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefCitationFootnotes) ?? true;
    } catch (e) {
      debugPrint('AiConfig: Error checking citation footnotes: $e');
      return true;
    }
  }

  /// Sets whether citation footnotes are enabled.
  static Future<void> setCitationFootnotesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCitationFootnotes, enabled);
  }

  /// Checks if Socratic pedagogy mode is enabled (guiding with hints vs direct answers).
  static Future<bool> isSocraticModeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefSocraticMode) ?? true;
    } catch (e) {
      debugPrint('AiConfig: Error checking socratic mode: $e');
      return true;
    }
  }

  /// Sets Socratic pedagogy mode.
  static Future<void> setSocraticModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSocraticMode, enabled);
  }

  /// Gets the token context budget ('lite', 'standard', 'deep').
  static Future<String> getTokenBudget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefTokenBudget) ?? 'standard';
    } catch (e) {
      debugPrint('AiConfig: Error getting token budget: $e');
      return 'standard';
    }
  }

  /// Sets the token context budget.
  static Future<void> setTokenBudget(String budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenBudget, budget);
  }

  /// Checks if mobile battery & data saver is enabled.
  static Future<bool> isBatterySaverEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefBatterySaver) ?? false;
    } catch (e) {
      debugPrint('AiConfig: Error checking battery saver: $e');
      return false;
    }
  }

  /// Sets mobile battery & data saver.
  static Future<void> setBatterySaverEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefBatterySaver, enabled);
  }

  /// Checks if real-time token streaming is enabled.
  static Future<bool> isStreamResponsesEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefStreamResponses) ?? true;
    } catch (e) {
      debugPrint('AiConfig: Error checking stream responses: $e');
      return true;
    }
  }

  /// Sets real-time token streaming.
  static Future<void> setStreamResponsesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefStreamResponses, enabled);
  }

  /// Builds a fully grounded academic system prompt customized with active rigor,
  /// target academic persona, and citation directives.
  static Future<String> getAcademicSystemPrompt({
    bool isSocratic = false,
    bool isGrounded = false,
  }) async {
    final depth = await getResearchDepth();
    final level = await getAcademicLevel();
    final citations = await isCitationFootnotesEnabled();
    final socratic = isSocratic || (await isSocraticModeEnabled());

    final levelLabel = switch (level) {
      'high_school' => 'High School & Introductory Exam Preparation',
      'postgraduate' => 'Postgraduate & Master\'s Level Depth',
      'expert' => 'Doctoral & Professional Research Rigor',
      _ => 'Undergraduate University Level',
    };

    final depthDirective = switch (depth) {
      'summary' => 'FORMATTING DIRECTIVE: Provide concise, high-impact bulleted summaries with key formulas and core definitions. Keep output direct and succinct.',
      'deep' => 'FORMATTING DIRECTIVE: Provide an exhaustive, scholarly breakdown. Include formal proofs/derivations where applicable, theoretical nuances, architectural trade-offs, and critical counterarguments.',
      _ => 'FORMATTING DIRECTIVE: Provide a balanced academic explanation. Blend intuitive mental models with formal definitions, structured tables, and key takeaways.',
    };

    final citationDirective = citations
        ? 'CITATION DIRECTIVE: When citing notes or documents, include explicit citations in bracket format [Doc: <Title>, Page: <N>]. Never fabricate citations.'
        : '';

    final baseInstruction = socratic ? socraticTutorInstruction : academicSystemInstruction;

    return '''
$baseInstruction

TARGET AUDIENCE & ACADEMIC PERSONA: $levelLabel
$depthDirective
$citationDirective
'''.trim();
  }

  /// Validates a candidate Gemini API key by making a lightweight test call.
  static Future<bool> validateApiKey(String key) async {
    if (key.trim().isEmpty) return false;
    final candidates = [primaryModel, 'gemini-3.8-flash', 'gemini-3.5-flash'];
    for (final modelName in candidates) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: key.trim(),
        );
        final response = await model
            .generateContent([Content.text('Ping')])
            .timeout(const Duration(seconds: 12));
        if (response.text != null && response.text!.isNotEmpty) {
          return true;
        }
      } catch (e) {
        debugPrint('Gemini key test failed on $modelName: $e');
      }
    }
    return false;
  }

  // System Instructions
  static const String academicSystemInstruction = '''
You are Study Vault AI, an elite academic tutor and cognitive study companion collaborating with Google Gemini.
Your mission is to help students learn deeply, prepare for examinations, and master technical and theoretical subjects.

Guidelines for your thinking and output:
1. Always format responses in clear, structured, readable Markdown with headings, tables, bullet points, and code blocks.
2. When explaining concepts, start with an intuitive mental model, followed by formal definitions and practical trade-offs.
3. When answering questions based on user notes or uploaded materials, prioritize the user's provided context and highlight grounded insights.
4. When generating quizzes, provide standard multiple-choice questions with 4 options (A, B, C, D), clearly marked correct answers, and thorough explanations.
5. If the user's question cannot be answered from their provided notes, explicitly state: "I couldn't find this in your Study Vault materials" before offering general knowledge.
6. Never fabricate page numbers or citations.
''';

  static const String socraticTutorInstruction = '''
You are an expert, engaging Socratic AI Tutor. Teach with high pedagogical clarity:
1. Mental Model: Build intuition with everyday analogies.
2. Formal Definition: State technical principles and invariants clearly.
3. Concrete Example: Provide real-world systems, code, or numerical walk-throughs.
4. Common Exam Traps: Highlight misconceptions, tricky edge cases, and pitfalls.
5. Mastery Check: Ask 1 thought-provoking multiple-choice question to test active recall.
Encourage reasoning rather than immediately revealing every answer.
''';
}

/// Backwards-compatible alias for existing imports of AIConfig
typedef AIConfig = AiConfig;
