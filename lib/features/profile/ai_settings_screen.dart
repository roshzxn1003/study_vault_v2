import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Comprehensive AI Intelligence & Privacy Settings Screen.
/// Manages model selection (Gemini & Claude), API credentials, key acquisition guides,
/// RAG access permissions, and pedagogical response style.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _claudeKeyController = TextEditingController();
  bool _isAiEnabled = true;
  bool _isVaultContextEnabled = true;
  String _selectedModel = AiConfig.primaryModel;
  String _preferredStyle = 'socratic';
  bool _obscureKey = true;
  bool _obscureClaudeKey = true;
  bool _isTestingKey = false;
  bool _keyValidated = false;
  bool _claudeKeySaved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final key = await AiConfig.getApiKey();
    final claudeKey = await AiConfig.getClaudeApiKey();
    final model = await AiConfig.getSelectedModel();
    final enabled = await AiConfig.isAiEnabled();
    final vaultContext = await AiConfig.isVaultContextEnabled();
    final style = await AiConfig.getPreferredResponseStyle();

    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _claudeKeyController.text = claudeKey;
        _selectedModel = model;
        _isAiEnabled = enabled;
        _isVaultContextEnabled = vaultContext;
        _preferredStyle = style;
        _keyValidated = key.isNotEmpty;
        _claudeKeySaved = claudeKey.isNotEmpty;
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
          const SnackBar(content: Text('Gemini API key removed. Running in offline/fallback mode.')),
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

  Future<void> _saveClaudeApiKey() async {
    final key = _claudeKeyController.text.trim();
    await AiConfig.setClaudeApiKey(key);
    if (mounted) {
      setState(() => _claudeKeySaved = key.isNotEmpty);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isNotEmpty
              ? '✨ Anthropic Claude API key saved securely on device!'
              : 'Claude API key cleared.'),
          backgroundColor: key.isNotEmpty ? AppColors.emerald : AppColors.amber,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching browser: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _claudeKeyController.dispose();
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

          // 🔑 Interactive Guide: How to Get Free & Pro API Keys
          _buildApiKeyGuideCard(context),

          const SizedBox(height: AppSpacing.md),

          // Google Gemini API Configuration Card
          _buildGeminiConfigCard(context),

          const SizedBox(height: AppSpacing.md),

          // Anthropic Claude API Configuration Card
          _buildClaudeConfigCard(context),

          const SizedBox(height: AppSpacing.md),

          // Vault Context Privacy Permission (RAG)
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
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                    'Privacy Commitment: Your notes and PDFs are parsed locally on your device. Only small, relevant text snippets are sent to Gemini or Claude when answering specific study queries. Your private notes are never used for model training.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Builds the interactive step-by-step API Key Acquisition Guide Card.
  Widget _buildApiKeyGuideCard(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !_keyValidated && !_claudeKeySaved,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.help_outline_rounded, color: AppColors.primaryLight, size: 20),
          ),
          title: const Text(
            'How to Get Free & Pro API Keys',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          subtitle: const Text(
            'Step-by-step instructions for Google Gemini (Free) & Anthropic Claude',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.cardBorder),
                  const SizedBox(height: 8),

                  // Gemini Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x2210B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('100% FREE', style: TextStyle(color: AppColors.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            const Text('Google Gemini API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Visit Google AI Studio with your Google account.\n'
                          '2. Click "Get API Key" or "Create API Key in new project".\n'
                          '3. Copy the string starting with "AIzaSy...".\n'
                          '4. Paste below and tap "Save & Verify Key".',
                          style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryLight),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Open Google AI Studio (aistudio.google.com)'),
                          onPressed: () => _openUrl('https://aistudio.google.com/'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Claude Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x228B5CF6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('PRO REASONING', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            const Text('Anthropic Claude API Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Visit Anthropic Console and create/sign into your account.\n'
                          '2. Navigate to "API Keys" in settings.\n'
                          '3. Click "Create Key", name it "StudyVault", and copy the key starting with "sk-ant-api03-...".\n'
                          '4. Paste below in the Claude key card.',
                          style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF8B5CF6)),
                            foregroundColor: const Color(0xFF8B5CF6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Open Anthropic Console (console.anthropic.com)'),
                          onPressed: () => _openUrl('https://console.anthropic.com/settings/keys'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the Google Gemini configuration card.
  Widget _buildGeminiConfigCard(BuildContext context) {
    return Container(
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
            'Generous free tier: 15 RPM, 1M TPM. Powers multimodal document search & fast answers.',
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
            'Target Model Selection',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: AiConfig.supportedModels.map((m) {
              final id = m['id']!;
              final name = m['name']!;
              final provider = m['provider']!;
              final tag = m['tag']!;
              return DropdownMenuItem<String>(
                value: id,
                child: Text('$name ($provider - $tag)', style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
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
              label: Text(_isTestingKey ? 'Verifying...' : 'Save & Verify Gemini Key'),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Anthropic Claude configuration card.
  Widget _buildClaudeConfigCard(BuildContext context) {
    return Container(
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
                  Icon(Icons.psychology_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  SizedBox(width: 8),
                  Text(
                    'Anthropic Claude API Key',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ],
              ),
              if (_claudeKeySaved)
                const Chip(
                  label: Text('Saved', style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6))),
                  backgroundColor: Color(0x1A8B5CF6),
                  side: BorderSide(color: Color(0x338B5CF6)),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enables Claude 3.7 Sonnet, Claude 3.5 Sonnet, and Claude 3.5 Haiku for mathematical proofs, coding syntax, and exam synthesis.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _claudeKeyController,
            obscureText: _obscureClaudeKey,
            decoration: InputDecoration(
              hintText: 'sk-ant-api03-...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: IconButton(
                icon: Icon(_obscureClaudeKey ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscureClaudeKey = !_obscureClaudeKey),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saveClaudeApiKey,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Claude API Key'),
            ),
          ),
        ],
      ),
    );
  }
}
