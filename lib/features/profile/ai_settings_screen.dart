import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Comprehensive AI Intelligence & Privacy Settings Screen.
/// Manages model selection, API credentials, RAG access permissions, and pedagogical response style.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _isAiEnabled = true;
  bool _isVaultContextEnabled = true;
  String _selectedModel = AiConfig.primaryModel;
  String _preferredStyle = 'socratic';
  bool _obscureKey = true;
  bool _isTestingKey = false;
  bool _keyValidated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final key = await AiConfig.getApiKey();
    final model = await AiConfig.getSelectedModel();
    final enabled = await AiConfig.isAiEnabled();
    final vaultContext = await AiConfig.isVaultContextEnabled();
    final style = await AiConfig.getPreferredResponseStyle();

    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _selectedModel = model;
        _isAiEnabled = enabled;
        _isVaultContextEnabled = vaultContext;
        _preferredStyle = style;
        _keyValidated = key.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAiEnabled(bool val) async {
    setState(() => _isAiEnabled = val);
    await AiConfig.setAiEnabled(val);
  }

  Future<void> _saveVaultContext(bool val) async {
    setState(() => _isVaultContextEnabled = val);
    await AiConfig.setVaultContextEnabled(val);
  }

  Future<void> _savePreferredStyle(String style) async {
    setState(() => _preferredStyle = style);
    await AiConfig.setPreferredResponseStyle(style);
  }

  Future<void> _saveAndTestApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      await AiConfig.setApiKey('');
      setState(() => _keyValidated = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key removed. Running in offline/fallback mode.')),
        );
      }
      return;
    }

    setState(() => _isTestingKey = true);
    final isValid = await AiConfig.validateApiKey(key);
    await AiConfig.setApiKey(key);
    await AiConfig.setSelectedModel(_selectedModel);

    if (mounted) {
      setState(() {
        _isTestingKey = false;
        _keyValidated = isValid;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isValid
              ? '✨ Connected to Google Gemini successfully ($_selectedModel)!'
              : '⚠️ Key saved, but verification failed. Please verify API Studio permissions.'),
          backgroundColor: isValid ? AppColors.emerald : AppColors.amber,
        ),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & Privacy Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Master AI Enabled Switch
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            child: SwitchListTile(
              secondary: CircleAvatar(
                backgroundColor: _isAiEnabled
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.psychology_outlined,
                  color: _isAiEnabled ? AppColors.primaryLight : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'AI Study Features',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Enable Socratic tutoring, document Q&A, smart summaries, and quizzes.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              value: _isAiEnabled,
              onChanged: _saveAiEnabled,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Vault Context Privacy Permission
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            child: SwitchListTile(
              secondary: CircleAvatar(
                backgroundColor: _isVaultContextEnabled
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.shield_outlined,
                  color: _isVaultContextEnabled ? AppColors.emerald : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'Personal Vault Grounding (RAG)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Allow AI to retrieve relevant snippets from your notes to generate page-cited answers.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              value: _isVaultContextEnabled,
              onChanged: _isAiEnabled ? _saveVaultContext : null,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Response Pedagogy Style
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_outlined, size: 18, color: AppColors.primaryLight),
                    SizedBox(width: 8),
                    Text(
                      'Preferred Teaching Style',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how the AI assistant formats explanations and answers.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _preferredStyle,
                  onChanged: (v) {
                    if (v != null) _savePreferredStyle(v);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Socratic Tutor (Recommended)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('5-step sequence: Intuition, Formal rules, Real-world analogy, Exam pitfalls, Active recall.', style: TextStyle(fontSize: 12)),
                        value: 'socratic',
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: const Text('Concise & Direct', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Bullet-point answers focused directly on facts and equations for fast revision.', style: TextStyle(fontSize: 12)),
                        value: 'concise',
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: const Text('Exhaustive & Technical', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Deep architectural breakdowns, full mathematical proofs, and system trade-offs.', style: TextStyle(fontSize: 12)),
                        value: 'detailed',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Google Gemini API Configuration
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key_rounded, size: 18, color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        Text(
                          'Google Gemini API Key',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ],
                    ),
                    if (_keyValidated)
                      const Chip(
                        label: Text('Verified', style: TextStyle(fontSize: 11, color: AppColors.emerald)),
                        backgroundColor: Color(0x1A10B981),
                        side: BorderSide(color: Color(0x3310B981)),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your free API key from Google AI Studio (aistudio.google.com).',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    hintText: 'AIzaSy...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Target Model',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedModel,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'gemini-1.5-flash',
                      child: Text('gemini-1.5-flash (Fast & Recommended)'),
                    ),
                    DropdownMenuItem(
                      value: 'gemini-2.0-flash',
                      child: Text('gemini-2.0-flash (Next-Gen Flash)'),
                    ),
                    DropdownMenuItem(
                      value: 'gemini-1.5-pro',
                      child: Text('gemini-1.5-pro (High Reasoning Depth)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedModel = val);
                      AiConfig.setSelectedModel(val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isTestingKey ? null : _saveAndTestApiKey,
                    icon: _isTestingKey
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_isTestingKey ? 'Verifying...' : 'Save & Verify Key'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Privacy Architecture Notice
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Privacy Commitment: Your notes and PDFs are parsed locally. Only small, relevant text snippets are sent to Gemini when answering specific questions. Your data is never used to train global models.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
