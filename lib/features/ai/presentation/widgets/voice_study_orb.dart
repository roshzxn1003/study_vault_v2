import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VoiceOrbState {
  idle,
  listening,
  thinking,
  speaking,
}

/// A glowing, pulsating audio visualizer orb for Hands-Free Voice Study Mode.
///
/// Visual behaviors:
/// - [VoiceOrbState.idle]: Gentle breathing pulse in ambient indigo/purple.
/// - [VoiceOrbState.listening]: Reactive emerald/cyan ripple waves expanding outward.
/// - [VoiceOrbState.thinking]: Revolving multi-hue gradient orbit simulating AI synthesis.
/// - [VoiceOrbState.speaking]: Dynamic rhythmic acoustic wave pulses in electric blue.
class VoiceStudyOrb extends StatefulWidget {
  final VoiceOrbState state;
  final double soundLevel; // 0.0 to 1.0 (normalized)
  final double size;
  final VoidCallback? onTap;

  const VoiceStudyOrb({
    super.key,
    required this.state,
    this.soundLevel = 0.0,
    this.size = 200.0,
    this.onTap,
  });

  @override
  State<VoiceStudyOrb> createState() => _VoiceStudyOrbState();
}

class _VoiceStudyOrbState extends State<VoiceStudyOrb> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  List<Color> _getGradientColors() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF4338CA)];
      case VoiceOrbState.listening:
        return const [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF047857)];
      case VoiceOrbState.thinking:
        return const [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)];
      case VoiceOrbState.speaking:
        return const [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF2563EB)];
    }
  }

  Color _getGlowColor() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return const Color(0xFF8B5CF6).withValues(alpha: 0.45);
      case VoiceOrbState.listening:
        return const Color(0xFF10B981).withValues(alpha: 0.55);
      case VoiceOrbState.thinking:
        return const Color(0xFFF59E0B).withValues(alpha: 0.50);
      case VoiceOrbState.speaking:
        return const Color(0xFF3B82F6).withValues(alpha: 0.60);
    }
  }

  IconData _getStateIcon() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return Icons.mic_none_rounded;
      case VoiceOrbState.listening:
        return Icons.mic_rounded;
      case VoiceOrbState.thinking:
        return Icons.auto_awesome_rounded;
      case VoiceOrbState.speaking:
        return Icons.volume_up_rounded;
    }
  }

  String _getStateLabel() {
    switch (widget.state) {
      case VoiceOrbState.idle:
        return 'Ready to listen';
      case VoiceOrbState.listening:
        return 'Listening...';
      case VoiceOrbState.thinking:
        return 'Thinking...';
      case VoiceOrbState.speaking:
        return 'Tutor Speaking';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getGradientColors();
    final glowColor = _getGlowColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _rotationController, _waveController]),
            builder: (context, child) {
              // Scale modulation
              double scale = 1.0;
              if (widget.state == VoiceOrbState.idle) {
                scale = 0.95 + (_pulseController.value * 0.08);
              } else if (widget.state == VoiceOrbState.listening) {
                final audioBoost = widget.soundLevel.clamp(0.0, 1.0) * 0.25;
                scale = 0.98 + (_pulseController.value * 0.05) + audioBoost;
              } else if (widget.state == VoiceOrbState.thinking) {
                scale = 1.0 + (_pulseController.value * 0.06);
              } else if (widget.state == VoiceOrbState.speaking) {
                scale = 1.02 + (math.sin(_waveController.value * math.pi * 2) * 0.08);
              }

              return SizedBox(
                width: widget.size * 1.4,
                height: widget.size * 1.4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Ripple 2 (Speaking / Listening)
                    if (widget.state == VoiceOrbState.listening || widget.state == VoiceOrbState.speaking)
                      Container(
                        width: widget.size * (1.1 + (_waveController.value * 0.35)),
                        height: widget.size * (1.1 + (_waveController.value * 0.35)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: glowColor.withValues(alpha: (1.0 - _waveController.value) * 0.6),
                            width: 2.0,
                          ),
                        ),
                      ),

                    // Outer Ripple 1
                    if (widget.state == VoiceOrbState.listening || widget.state == VoiceOrbState.speaking)
                      Container(
                        width: widget.size * (1.0 + (((_waveController.value + 0.5) % 1.0) * 0.25)),
                        height: widget.size * (1.0 + (((_waveController.value + 0.5) % 1.0) * 0.25)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: glowColor.withValues(alpha: (1.0 - ((_waveController.value + 0.5) % 1.0)) * 0.5),
                            width: 1.5,
                          ),
                        ),
                      ),

                    // Outer Ambient Glow Aura
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor,
                              blurRadius: 36.0 + (widget.soundLevel * 20.0),
                              spreadRadius: 10.0 + (widget.soundLevel * 12.0),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Core Rotating Orb
                    Transform.scale(
                      scale: scale,
                      child: Transform.rotate(
                        angle: widget.state == VoiceOrbState.thinking
                            ? _rotationController.value * math.pi * 2
                            : (_rotationController.value * math.pi * 0.3),
                        child: Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                colors[0],
                                colors[1],
                                colors[2],
                                colors[0],
                              ],
                              stops: const [0.0, 0.4, 0.8, 1.0],
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(3.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.35),
                                  colors[1].withValues(alpha: 0.8),
                                  colors[0],
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _getStateIcon(),
                                size: widget.size * 0.28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _getStateLabel(),
            key: ValueKey(widget.state),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: colors[0],
            ),
          ),
        ),
      ],
    );
  }
}
