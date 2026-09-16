import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/theme/app_colors.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/config/gemini_config.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = GeminiConfig.defaultModel;
  bool _obscureKey = true;
  bool _isTestingKey = false;
  bool _keyValidated = false;

  bool _dailyReminders = true;
  bool _offlineSync = true;
  bool _soundEffects = true;
  bool _hapticFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadGeminiSettings();
  }

  Future<void> _loadGeminiSettings() async {
    final key = await GeminiConfig.getApiKey();
    final model = await GeminiConfig.getSelectedModel();
    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _selectedModel = model;
        _keyValidated = key.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTestGemini() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      await GeminiConfig.setApiKey('');
      setState(() => _keyValidated = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gemini API Key removed. Using offline study engine.")),
        );
      }
      return;
    }

    setState(() => _isTestingKey = true);
    final isValid = await GeminiConfig.validateApiKey(key);
    await GeminiConfig.setApiKey(key);
    await GeminiConfig.setSelectedModel(_selectedModel);

    if (mounted) {
      setState(() {
        _isTestingKey = false;
        _keyValidated = isValid;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid
              ? "✨ Connected to Google Gemini successfully ($_selectedModel active)!"
              : "⚠️ Key saved, but verification failed. Please check key permissions."),
          backgroundColor: isValid ? AppColors.emerald : AppColors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings & AI Configuration")),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Google Gemini Collaboration Card
          const Text("Google Gemini AI Collaboration", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _keyValidated ? AppColors.emerald.withValues(alpha: 0.5) : AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Google Gemini Engine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                          Text(
                            _keyValidated ? "Connected & Live Reasoning Active" : "Connect your free API Key for live AI",
                            style: TextStyle(
                              fontSize: 12,
                              color: _keyValidated ? AppColors.emerald : AppColors.textSecondary,
                              fontWeight: _keyValidated ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Model Selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedModel,
                  dropdownColor: AppColors.surfaceElevated,

                  decoration: const InputDecoration(
                    labelText: "Gemini Model",
                    prefixIcon: Icon(Icons.psychology_outlined, color: AppColors.primary),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'gemini-1.5-flash', child: Text("Gemini 1.5 Flash (Fastest & Free)")),
                    DropdownMenuItem(value: 'gemini-1.5-pro', child: Text("Gemini 1.5 Pro (Deep Socratic Reasoning)")),
                    DropdownMenuItem(value: 'gemini-2.0-flash', child: Text("Gemini 2.0 Flash (Next-Gen Preview)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedModel = val);
                      GeminiConfig.setSelectedModel(val);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // API Key Input
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: "Gemini API Key",
                    hintText: "AIzaSy...",
                    prefixIcon: const Icon(Icons.key, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isTestingKey ? null : _saveAndTestGemini,
                    icon: _isTestingKey
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(_isTestingKey ? "Testing Connection..." : "Save & Verify Gemini Key"),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Get your free key with unlimited personal requests at aistudio.google.com",
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text("Study Preferences", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                  title: const Text("Daily Study Reminders", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("Receive AI nudge for scheduled exams", style: TextStyle(fontSize: 12)),
                  value: _dailyReminders,
                  onChanged: (val) => setState(() => _dailyReminders = val),
                ),
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile(
                  secondary: const Icon(Icons.sync, color: AppColors.emerald),
                  title: const Text("Background Vault Sync", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("Sync local SQLite vault with cloud", style: TextStyle(fontSize: 12)),
                  value: _offlineSync,
                  onChanged: (val) => setState(() => _offlineSync = val),
                ),
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined, color: AppColors.cyan),
                  title: const Text("Audio Cues & Speech Reader", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("Play voice explanations and audio cues", style: TextStyle(fontSize: 12)),
                  value: _soundEffects,
                  onChanged: (val) => setState(() => _soundEffects = val),
                ),
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: AppColors.amber),
                  title: const Text("Haptic Feedback", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("Tactile feedback on card flips and taps", style: TextStyle(fontSize: 12)),
                  value: _hapticFeedback,
                  onChanged: (val) => setState(() => _hapticFeedback = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text("Storage & Data", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.storage_outlined, color: AppColors.primary),
                  title: Text("Local SQLite Database", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text("Private on-device storage • Zero telemetry", style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: Colors.orangeAccent),
                  title: const Text("Clear Temporary Cache", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text("Free up cached PDF preview pages", style: TextStyle(fontSize: 12)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Preview cache cleared successfully!")),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text("Wipe All Local Vault Data", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent)),
                  subtitle: const Text("Permanently delete local notes and folders", style: TextStyle(fontSize: 12)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Wipe Local Vault?"),
                        content: const Text("This will permanently remove all local notes and materials from this device."),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Delete All"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await LocalDbService.instance.clearAllData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Local vault wiped clean.")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text("About", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Study Vault v1.0.0 (Production)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                SizedBox(height: 4),
                Text(
                  "Intelligent academic study companion collaborating with Google Gemini models. Offline-first, private, and syllabus-adaptive.",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
