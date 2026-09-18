import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/classification_prompt_builder.dart';
import 'package:study_vault/core/ai/document_qa_prompt_builder.dart';
import 'package:study_vault/core/ai/flashcard_prompt_builder.dart';
import 'package:study_vault/core/ai/quiz_prompt_builder.dart';
import 'package:study_vault/core/ai/study_plan_prompt_builder.dart';
import 'package:study_vault/core/ai/summary_prompt_builder.dart';
import 'package:study_vault/core/ai/tutor_prompt_builder.dart';

/// Centralized, typed Prompt Engine managing prompt construction across all AI study modes.
class PromptEngine {
  static String buildDocumentQaPrompt({
    required String query,
    required String context,
    String? subject,
    String? workspace,
  }) {
    return DocumentQaPromptBuilder.buildPrompt(
      query: query,
      context: context,
      subject: subject,
      workspace: workspace,
    );
  }

  static String buildTutorPrompt({
    required String topic,
    required String context,
    required String currentStep,
    String? studentLevel,
    String? subject,
  }) {
    return TutorPromptBuilder.buildTeachingPrompt(
      topic: topic,
      context: context,
      currentStep: currentStep,
      studentLevel: studentLevel,
      subject: subject,
    );
  }

  static String buildSummaryPrompt({
    required String context,
    SummaryDepth depth = SummaryDepth.detailed,
    String? title,
  }) {
    return SummaryPromptBuilder.buildSummaryPrompt(
      context: context,
      depth: depth,
      title: title,
    );
  }

  static String buildQuizPrompt({
    required String topic,
    required String context,
    int count = 5,
    String difficulty = 'medium',
    String? subject,
  }) {
    return QuizPromptBuilder.buildQuizPrompt(
      topic: topic,
      context: context,
      count: count,
      difficulty: difficulty,
      subject: subject,
    );
  }

  static String buildFlashcardsPrompt({
    required String topic,
    required String context,
    int count = 5,
    String difficulty = 'medium',
  }) {
    return FlashcardPromptBuilder.buildPrompt(
      topic: topic,
      context: context,
      count: count,
      difficulty: difficulty,
    );
  }

  static String buildStudyPlanPrompt({
    required String subject,
    required List<String> topics,
    required int days,
    required String dailyStudyTime,
    String? difficulty,
  }) {
    return StudyPlanPromptBuilder.buildPlanPrompt(
      subject: subject,
      topics: topics,
      days: days,
      dailyStudyTime: dailyStudyTime,
      difficulty: difficulty,
    );
  }

  static String buildOrganizationPrompt({
    required String documentContent,
    String? rawFileName,
    List<String> existingSubjects = const [],
    List<String> existingFolders = const [],
    List<String> existingLabels = const [],
  }) {
    return ClassificationPromptBuilder.buildOrganizationPrompt(
      documentContent: documentContent,
      rawFileName: rawFileName,
      existingSubjects: existingSubjects,
      existingFolders: existingFolders,
      existingLabels: existingLabels,
    );
  }
}
