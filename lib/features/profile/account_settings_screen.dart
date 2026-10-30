import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/profile/ai_settings_screen.dart';

/// Clean, consolidated Account & App Settings Screen.
/// Strictly decoupled from AI model configuration (managed in [AiSettingsScreen])
/// and Academic Curriculum (managed in [AcademicSettingsScreen]).
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _dailyReminders = true;
  bool _soundEffects = true;
  bool _hapticFeedback = true;
  bool _compactMode = false;
  String _activeModel = AiConfig.primaryModel;
  String _researchDepth = 'balanced';
  double _temperature = 0.4;
  bool _hasApiKey = false;
  bool _isLoadingAiInfo = true;

  @override
  void initState() {
    super.initState();
    _loadAiSummary();
  }

  Future<void> _loadAiSummary() async {
    final key = await AiConfig.getApiKey();
    final model = await AiConfig.getSelectedModel();
    final depth = await AiConfig.getResearchDepth();
    final temp = await AiConfig.getTemperature();
    if (mounted) {
      setState(() {
        _hasApiKey = key.isNotEmpty;
        _activeModel = model;
        _researchDepth = depth;
        _temperature = temp;
        _isLoadingAiInfo = false;
      });
    }
  }

  Future<void> _handlePasswordReset(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered email found for password reset.')),
      );
      return;
    }

    try {
      await ref.read(authRepositoryProvider).resetPassword(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reset email: $e'), backgroundColor: AppColors.destructive),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).getCurrentUser();
    final email = user?.email ?? 'Offline Guest User';
    final isGuest = user == null;

    final depthDisplay = switch (_researchDepth) {
      'summary' => 'Quick Summary',
      'deep' => 'Deep Scholarly',
      _ => 'Balanced Rigor',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Profile',
          onPressed: () {
            if (GoRouter.maybeOf(context)?.canPop() ?? false) {
              context.pop();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (GoRouter.maybeOf(context) != null) {
              context.go('/profile');
            }
          },
        ),
        title: const Text('Account & Preferences'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
            children: [
              // ===================================================================
              // 1. ACCOUNT & SECURITY
              // ===================================================================
              _buildSectionHeader('ACCOUNT & SECURITY'),
              _buildCardGroup([
                ListTile(
                  leading: _buildTileIcon(Icons.person_outline_rounded, AppColors.primaryLight),
                  title: Text(isGuest ? 'Guest Scholar' : 'Registered Student',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(email, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isGuest
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : AppColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isGuest ? 'Local Mode' : 'Cloud Sync',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isGuest ? const Color(0xFFF59E0B) : AppColors.emerald,
                      ),
                    ),
                  ),
                ),
                if (!isGuest) ...[
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  ListTile(
                    leading: _buildTileIcon(Icons.lock_reset_rounded, AppColors.cyan),
                    title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Receive a password reset link via email'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _handlePasswordReset(email),
                  ),
                ],
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  leading: _buildTileIcon(Icons.shield_outlined, AppColors.emerald),
                  title: const Text('Privacy & Security Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Zero telemetry, on-device SQLite encryption'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push('/privacy'),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 2. AI INTELLIGENCE & RESEARCH COMMAND CENTER
              // ===================================================================
              _buildSectionHeader('AI REASONING & RESEARCH SUITE'),
              _buildCardGroup([
                ListTile(
                  leading: _buildTileIcon(Icons.auto_awesome_rounded, const Color(0xFF8B5CF6)),
                  title: const Text('AI & Research Command Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    _isLoadingAiInfo
                        ? 'Loading configuration...'
                        : 'Model: $_activeModel • $depthDisplay (T: ${_temperature.toStringAsFixed(1)}) • ${_hasApiKey ? "Gemini Key Active" : "Bring Your Own Key"}',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                    );
                    _loadAiSummary();
                  },
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 3. ACADEMIC CURRICULUM & DEGREE SETTINGS
              // ===================================================================
              _buildSectionHeader('ACADEMIC CURRICULUM & GOALS'),
              _buildCardGroup([
                ListTile(
                  leading: _buildTileIcon(Icons.school_outlined, AppColors.primaryLight),
                  title: const Text('Curriculum & Semester Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Manage your degree program, major, active semester and enrolled subjects'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push('/academic/settings'),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 4. STUDY EXPERIENCE PREFERENCES
              // ===================================================================
              _buildSectionHeader('STUDY EXPERIENCE'),
              _buildCardGroup([
                SwitchListTile(
                  secondary: _buildTileIcon(Icons.notifications_active_outlined, AppColors.primaryLight),
                  title: const Text('Daily Study Reminders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Receive gentle study plan nudges before scheduled exams'),
                  value: _dailyReminders,
                  onChanged: (val) => setState(() => _dailyReminders = val),
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                SwitchListTile(
                  secondary: _buildTileIcon(Icons.volume_up_outlined, AppColors.cyan),
                  title: const Text('Audio Cues & Speech Reader', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Enable voice recitation and audio feedback'),
                  value: _soundEffects,
                  onChanged: (val) => setState(() => _soundEffects = val),
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                SwitchListTile(
                  secondary: _buildTileIcon(Icons.vibration_rounded, const Color(0xFFF59E0B)),
                  title: const Text('Haptic Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Tactile response on flashcard flips and button actions'),
                  value: _hapticFeedback,
                  onChanged: (val) => setState(() => _hapticFeedback = val),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 5. DISPLAY & ACCESSIBILITY
              // ===================================================================
              _buildSectionHeader('DISPLAY & ACCESSIBILITY'),
              _buildCardGroup([
                SwitchListTile(
                  secondary: _buildTileIcon(Icons.fit_screen_rounded, AppColors.primaryLight),
                  title: const Text('Compact Layout Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Reduces whitespace and card padding for smaller mobile displays'),
                  value: _compactMode,
                  onChanged: (val) => setState(() => _compactMode = val),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 6. STORAGE & MAINTENANCE
              // ===================================================================
              _buildSectionHeader('STORAGE & MAINTENANCE'),
              _buildCardGroup([
                ListTile(
                  leading: _buildTileIcon(Icons.pie_chart_outline_rounded, const Color(0xFF8B5CF6)),
                  title: const Text('Storage Breakdown & Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Offline cache metrics, outbox queue & cloud backup'),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => context.push('/settings/storage-sync'),
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  leading: _buildTileIcon(Icons.cleaning_services_outlined, const Color(0xFFF59E0B)),
                  title: const Text('Clear Preview Cache', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Free up temporary thumbnail and PDF preview memory'),
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preview cache cleared successfully!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 7. DANGER ZONE
              // ===================================================================
              _buildSectionHeader('DANGER ZONE'),
              _buildCardGroup([
                ListTile(
                  leading: _buildTileIcon(Icons.delete_forever_rounded, AppColors.destructive),
                  title: const Text('Wipe All Local Vault Data',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.destructive)),
                  subtitle: const Text('Permanently delete all cached materials and notes on this device'),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.destructive),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                        title: const Text('Wipe Local Vault?'),
                        content: const Text(
                          'This will permanently delete all offline study materials and database entries from this device. '
                          'Cloud-synced data will remain in your Supabase account.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Wipe All'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await LocalDbService.instance.clearAllData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Local vault database wiped clean.'),
                            backgroundColor: AppColors.destructive,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ]),
              const SizedBox(height: AppSpacing.xl),

              // ===================================================================
              // 8. OFFICIAL ABOUT BADGE
              // ===================================================================
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.card,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Study Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('v2.4.0 (Enterprise Academic Build)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Obsidian',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTileIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Icon(icon, color: color, size: 20)),
    );
  }
}
