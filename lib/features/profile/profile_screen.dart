import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/profile/presentation/providers/profile_provider.dart';
import 'package:study_vault/features/profile/ai_settings_screen.dart';
import 'package:study_vault/features/sharing/presentation/widgets/qr_discovery_modal.dart';
import 'package:study_vault/features/sharing/presentation/screens/privacy_sharing_settings_screen.dart';
import 'package:study_vault/features/sharing/presentation/providers/sharing_providers.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_vault/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/sync/presentation/providers/sync_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(updateProfileProvider)(fullName: _nameController.text.trim());
      ref.invalidate(profileDataProvider);
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded, color: AppColors.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Study Vault'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 2.4.0 • Academic Edition', style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Your high-performance academic companion designed for university scholars. Offline-first local SQLite with cloud sync, contextual AI, and peer study groups.',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text('Built with Flutter & Supabase', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDataProvider);
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'My QR Card',
            onPressed: () => QrDiscoveryModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Account Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.textSecondary))),
        data: (profile) {
          final user = Supabase.instance.client.auth.currentUser;
          final name = profile?['full_name'] ?? (user != null ? 'Study Vault Scholar' : 'Guest Scholar');
          final email = user?.email ?? 'Offline Mode (Local Storage)';
          final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile Avatar & User Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(name, style: AppTypography.title.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Consumer(
                        builder: (ctx, ref, _) {
                          final studentProfile = ref.watch(currentStudentProfileProvider).value;
                          final username = studentProfile?.displayUsername ?? '@scholar';
                          return Text(
                            username,
                            style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 13),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      if (!_isEditing) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            _nameController.text = name;
                            setState(() => _isEditing = true);
                          },
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Edit Display Name', style: TextStyle(fontSize: 12)),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _isEditing = false),
                            ),
                            IconButton.filled(
                              icon: const Icon(Icons.check),
                              onPressed: _isLoading ? null : _saveProfile,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Real Vault Stats Row
                Consumer(
                  builder: (context, ref, _) {
                    final academicState = ref.watch(academicWorkspaceProvider);
                    final vaultState = ref.watch(vaultProvider);
                    final subjectCount = academicState.subjects.length;
                    final materialCount = vaultState.materials.length;
                    final folderCount = vaultState.folders.length;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.menu_book_rounded,
                            color: AppColors.primaryLight,
                            title: '$subjectCount',
                            subtitle: subjectCount == 1 ? 'Subject' : 'Subjects',
                            onTap: () => context.push('/academic/settings'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.description_outlined,
                            color: AppColors.emerald,
                            title: '$materialCount',
                            subtitle: materialCount == 1 ? 'Material' : 'Materials',
                            onTap: () => context.push('/library'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.folder_outlined,
                            color: AppColors.cyan,
                            title: '$folderCount',
                            subtitle: folderCount == 1 ? 'Folder' : 'Folders',
                            onTap: () => context.push('/library'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // =============================================================
                // 3. GROUP 1: ACADEMIC
                // =============================================================
                _buildSectionHeader('ACADEMIC'),
                Container(
                  decoration: _cardBoxDecoration,
                  child: Column(
                    children: [
                      Consumer(
                        builder: (ctx, ref, _) {
                          final academicState = ref.watch(academicWorkspaceProvider);
                          final program = academicState.activeWorkspace?.name ?? 'Academic Program';
                          final period = academicState.activePeriod?.name ?? 'Current Term';

                          return ListTile(
                            leading: _buildTileIcon(Icons.school_rounded, const Color(0xFFF59E0B)),
                            title: const Text('Academic Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('$program • $period', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => context.push('/academic/profile'),
                          );
                        },
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.auto_stories_rounded, AppColors.primaryLight),
                        title: const Text('Manage Subjects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Courses, subject codes, and instructors'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/academic/settings'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.history_edu_rounded, AppColors.cyan),
                        title: const Text('Academic Year & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Previous semesters and academic milestones'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/academic/history'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // =============================================================
                // 4. GROUP 2: ACCOUNT & CLOUD SYNC
                // =============================================================
                _buildSectionHeader('ACCOUNT & STORAGE'),
                Container(
                  decoration: _cardBoxDecoration,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildTileIcon(
                          syncState.isSyncing
                              ? Icons.sync_rounded
                              : (syncState.hasError ? Icons.sync_problem_rounded : Icons.cloud_done_rounded),
                          syncState.hasError ? AppColors.destructive : (syncState.isSyncing ? AppColors.primaryLight : AppColors.emerald),
                        ),
                        title: const Text('Cloud & Sync Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          syncState.isSyncing
                              ? 'Syncing materials now...'
                              : (syncState.lastSyncTime != null
                                  ? 'Last synced: ${syncState.lastSyncTime!.hour.toString().padLeft(2, '0')}:${syncState.lastSyncTime!.minute.toString().padLeft(2, '0')}'
                                  : 'Offline storage active'),
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        trailing: TextButton(
                          onPressed: syncState.isSyncing ? null : () => syncNotifier.syncNow(),
                          child: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.pie_chart_outline_rounded, const Color(0xFF8B5CF6)),
                        title: const Text('Storage Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Local cache size and offline copies'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/settings/storage-sync'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.shield_outlined, AppColors.emerald),
                        title: const Text('Privacy & Sharing Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Student search visibility, QR and invites'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrivacySharingSettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // =============================================================
                // 5. GROUP 3: APP PREFERENCES
                // =============================================================
                _buildSectionHeader('APP PREFERENCES'),
                Container(
                  decoration: _cardBoxDecoration,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildTileIcon(Icons.dark_mode_rounded, AppColors.primaryLight),
                        title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Dark theme (Academic Purple accent)'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Dark Mode', style: TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        onTap: () {},
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.manage_accounts_rounded, AppColors.cyan),
                        title: const Text('Account Security & Auth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Password, session and security controls'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/settings'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.lock_outline_rounded, const Color(0xFFF59E0B)),
                        title: const Text('Local SQLite & Encryption', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Offline-first data security and local database'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/privacy'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // =============================================================
                // 6. GROUP 4: TOOLS & AI
                // =============================================================
                _buildSectionHeader('TOOLS & INTELLIGENCE'),
                Container(
                  decoration: _cardBoxDecoration,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildTileIcon(Icons.auto_awesome_rounded, const Color(0xFF8B5CF6)),
                        title: const Text('AI Assistant Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Model configuration, API key & RAG indexing'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.bar_chart_rounded, AppColors.primaryLight),
                        title: const Text('Study Analytics & Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Revision time, mastery scores & badges'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/progress'),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      ListTile(
                        leading: _buildTileIcon(Icons.qr_code_2_rounded, AppColors.emerald),
                        title: const Text('Student QR Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Quick scan for classmate discovery'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => QrDiscoveryModal.show(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // =============================================================
                // 7. GROUP 5: ABOUT
                // =============================================================
                _buildSectionHeader('ABOUT'),
                Container(
                  decoration: _cardBoxDecoration,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildTileIcon(Icons.info_outline_rounded, AppColors.textSecondary),
                        title: const Text('About Study Vault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('v2.4.0 • Academic Productivity Suite'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 8. Log Out / Switch Account
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: const BorderSide(color: AppColors.destructive),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                          title: const Text('Log Out'),
                          content: const Text(
                            'Are you sure you want to log out? Your materials are safely saved in local storage and cloud sync.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Log Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      if (user != null) {
                        await LocalDbService.instance.clearUserData(user.id);
                      }
                      await ref.read(authControllerProvider.notifier).signOut();
                      await ref.read(onboardingProvider.notifier).resetOnboarding();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(user != null ? 'Log Out' : 'Switch / Sign In Account', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(title, style: AppTypography.title.copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _cardBoxDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderSubtle),
      );
}
