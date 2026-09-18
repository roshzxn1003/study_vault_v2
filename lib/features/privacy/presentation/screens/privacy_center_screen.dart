import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/features/profile/data/services/account_management_service.dart';

class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

  Future<void> _handleDeleteAccount(BuildContext context, WidgetRef ref) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account & All Data?'),
        content: const Text(
          'This action is irreversible. All your academic workspaces, subjects, folders, '
          'notes, flashcards, study plans, and cloud sync records will be permanently erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting account & data...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );

      await ref.read(accountManagementServiceProvider).deleteAccount(userId: userId);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account and local vault data have been completely deleted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _handleExportData(BuildContext context, WidgetRef ref) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'guest';

    try {
      final exportJson = await ref.read(accountManagementServiceProvider).exportUserData(userId: userId);
      final kbSize = (exportJson.length / 1024).toStringAsFixed(1);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data export generated ($kbSize KB). Zero secrets included.'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Center')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Your Data, Your Control',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'We use local SQLite storage, on-device indexing, and RLS to ensure your study materials remain private.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildPrivacyOption(
            icon: Icons.lock,
            title: 'Data Encryption',
            description: 'Your files are stored safely in your private local vault and encrypted in transit.',
          ),
          _buildPrivacyOption(
            icon: Icons.visibility_off,
            title: 'AI Privacy',
            description: 'Your notes are indexed locally for RAG; models are never trained on your private data.',
          ),
          _buildPrivacyOption(
            icon: Icons.delete_sweep,
            title: 'Account Deletion',
            description: 'Permanently remove all your data from our database and local device.',
            onTap: () => _handleDeleteAccount(context, ref),
          ),
          const Divider(height: 40, color: AppColors.border),
          const Text(
            'Data Portability',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.download, color: AppColors.primary),
            title: const Text('Export My Data'),
            subtitle: const Text('Download all your notes, folders, and progress in sanitized JSON format.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handleExportData(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(description),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
