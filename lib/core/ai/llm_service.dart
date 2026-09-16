import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:study_vault/core/config/gemini_config.dart';

abstract class LlmService {
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

/// Real Google Gemini LLM Service that powers dynamic AI reasoning,
/// multimodal image understanding, real-time quiz generation, and Socratic tutoring.
class GeminiLlmService implements LlmService {
  Future<String?> _callGeminiText({
    required List<Content> contents,
    String? systemInstruction,
  }) async {
    final apiKey = await GeminiConfig.getApiKey();
    if (apiKey.isEmpty) return null;

    final selectedModel = await GeminiConfig.getSelectedModel();
    final modelsToTry = {selectedModel, 'gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-1.5-pro'}.toList();

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
        );
        final response = await model.generateContent(contents).timeout(const Duration(seconds: 20));
        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        debugPrint('Gemini call with model $modelName failed: $e');
      }
    }
    return null;
  }

  @override
  Future<String> generateAnswer({
    required String query,
    required String context,
    List<String>? history,
    String? imagePath,
  }) async {
    final contentParts = <Part>[];

    // Attach image if present
    if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()) {
      try {
        final bytes = await File(imagePath).readAsBytes();
        final mime = imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        contentParts.add(DataPart(mime, bytes));
      } catch (e) {
        debugPrint('Failed to load image attachment: $e');
      }
    }

    final fullPrompt = StringBuffer();
    if (context.isNotEmpty && !context.contains('No relevant context')) {
      fullPrompt.writeln('### Vault Notes / Reference Context:\n$context\n');
    }
    if (history != null && history.isNotEmpty) {
      fullPrompt.writeln('### Conversation History:');
      for (final h in history.take(4)) {
        fullPrompt.writeln('- $h');
      }
      fullPrompt.writeln();
    }
    fullPrompt.writeln('### Student Prompt / Query:\n$query');
    contentParts.add(TextPart(fullPrompt.toString()));

    final result = await _callGeminiText(
      contents: [Content.multi(contentParts)],
      systemInstruction: GeminiConfig.academicSystemInstruction,
    );

    if (result != null) return result;
    return _generateOfflineFallback(query, context);
  }

  @override
  Future<String> generateSummary({required String context}) async {
    final prompt = '''
Please provide a comprehensive, structured examination summary of the following study notes/material.
Include:
1. Executive Overview & Core Purpose
2. Key Principles, Invariants & Definitions (use clear bullet points or a Markdown table)
3. Mathematical / Algorithmic Rules
4. High-Yield Exam Review Takeaways & Edge Cases

Study Material:
$context
''';

    final result = await _callGeminiText(
      contents: [Content.text(prompt)],
      systemInstruction: GeminiConfig.academicSystemInstruction,
    );

    if (result != null) return result;

    return '''### 📋 Document Summary

* **Overview**: Comprehensive review of key mechanisms and core invariants.
* **Key Principles**: 
  * Definitive definitions, mathematical rules, and operational constraints.
  * Practical trade-offs and real-world system applications.
* **High-Yield Exam Takeaway**: Pay special attention to edge cases and comparative differences.
''';
  }

  @override
  Future<String> generateQuestions({required String context, int count = 3}) async {
    final prompt = 'Generate $count critical, conceptual examination questions with brief model answers based on this text:\n$context';
    final result = await _callGeminiText(
      contents: [Content.text(prompt)],
      systemInstruction: GeminiConfig.academicSystemInstruction,
    );

    if (result != null) return result;

    return '''1. What are the essential conditions and invariants that define this topic?
2. How does the system resolve conflicts or recover from unexpected failures?
3. What are the primary trade-offs in terms of time, memory, and complexity?''';
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
Return ONLY a valid JSON array matching this exact format with NO markdown code fences or backticks:
[
  {
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctIndex": 0,
    "explanation": "Detailed explanation of why option A is correct and others are wrong."
  }
]
''';

    final result = await _callGeminiText(
      contents: [Content.text(prompt)],
      systemInstruction: GeminiConfig.academicSystemInstruction,
    );

    if (result != null) {
      final cleaned = result.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = _parseQuizJson(cleaned);
      if (parsed.isNotEmpty) return parsed;
    }

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

    final result = await _callGeminiText(
      contents: [Content.text(prompt)],
      systemInstruction: GeminiConfig.academicSystemInstruction,
    );

    if (result != null) {
      final cards = <Map<String, String>>[];
      final parts = result.split('---');
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
    }

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

    final result = await _callGeminiText(
      contents: [Content.text(prompt)],
      systemInstruction: 'You are an inspiring, elite Socratic AI tutor. Teach "$topic" with deep clarity, diagrams/analogies, and active recall.',
    );

    if (result != null) return result;

    return '''### 🎓 Understanding $topic ($currentStep)

Let's break down **$topic** step by step:

1. **Fundamental Mechanism**: At its core, this concept manages how resources and operations are coordinated safely without collisions.
2. **Real-World Analogy**: Think of a traffic intersection managed by smart sensors to prevent gridlocks.
3. **Core Rule**: All invariants must be preserved before and after state transitions.

> 💡 **Quick Check**: Can you identify the primary trade-off between strict isolation and throughput?''';
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

    final result = await _callGeminiText(
      contents: [Content.text(prompt)],
      systemInstruction: GeminiConfig.academicSystemInstruction,
    );

    if (result != null) {
      final cleaned = result.replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = _parseMilestonesJson(cleaned);
      if (parsed.isNotEmpty) return parsed;
    }

    return _fallbackExamPlan(subject, topics, days);
  }

  // --- Fallbacks and JSON Parsers ---

  String _generateOfflineFallback(String query, String context) {
    return '''### 🤖 AI Study Analysis

**Question**: $query

${context.isNotEmpty ? "#### Grounded Context from Vault:\n$context\n\n" : ""}
#### Core Conceptual Breakdown:
1. **Definition & Purpose**: Understanding this concept is central to academic and technical mastery.
2. **Key Invariants**: Review structural constraints, data flow, and operational guarantees.
3. **Examination Pointers**: Focus on definitions, comparative tables, and solving sample numericals.

> 💡 **Tip**: Connect your **Google Gemini API Key** in **Settings** (free from [aistudio.google.com](https://aistudio.google.com/)) to unlock live real-time AI reasoning on any topic!''';
  }

  List<Map<String, dynamic>> _parseQuizJson(String raw) {
    try {
      final List<Map<String, dynamic>> results = [];
      // Simple regex extraction for robustness
      final qBlocks = raw.split(RegExp(r'\}\s*,\s*\{'));
      for (final block in qBlocks) {
        final qMatch = RegExp(r'"question"\s*:\s*"([^"]+)"').firstMatch(block);
        final expMatch = RegExp(r'"explanation"\s*:\s*"([^"]+)"').firstMatch(block);
        final corrMatch = RegExp(r'"correctIndex"\s*:\s*(\d+)').firstMatch(block);
        final optMatches = RegExp(r'"options"\s*:\s*\[([^\]]+)\]').firstMatch(block);

        if (qMatch != null && optMatches != null) {
          final opts = optMatches.group(1)!
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
