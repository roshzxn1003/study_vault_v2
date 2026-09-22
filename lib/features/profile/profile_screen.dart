import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/providers/profile_provider.dart';
import '../../core/theme/app_colors.dart';
import '../sharing/presentation/widgets/qr_discovery_modal.dart';
import '../sharing/presentation/screens/privacy_sharing_settings_screen.dart';
import '../sharing/presentation/providers/sharing_providers.dart';
import '../../core/database/local_db_service.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../onboarding/presentation/providers/onboarding_provider.dart';
import '../academic/presentation/providers/academic_workspace_provider.dart';
import '../vault/presentation/providers/vault_provider.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Vault Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Account Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (profile) {
          final user = Supabase.instance.client.auth.currentUser;
          final name = profile?['full_name'] ?? (user != null ? 'Study Vault Scholar' : 'Guest Scholar');
          final email = user?.email ?? 'Offline Mode (Local Storage)';
          final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Avatar Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                      Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
                          label: const Text("Edit Name", style: TextStyle(fontSize: 12)),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: "Display Name",
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
                const SizedBox(height: 18),

                // Real Vault Stats Grid
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
                            color: AppColors.primary,
                            title: '$subjectCount',
                            subtitle: subjectCount == 1 ? 'Subject' : 'Subjects',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.description_outlined,
                            color: AppColors.emerald,
                            title: '$materialCount',
                            subtitle: materialCount == 1 ? 'Material' : 'Materials',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.folder_outlined,
                            color: AppColors.cyan,
                            title: '$folderCount',
                            subtitle: folderCount == 1 ? 'Folder' : 'Folders',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                const Text("Learning & Vault", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 10),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A6366F1),
                          child: Icon(Icons.bar_chart_rounded, color: AppColors.primary),
                        ),
                        title: const Text("Study Analytics & Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Weekly study hours, mastery scores & badges"),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/progress'),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A06B6D4),
                          child: Icon(Icons.shield_outlined, color: AppColors.cyan),
                        ),
                        title: const Text("Privacy & Local Encryption", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Offline SQLite storage and data controls"),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/privacy'),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A10B981),
                          child: Icon(Icons.qr_code_2_rounded, color: AppColors.emerald),
                        ),
                        title: const Text("My Study Vault QR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Share your profile card for peer discovery"),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => QrDiscoveryModal.show(context),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A8B5CF6),
                          child: Icon(Icons.people_outline_rounded, color: Color(0xFF8B5CF6)),
                        ),
                        title: const Text("Privacy & Sharing Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text("Search visibility, group invites & permissions"),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrivacySharingSettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Logout / Sign in Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Log Out'),
                          content: const Text(
                            'Are you sure you want to log out of Study Vault? Your local changes have been safely saved to your account.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
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
                    icon: const Icon(Icons.logout),
                    label: Text(user != null ? "Log Out" : "Switch / Sign In Account", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

