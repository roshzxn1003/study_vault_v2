import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_vault/core/ai/ai_config.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';

/// Comprehensive AI Intelligence, Research Rigor & Privacy Settings Screen.
/// Manages model selection (Gemini & Claude), API credentials, key acquisition guides,
/// academic research depth, temperature determinism, Socratic hinting, and device optimization.
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
  bool _obscureKey = true;
  bool _obscureClaudeKey = true;
  bool _isTestingKey = false;
  bool _keyValidated = false;
  bool _claudeKeySaved = false;
  bool _isLoading = true;

  // Professional Research & Academic Rigor State
  String _researchDepth = 'balanced';
  double _temperature = 0.4;
  String _academicLevel = 'undergraduate';
  bool _citationFootnotes = true;
  bool _socraticMode = true;
  String _tokenBudget = 'standard';
  bool _batterySaver = false;
  bool _streamResponses = true;

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

    // Research options
    final depth = await AiConfig.getResearchDepth();
    final temp = await AiConfig.getTemperature();
    final level = await AiConfig.getAcademicLevel();
    final citations = await AiConfig.isCitationFootnotesEnabled();
    final socratic = await AiConfig.isSocraticModeEnabled();
    final budget = await AiConfig.getTokenBudget();
    final batterySaver = await AiConfig.isBatterySaverEnabled();
    final streamResponses = await AiConfig.isStreamResponsesEnabled();

    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _claudeKeyController.text = claudeKey;
        _selectedModel = model;
        _isAiEnabled = enabled;
        _isVaultContextEnabled = vaultContext;
        _keyValidated = key.isNotEmpty;
        _claudeKeySaved = claudeKey.isNotEmpty;

        _researchDepth = depth;
        _temperature = temp;
        _academicLevel = level;
        _citationFootnotes = citations;
        _socraticMode = socratic;
        _tokenBudget = budget;
        _batterySaver = batterySaver;
        _streamResponses = streamResponses;

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

  Future<void> _saveResearchDepth(String depth) async {
    setState(() => _researchDepth = depth);
    await AiConfig.setResearchDepth(depth);
  }

  Future<void> _saveTemperature(double temp) async {
    setState(() => _temperature = temp);
    await AiConfig.setTemperature(temp);
  }

  Future<void> _saveAcademicLevel(String level) async {
    setState(() => _academicLevel = level);
    await AiConfig.setAcademicLevel(level);
  }

  Future<void> _saveCitationFootnotes(bool val) async {
    setState(() => _citationFootnotes = val);
    await AiConfig.setCitationFootnotesEnabled(val);
  }

  Future<void> _saveSocraticMode(bool val) async {
    setState(() => _socraticMode = val);
    await AiConfig.setSocraticModeEnabled(val);
  }

  Future<void> _saveTokenBudget(String budget) async {
    setState(() => _tokenBudget = budget);
    await AiConfig.setTokenBudget(budget);
  }

  Future<void> _saveBatterySaver(bool val) async {
    setState(() => _batterySaver = val);
    await AiConfig.setBatterySaverEnabled(val);
  }

  Future<void> _saveStreamResponses(bool val) async {
    setState(() => _streamResponses = val);
    await AiConfig.setStreamResponsesEnabled(val);
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
              ? 'Connected to Google Gemini successfully ($_selectedModel)!'
              : 'Key saved, but verification failed. Please verify API Studio permissions.'),
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
              ? 'Anthropic Claude API key saved securely on device!'
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
        title: const Text('AI & Privacy Settings'),
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
              // 1. MASTER AI STATUS
              // ===================================================================
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
                    'Powers scholarly research, Socratic tutoring, document Q&A, and exam synthesis.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  value: _isAiEnabled,
                  onChanged: _saveAiEnabled,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ===================================================================
              // 2. MODEL & API KEYS ORCHESTRATION
              // ===================================================================
              _buildSectionHeader('MODEL ORCHESTRATION & CREDENTIALS'),
              _buildApiKeyGuideCard(context),
              const SizedBox(height: AppSpacing.sm),
              _buildGeminiConfigCard(context),
              const SizedBox(height: AppSpacing.sm),
              _buildClaudeConfigCard(context),

              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 3. RESEARCH RIGOR & ACADEMIC PERSONA
              // ===================================================================
              _buildSectionHeader('RESEARCH RIGOR & ACADEMIC SYNTHESIS'),
              _buildResearchRigorCard(context),

              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 4. REASONING TEMPERATURE & PEDAGOGICAL CONTROL
              // ===================================================================
              _buildSectionHeader('REASONING & PEDAGOGICAL CONTROL'),
              _buildReasoningAndSocraticCard(context),

              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 5. VAULT GROUNDING, CITATIONS & TOKEN BUDGET
              // ===================================================================
              _buildSectionHeader('VAULT GROUNDING & CITATION EVIDENCE'),
              _buildGroundingAndCitationsCard(context),

              const SizedBox(height: AppSpacing.lg),

              // ===================================================================
              // 6. LOW-END MOBILE & PERFORMANCE TUNING
              // ===================================================================
              _buildSectionHeader('DEVICE OPTIMIZATION & PERFORMANCE'),
              _buildPerformanceAndMobileCard(context),

              const SizedBox(height: AppSpacing.lg),

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
                    Icon(Icons.shield_rounded, size: 18, color: AppColors.emerald),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Privacy Commitment: Your documents and notes are parsed and indexed locally on your device. Only relevant, contextual snippets are sent to Gemini or Claude when you request answers. Your private vault is never used for training foundation models.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.45),
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

  /// Interactive step-by-step API Key Acquisition Guide Card.
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
                          '4. Paste below and tap "Save & Verify Gemini Key".',
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

  /// Google Gemini configuration card.
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
            isExpanded: true,
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
                child: Text(
                  '$name ($provider - $tag)',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
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

  /// Anthropic Claude configuration card.
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

  /// Research Rigor and Academic Persona Card.
  Widget _buildResearchRigorCard(BuildContext context) {
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
          const Row(
            children: [
              Icon(Icons.biotech_rounded, size: 20, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text(
                'Academic Depth & Synthesis Rigor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select how thoroughly the AI unpacks research papers, course materials, and technical proofs.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Research Depth Segmented Control
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'summary',
                label: Text('Quick Summary', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.flash_on_rounded, size: 16),
              ),
              ButtonSegment<String>(
                value: 'balanced',
                label: Text('Balanced', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.balance_rounded, size: 16),
              ),
              ButtonSegment<String>(
                value: 'deep',
                label: Text('Deep Scholarly', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.school_rounded, size: 16),
              ),
            ],
            selected: {_researchDepth},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) _saveResearchDepth(set.first);
            },
          ),
          const SizedBox(height: 10),
          Text(
            switch (_researchDepth) {
              'summary' => '⚡ Concise summaries: Core formulas, bullet definitions, minimal token usage.',
              'deep' => '🎓 Exhaustive scholarly rigor: Full theoretical proofs, methodology nuances, and counter-perspectives.',
              _ => '⚖️ Balanced Academic: Structured headings, mental models, code snippets, and key takeaways.',
            },
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 18),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 12),

          const Text(
            'Target Academic Persona',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _academicLevel,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(
                value: 'high_school',
                child: Text('High School / AP & Foundation Prep', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'undergraduate',
                child: Text('Undergraduate University (Default)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'postgraduate',
                child: Text('Postgraduate / Master\'s Research Depth', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'expert',
                child: Text('Doctoral / Subject Matter Specialist', style: TextStyle(fontSize: 13)),
              ),
            ],
            onChanged: (val) {
              if (val != null) _saveAcademicLevel(val);
            },
          ),
        ],
      ),
    );
  }

  /// Reasoning Temperature & Socratic Hinting Card.
  Widget _buildReasoningAndSocraticCard(BuildContext context) {
    final tempLabel = _temperature < 0.25
        ? 'Deterministic & Precise (Formulas, Proofs, Code)'
        : (_temperature <= 0.55
            ? 'Balanced Academic (Coursework & Explanations)'
            : 'Exploratory & Brainstorming (Analogies & Thesis Topics)');

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryLight),
                    SizedBox(width: 8),
                    Text(
                      'Reasoning Temperature',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    _temperature.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Active Mode: $tempLabel',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            Slider(
              value: _temperature,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: AppColors.primaryLight,
              onChanged: _saveTemperature,
            ),

            const Divider(color: AppColors.cardBorder),

            // Socratic Hinting Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: _socraticMode
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _socraticMode ? AppColors.primaryLight : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'Socratic Hinting & Active Recall',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Guides you with incremental hints, questions, and conceptual scaffolds rather than revealing raw answers immediately.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _socraticMode,
              onChanged: _saveSocraticMode,
            ),
          ],
        ),
      ),
    );
  }

  /// Vault Grounding, Citations & Token Budget Card.
  Widget _buildGroundingAndCitationsCard(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vault Context Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: _isVaultContextEnabled
                    ? AppColors.emerald.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.storage_rounded,
                  color: _isVaultContextEnabled ? AppColors.emerald : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'Personal Vault Grounding (RAG)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Allow AI to search through your imported documents, class notes, and textbook PDFs.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _isVaultContextEnabled,
              onChanged: _isAiEnabled ? _saveVaultContext : null,
            ),

            const Divider(color: AppColors.cardBorder),

            // Citation Footnotes Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: _citationFootnotes
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.menu_book_rounded,
                  color: _citationFootnotes ? AppColors.primaryLight : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'Mandatory Citation Footnotes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Strictly cite source filenames and page numbers [Doc: <Title>, Page: <N>] in generated answers.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _citationFootnotes,
              onChanged: _isAiEnabled ? _saveCitationFootnotes : null,
            ),

            const SizedBox(height: 12),
            const Divider(color: AppColors.cardBorder),
            const SizedBox(height: 8),

            const Text(
              'Retrieval Context Window Budget',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'lite',
                  label: Text('Lite (300 tok)', style: TextStyle(fontSize: 11.5)),
                ),
                ButtonSegment<String>(
                  value: 'standard',
                  label: Text('Standard (600 tok)', style: TextStyle(fontSize: 11.5)),
                ),
                ButtonSegment<String>(
                  value: 'deep',
                  label: Text('Deep (1200 tok)', style: TextStyle(fontSize: 11.5)),
                ),
              ],
              selected: {_tokenBudget},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) _saveTokenBudget(set.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Device Optimization and Performance Card.
  Widget _buildPerformanceAndMobileCard(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stream Responses Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: _streamResponses
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.stream_rounded,
                  color: _streamResponses ? AppColors.primaryLight : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'Real-Time Token Streaming',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Render thoughts and sentences word-by-word as generated by Gemini and Claude.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _streamResponses,
              onChanged: _saveStreamResponses,
            ),

            const Divider(color: AppColors.cardBorder),

            // Mobile Battery & Memory Saver Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: CircleAvatar(
                backgroundColor: _batterySaver
                    ? AppColors.amber.withValues(alpha: 0.12)
                    : AppColors.surfaceVariant,
                child: Icon(
                  Icons.battery_saver_rounded,
                  color: _batterySaver ? AppColors.amber : AppColors.textMuted,
                ),
              ),
              title: const Text(
                'Mobile Battery & Memory Saver',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Throttles background vectorization and lowers UI frame rates to prevent battery drain on budget devices.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _batterySaver,
              onChanged: _saveBatterySaver,
            ),
          ],
        ),
      ),
    );
  }
}
