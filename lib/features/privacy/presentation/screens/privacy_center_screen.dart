import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/privacy/data/services/data_export_service.dart';

class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

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
            'We use industry-standard encryption and RLS to ensure your study materials remain private.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          _buildPrivacyOption(
            icon: Icons.lock,
            title: 'Data Encryption',
            description: 'Your files are encrypted at rest and in transit.',
          ),
          _buildPrivacyOption(
            icon: Icons.visibility_off,
            title: 'AI Privacy',
            description: 'Your notes are used for RAG locally; we do not train global models on your private data.',
          ),
          _buildPrivacyOption(
            icon: Icons.delete_sweep,
            title: 'Account Deletion',
            description: 'Permanently remove all your data from our servers.',
            onTap: () {
              // Route to account deletion
            },
          ),
          const Divider(height: 40),
          const Text(
            'Data Portability',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export My Data'),
            subtitle: const Text('Download all your notes, folders, and progress in JSON format.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                await ref.read(dataExportServiceProvider).exportUserData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export completed! Your data has been prepared.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
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
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(description),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
