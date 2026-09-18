import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/design/widgets/widgets.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../providers/sharing_providers.dart';

/// Screen managing peer collaboration privacy, username discovery, and invitation controls.
class PrivacySharingSettingsScreen extends ConsumerStatefulWidget {
  const PrivacySharingSettingsScreen({super.key});

  @override
  ConsumerState<PrivacySharingSettingsScreen> createState() => _PrivacySharingSettingsScreenState();
}

class _PrivacySharingSettingsScreenState extends ConsumerState<PrivacySharingSettingsScreen> {
  final _usernameController = TextEditingController();
  bool _isSavingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentStudentProfileProvider).value;
      if (profile != null) {
        _usernameController.text = profile.username.replaceAll('@', '');
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveUsername() async {
    final raw = _usernameController.text.trim().replaceAll('@', '').toLowerCase();
    if (raw.length < 3) {
      setState(() => _usernameError = 'Username must be at least 3 characters.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(raw)) {
      setState(() => _usernameError = 'Username can only contain letters, numbers, and underscores.');
      return;
    }

    setState(() {
      _isSavingUsername = true;
      _usernameError = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userId = authRepo.getCurrentUser()?.id ?? 'guest';
      final repo = ref.read(sharingRepositoryProvider);

      // Check if taken
      final existing = await repo.getStudentByUsername(raw);
      if (existing != null && existing.id != userId) {
        setState(() => _usernameError = '@$raw is already taken by another student.');
        return;
      }

      await repo.updatePublicProfile(userId: userId, username: raw);
      ref.invalidate(currentStudentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated username to @$raw!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      setState(() => _usernameError = 'Failed to update username: $e');
    } finally {
      if (mounted) setState(() => _isSavingUsername = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(sharingPrivacySettingsProvider);
    final settingsNotifier = ref.read(sharingPrivacySettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Privacy & Sharing', style: AppTypography.subtitle.copyWith(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Private by Default Notice
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.card,
                      border: AppBorders.allStandard,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Private By Default',
                                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your Vault, subjects, notes, and academic history are strictly private. Connecting with another student never exposes private materials unless explicitly shared.',
                                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Text('Public Identity', style: AppTypography.subtitle.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your public Study Vault username is used for peer discovery and collaboration. Your email and passwords are never exposed.',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Card(
                    color: AppColors.surface,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    prefixText: '@ ',
                                    labelText: 'Public Username',
                                    border: OutlineInputBorder(borderRadius: AppRadius.button),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                text: 'Save',
                                isLoading: _isSavingUsername,
                                onPressed: _isSavingUsername ? null : _handleSaveUsername,
                              ),
                            ],
                          ),
                          if (_usernameError != null) ...[
                            const SizedBox(height: 6),
                            Text(_usernameError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Text('Discovery & Invitations', style: AppTypography.subtitle.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),

                  Card(
                    color: AppColors.surface,
                    shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: settings.isSearchable,
                          activeThumbColor: AppColors.primaryLight,
                          title: const Text('Allow students to search me by username', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('When disabled, other students cannot find your profile via student search', style: TextStyle(fontSize: 12)),
                          onChanged: (val) {
                            settingsNotifier.updateSettings(isSearchable: val);
                          },
                        ),
                        const AppDivider(),
                        SwitchListTile(
                          value: settings.allowsInvitesFromAnyone,
                          activeThumbColor: AppColors.primaryLight,
                          title: const Text('Allow study group invitations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Allow peers to send group study invitations', style: TextStyle(fontSize: 12)),
                          onChanged: (val) {
                            settingsNotifier.updateSettings(allowGroupInvites: val ? 'anyone' : 'nobody');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
