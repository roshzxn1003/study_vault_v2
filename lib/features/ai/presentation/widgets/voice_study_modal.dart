import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/core/services/speech_service.dart';
import 'package:study_vault/core/services/text_to_speech_service.dart';
import 'package:study_vault/features/ai/presentation/widgets/voice_study_orb.dart';

/// Hands-Free Voice Study Mode Modal
///
/// Provides a continuous conversational Socratic tutoring experience:
/// 1. Speaks Socratic guiding questions via TTS.
/// 2. Listens for user response via STT.
/// 3. Streams AI answer through the unified Gemini/Claude engine.
/// 4. Loops back to listening automatically for true hands-free learning.
class VoiceStudyModal extends ConsumerStatefulWidget {
  final String? initialContext;
  final String? topicOrSubject;

  const VoiceStudyModal({
    super.key,
    this.initialContext,
    this.topicOrSubject,
  });

  /// Displays the full-screen interactive voice tutor modal.
  static Future<void> show(
    BuildContext context, {
    String? initialContext,
    String? topicOrSubject,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceStudyModal(
        initialContext: initialContext,
        topicOrSubject: topicOrSubject,
      ),
    );
  }

  @override
  ConsumerState<VoiceStudyModal> createState() => _VoiceStudyModalState();
}

class _VoiceStudyModalState extends ConsumerState<VoiceStudyModal> {
  final SpeechService _speech = SpeechService();
  final TextToSpeechService _tts = TextToSpeechService();
  final TextEditingController _textFallbackController = TextEditingController();

  VoiceOrbState _orbState = VoiceOrbState.idle;
  double _soundLevel = 0.0;
  bool _isMuted = false;
  bool _isHandsFreeActive = true;
  String _userTranscript = '';
  String _aiTranscript = '';
  String _statusMessage = 'Initializing Voice Engine...';

  final List<Map<String, String>> _dialogueTurns = [];

  @override
  void initState() {
    super.initState();
    _initVoiceEngine();
  }

  @override
  void dispose() {
    _isHandsFreeActive = false;
    _speech.stopListening();
    _tts.stop();
    _textFallbackController.dispose();
    super.dispose();
  }

  Future<void> _initVoiceEngine() async {
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      if (_isHandsFreeActive && !_isMuted) {
        _startListeningTurn();
      } else {
        setState(() {
          _orbState = VoiceOrbState.idle;
        });
      }
    });

    _tts.setErrorHandler((error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Voice output error: $error';
        _orbState = VoiceOrbState.idle;
      });
    });

    final speechReady = await _speech.init(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' && _orbState == VoiceOrbState.listening && _userTranscript.isNotEmpty) {
          _processUserSpeech(_userTranscript);
        }
      },
      onError: (err) {
        if (!mounted) return;
        debugPrint('STT Error in VoiceStudy: $err');
      },
    );

    if (!mounted) return;

    if (!speechReady) {
      setState(() {
        _statusMessage = 'Microphone permission or speech engine unavailable. Use text fallback below.';
      });
    }

    // Start with an engaging Socratic opening
    final greetingTopic = widget.topicOrSubject ?? 'your study material';
    final openingGreeting = "Hi there! I'm your Socratic voice tutor for $greetingTopic. What concept or problem should we explore together?";
    
    setState(() {
      _aiTranscript = openingGreeting;
      _orbState = VoiceOrbState.speaking;
      _statusMessage = 'Tutor speaking...';
    });

    await _tts.speak(openingGreeting);
  }

  void _startListeningTurn() {
    if (!mounted || _isMuted) return;

    setState(() {
      _orbState = VoiceOrbState.listening;
      _userTranscript = '';
      _statusMessage = 'Listening... Speak naturally.';
    });

    _speech.startContinuousListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _userTranscript = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          _processUserSpeech(words.trim());
        }
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() {
          // Normalize level (speech_to_text levels are typically -10 to +10 dB)
          _soundLevel = ((level + 10.0) / 20.0).clamp(0.0, 1.0);
        });
      },
    );
  }

  Future<void> _processUserSpeech(String speech) async {
    if (!mounted || speech.trim().isEmpty) return;

    _speech.stopListening();

    setState(() {
      _orbState = VoiceOrbState.thinking;
      _statusMessage = 'Thinking Socratically...';
      _userTranscript = speech;
      _dialogueTurns.add({'role': 'user', 'text': speech});
      _aiTranscript = '';
    });

    try {
      final llm = ref.read(llmServiceProvider);

      final socraticSystemPrompt = '''
You are StudyVault's Conversational Socratic Voice Study Tutor.
You are engaged in a real-time speech dialogue with the student.
STUDY RULES:
1. Speak in natural conversational prose suitable for text-to-speech.
2. Be concise: MAXIMUM 1 TO 3 SHORT SENTENCES per turn.
3. Act Socratically: Validate or gently nudge the user's reasoning, then ask ONE focused probing question to test their understanding.
4. DO NOT provide bullet points, markdown bolding, code fences, or lengthy lectures.
${widget.topicOrSubject != null ? 'Topic: ${widget.topicOrSubject}' : ''}
${widget.initialContext != null ? 'Reference Notes: ${widget.initialContext}' : ''}
''';

      final historyMessages = _dialogueTurns.map((turn) => AiChatMessage(
        role: turn['role'] == 'user' ? 'user' : 'assistant',
        content: turn['text'] ?? '',
      )).toList();

      final response = await llm.generate(AiRequest(
        mode: AiMode.tutor,
        systemInstruction: socraticSystemPrompt,
        userMessage: speech,
        context: widget.initialContext,
        subjectContext: widget.topicOrSubject,
        conversationHistory: historyMessages,
      ));

      if (!mounted) return;

      final tutorReply = response.answer.trim();

      setState(() {
        _aiTranscript = tutorReply;
        _dialogueTurns.add({'role': 'tutor', 'text': tutorReply});
        _orbState = VoiceOrbState.speaking;
        _statusMessage = 'Tutor speaking...';
      });

      await _tts.speak(tutorReply);
    } catch (e) {
      if (!mounted) return;
      final fallbackError = "I couldn't quite catch that with the network. Could you repeat that once more?";
      setState(() {
        _aiTranscript = fallbackError;
        _orbState = VoiceOrbState.speaking;
        _statusMessage = 'Audio error occurred.';
      });
      await _tts.speak(fallbackError);
    }
  }

  void _onOrbTapped() {
    if (_orbState == VoiceOrbState.speaking) {
      // Tap to interrupt AI speaking
      _tts.stop();
      _startListeningTurn();
    } else if (_orbState == VoiceOrbState.listening) {
      // Tap to finalize current user input or pause
      if (_userTranscript.trim().isNotEmpty) {
        _processUserSpeech(_userTranscript.trim());
      } else {
        _speech.stopListening();
        setState(() {
          _orbState = VoiceOrbState.idle;
          _statusMessage = 'Paused. Tap orb to speak.';
        });
      }
    } else if (_orbState == VoiceOrbState.idle) {
      _startListeningTurn();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _speech.stopListening();
        _tts.stop();
        _orbState = VoiceOrbState.idle;
        _statusMessage = 'Microphone muted.';
      } else {
        _statusMessage = 'Resumed.';
        _startListeningTurn();
      }
    });
  }

  void _showTextInputDialog() {
    _speech.stopListening();
    _tts.stop();
    setState(() {
      _orbState = VoiceOrbState.idle;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type to Voice Tutor'),
        content: TextField(
          controller: _textFallbackController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type your question or thought...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final query = _textFallbackController.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(ctx);
                _textFallbackController.clear();
                _processUserSpeech(query);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & Top Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.headset_mic_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Voice Study Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _isMuted ? 'Unmute' : 'Mute',
                  icon: Icon(
                    _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isMuted ? Colors.redAccent : theme.iconTheme.color,
                  ),
                  onPressed: _toggleMute,
                ),
                IconButton(
                  tooltip: 'Type instead',
                  icon: const Icon(Icons.keyboard_rounded),
                  onPressed: _showTextInputDialog,
                ),
                IconButton(
                  tooltip: 'End Session',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Central Orb Section
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: VoiceStudyOrb(
                  state: _orbState,
                  soundLevel: _soundLevel,
                  size: 170,
                  onTap: _onOrbTapped,
                ),
              ),
            ),
          ),

          // Live Dialogue Transcript Window
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_userTranscript.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_rounded, size: 18, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userTranscript,
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aiTranscript.isNotEmpty ? _aiTranscript : _statusMessage,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom status & controls bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _orbState == VoiceOrbState.speaking ? Icons.touch_app_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  _orbState == VoiceOrbState.speaking
                      ? 'Tap orb to interrupt tutor'
                      : 'Hands-free dialogue active • Tap orb to toggle',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
