import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/providers/ai_providers.dart';
import 'package:study_vault/features/ai/ai_screen.dart';
import 'package:study_vault/features/quiz/presentation/screens/quiz_player_screen.dart';
import 'package:study_vault/features/flashcards/presentation/screens/flashcard_screen.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';

/// Clean academic AI Assistant panel for materials (responsive side panel on tablet/desktop,
/// modal bottom sheet on mobile).
class AiMaterialSidePanel extends ConsumerStatefulWidget {
  final MaterialItem material;
  final VoidCallback? onStatusChanged;

  const AiMaterialSidePanel({
    super.key,
    required this.material,
    this.onStatusChanged,
  });

  static Future<void> showModal(BuildContext context, MaterialItem material) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: AiMaterialSidePanel(material: material),
        ),
      ),
    );
  }

  @override
  ConsumerState<AiMaterialSidePanel> createState() => _AiMaterialSidePanelState();
}

class _AiMaterialSidePanelState extends ConsumerState<AiMaterialSidePanel> {
  bool _isActionRunning = false;
  String? _statusText;

  Future<void> _handleRetryIndexing() async {
    setState(() {
      _isActionRunning = true;
      _statusText = 'Preparing AI search index...';
    });

    try {
      final orchestrator = ref.read(aiOrchestratorProvider);
      await orchestrator.indexMaterial(widget.material.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document indexed successfully for AI search!')),
        );
        widget.onStatusChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Indexing failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionRunning = false;
          _statusText = null;
        });
      }
    }
  }

  void _openChatWithMaterial(String mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AIScreen(
          initialMaterialId: widget.material.id,
          initialMaterialTitle: widget.material.title,
          initialSubject: widget.material.subjectName,
          initialMode: mode,
        ),
      ),
    );
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _isActionRunning = true;
      _statusText = 'Generating exam quiz...';
    });

    try {
      final orchestrator = ref.read(aiOrchestratorProvider);
      await orchestrator.generateQuiz(
        widget.material.title,
        materialId: widget.material.id,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizPlayerScreen(topic: widget.material.title),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quiz generation error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionRunning = false;
          _statusText = null;
        });
      }
    }
  }

  Future<void> _generateFlashcards() async {
    setState(() {
      _isActionRunning = true;
      _statusText = 'Generating flashcards...';
    });

    try {
      final orchestrator = ref.read(aiOrchestratorProvider);
      await orchestrator.generateFlashcards(
        widget.material.title,
        materialId: widget.material.id,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FlashcardScreen(topic: widget.material.title),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flashcard generation error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionRunning = false;
          _statusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.material.indexingStatus?.toUpperCase() ?? 'NOT_INDEXED';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Drag Handle (on mobile sheet)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title & Indexing Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_outlined, color: AppColors.primaryLight, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'AI Study Assistant',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildStatusBadge(status),
            ],
          ),

          const SizedBox(height: 6),
          Text(
            'Powered by grounded intelligence for "${widget.material.title}"',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),

          // Action Loading Indicator
          if (_isActionRunning) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusText ?? 'Processing with AI...',
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryLight),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quick Study Actions
          Expanded(
            child: ListView(
              children: [
                _buildActionTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Ask Questions About This Material',
                  subtitle: 'Grounded answers with page citations from your notes',
                  onTap: () => _openChatWithMaterial('ask'),
                ),
                _buildActionTile(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Socratic Concept Breakdown',
                  subtitle: 'Understand core invariants with mental models and analogies',
                  onTap: () => _openChatWithMaterial('tutor'),
                ),
                _buildActionTile(
                  icon: Icons.summarize_outlined,
                  title: 'Exhaustive Chapter Summary',
                  subtitle: 'Key principles, algorithms, and high-yield review takeaways',
                  onTap: () => _openChatWithMaterial('summarize'),
                ),
                _buildActionTile(
                  icon: Icons.quiz_outlined,
                  title: 'Generate Practice Quiz',
                  subtitle: '4-option multiple-choice questions with answers & explanations',
                  onTap: _isActionRunning ? null : _generateQuiz,
                ),
                _buildActionTile(
                  icon: Icons.flip_to_front_rounded,
                  title: 'Create Active-Recall Flashcards',
                  subtitle: 'High-yield front/back study cards ready for revision decks',
                  onTap: _isActionRunning ? null : _generateFlashcards,
                ),

                if (status == 'FAILED' || status == 'NOT_INDEXED') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(status == 'FAILED' ? 'Retry AI Search Indexing' : 'Index for AI Search'),
                    onPressed: _isActionRunning ? null : _handleRetryIndexing,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'INDEXED':
        bg = AppColors.emerald.withValues(alpha: 0.15);
        fg = AppColors.emerald;
        label = 'AI Ready';
        icon = Icons.check_circle_outline;
        break;
      case 'INDEXING':
        bg = AppColors.amber.withValues(alpha: 0.15);
        fg = AppColors.amber;
        label = 'Indexing...';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'FAILED':
        bg = AppColors.rose.withValues(alpha: 0.15);
        fg = AppColors.rose;
        label = 'AI Failed';
        icon = Icons.error_outline;
        break;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        label = 'Not Indexed';
        icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.primaryLight, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
