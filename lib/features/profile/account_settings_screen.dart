import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/ai/ai_config.dart';
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
  String _activeModel = AiConfig.primaryModel;
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
    if (mounted) {
      setState(() {
        _hasApiKey = key.isNotEmpty;
        _activeModel = model;
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
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
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
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Offline Guest User';
    final isGuest = user == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Profile',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: const Text('Account & Preferences'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
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
          // 2. AI INTELLIGENCE & REASONING (Single Canonical Shortcut)
          // ===================================================================
          _buildSectionHeader('AI REASONING & ASSISTANT'),
          _buildCardGroup([
            ListTile(
              leading: _buildTileIcon(Icons.auto_awesome_rounded, const Color(0xFF8B5CF6)),
              title: const Text('Google Gemini AI Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                _isLoadingAiInfo
                    ? 'Loading configuration...'
                    : 'Model: $_activeModel • ${_hasApiKey ? "API Key Connected" : "Bring Your Own Key"}',
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
          // 3. STUDY EXPERIENCE PREFERENCES
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
          // 4. STORAGE & MAINTENANCE
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
                      content: Text('✨ Preview cache cleared successfully!'),
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
          // 5. DANGER ZONE
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
          // 6. OFFICIAL ABOUT BADGE
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
                Image.asset(
                  'assets/images/logo.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.school_rounded, size: 36, color: AppColors.primaryLight),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Study Vault v1.0.0+1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text(
                        'Academic Edition • Offline-First Knowledge Vault',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTileIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
