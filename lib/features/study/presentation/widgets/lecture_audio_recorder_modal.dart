import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/services/speech_service.dart';

/// Lecture & Audio Study Note Recorder Modal
///
/// Records lecture audio, generates live or post-recording transcription,
/// and uses StudyVault's unified AI engine to distill high-yield study notes
/// and flashcards for the active subject.
class LectureAudioRecorderModal extends ConsumerStatefulWidget {
  final String? subjectId;
  final String? subjectName;
  final SpeechService? speechService;
  final bool autoInitSpeech;

  const LectureAudioRecorderModal({
    super.key,
    this.subjectId,
    this.subjectName,
    this.speechService,
    this.autoInitSpeech = true,
  });

  /// Displays the audio recorder modal.
  static Future<void> show(
    BuildContext context, {
    String? subjectId,
    String? subjectName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LectureAudioRecorderModal(
        subjectId: subjectId,
        subjectName: subjectName,
      ),
    );
  }

  @override
  ConsumerState<LectureAudioRecorderModal> createState() => _LectureAudioRecorderModalState();
}

class _LectureAudioRecorderModalState extends ConsumerState<LectureAudioRecorderModal> {
  late final SpeechService _speech;
  Timer? _timer;
  int _secondsRecorded = 0;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _liveTranscript = '';
  String _generatedNotes = '';
  String _status = 'Ready to record lecture or study note.';

  @override
  void initState() {
    super.initState();
    _speech = widget.speechService ?? SpeechService();
    if (widget.autoInitSpeech) {
      _speech.init();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stopListening();
    super.dispose();
  }

  void _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final ready = await _speech.init();
    if (!ready) {
      if (mounted) {
        setState(() {
          _status = 'Microphone access unavailable. Check device settings.';
        });
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _secondsRecorded = 0;
      _liveTranscript = '';
      _generatedNotes = '';
      _status = 'Recording lecture audio...';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _secondsRecorded++);
      }
    });

    _speech.startContinuousListening(
      onResult: (words, isFinal) {
        if (mounted) {
          setState(() {
            _liveTranscript = words;
          });
        }
      },
    );
  }

  void _stopRecording() {
    _timer?.cancel();
    _speech.stopListening();

    setState(() {
      _isRecording = false;
      _status = _liveTranscript.trim().isNotEmpty
          ? 'Recording finalized. Ready to distill notes.'
          : 'Recording stopped. No speech detected.';
    });
  }

  Future<void> _distillWithAi() async {
    if (_liveTranscript.trim().isEmpty) {
      setState(() => _status = 'Please record or dictate some audio first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'AI is synthesizing lecture notes & flashcards...';
    });

    try {
      final llm = ref.read(llmServiceProvider);
      final topic = widget.subjectName ?? 'University Lecture';

      final prompt = '''
You are an expert academic tutor distilling a student lecture recording for: "$topic".
Recorded Transcript:
"""
$_liveTranscript
"""

Generate a structured study guide with:
1. # 🎙️ Lecture Summary: $topic
2. ## Core Key Takeaways (3-5 high-yield bullet points)
3. ## Important Definitions & Formulas
4. ## High-Yield Flashcards (Q&A format)
5. ## 3 Recommended Exam Practice Questions
''';

      final response = await llm.generate(AiRequest(
        mode: AiMode.summary,
        userMessage: prompt,
      ));

      if (mounted) {
        setState(() {
          _generatedNotes = response.answer;
          _isProcessing = false;
          _status = 'Notes generated successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'Error synthesizing notes: $e';
        });
      }
    }
  }

  Future<void> _saveToVault() async {
    if (_generatedNotes.isEmpty) return;

    final title = 'Lecture Notes • ${widget.subjectName ?? 'Recorded'}';
    final id = 'lecture_${DateTime.now().millisecondsSinceEpoch}';

    final now = DateTime.now().toIso8601String();
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest';
    await LocalDbService.instance.saveMaterial({
      'id': id,
      'title': title,
      'user_id': userId,
      'subject_id': widget.subjectId ?? '',
      'content': _generatedNotes,
      'type': 'markdown',
      'created_at': now,
      'updated_at': now,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved lecture notes to your Study Vault!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Handle & Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lecture Audio Recorder',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.subjectName != null ? 'Subject: ${widget.subjectName}' : 'Study Vault Audio',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),

          // Central Recorder Controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              children: [
                Text(
                  _formatTimer(_secondsRecorded),
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    color: _isRecording ? Colors.redAccent : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      key: const ValueKey('toggle_lecture_record_fab'),
                      backgroundColor: _isRecording ? Colors.redAccent : const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      onPressed: _toggleRecording,
                      child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 28),
                    ),
                    if (!_isRecording && _liveTranscript.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        key: const ValueKey('distill_notes_ai_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isProcessing ? null : _distillWithAi,
                        icon: _isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('Distill with AI', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Transcript / Generated Notes Content Box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121216) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _generatedNotes.isNotEmpty ? 'Generated AI Notes & Flashcards' : 'Live Speech Transcript',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _generatedNotes.isNotEmpty
                          ? _generatedNotes
                          : (_liveTranscript.isNotEmpty ? _liveTranscript : 'Audio transcript will appear here in real time...'),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action
          if (_generatedNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('save_lecture_notes_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saveToVault,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Note & Flashcards to Vault', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
