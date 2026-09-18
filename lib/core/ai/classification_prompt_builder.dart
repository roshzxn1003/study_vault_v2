/// Prompt builder for document classification and smart metadata suggestions.
class ClassificationPromptBuilder {
  static String buildOrganizationPrompt({
    required String documentContent,
    String? rawFileName,
    List<String> existingSubjects = const [],
    List<String> existingFolders = const [],
    List<String> existingLabels = const [],
  }) {
    return """
You are Study Vault's Academic Curator.
Analyze the following document/image text to recommend optimal organizational metadata for the student's vault.

FILE NAME: ${rawFileName ?? 'Untitled File'}
EXISTING VAULT SUBJECTS: ${existingSubjects.isEmpty ? 'None' : existingSubjects.join(', ')}
EXISTING VAULT FOLDERS: ${existingFolders.isEmpty ? 'None' : existingFolders.join(', ')}
AVAILABLE LABELS: ${existingLabels.isEmpty ? 'Notes, Exam, Revision, Assignment, Important' : existingLabels.join(', ')}

RULES:
1. Title: Recommend a clean, professional, academic title (e.g., "Operating Systems — Process Scheduling Notes").
2. Subject: Prefer selecting an existing subject from the list if relevant; otherwise suggest a standard course name.
3. Folder: Prefer selecting an existing folder (e.g., "Unit 3" or "Lecture Notes"); do NOT invent verbose nested folder names.
4. Labels: Pick 1 to 3 relevant labels (e.g. ["Notes", "Exam"]).
5. Rationale: Briefly explain the classification in 1 concise sentence.

OUTPUT SCHEMA (JSON ONLY, no markdown fences):
{
  "suggestedTitle": "Operating Systems — Process Scheduling Notes",
  "suggestedSubject": "Operating Systems",
  "suggestedFolder": "Unit 3",
  "suggestedLabels": ["Notes", "Exam"],
  "confidence": 0.92,
  "rationale": "Detected Coffman deadlock conditions and CPU scheduling algorithms in the text."
}

DOCUMENT CONTENT (FIRST 1500 CHARACTERS):
${documentContent.length > 1500 ? documentContent.substring(0, 1500) : documentContent}
""";
  }
}
