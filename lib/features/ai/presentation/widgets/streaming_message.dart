import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/ai/citation_builder.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';

/// Clean academic message bubble supporting live streaming tokens,
/// Markdown rendering, source citation navigation, and generation control.
class StreamingMessageWidget extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onListen;
  final VoidCallback? onStop;
  final VoidCallback? onRetry;
  final void Function(AiSource source)? onOpenSource;

  const StreamingMessageWidget({
    super.key,
    required this.message,
    this.onListen,
    this.onStop,
    this.onRetry,
    this.onOpenSource,
  });

  Future<void> _saveAsNote(BuildContext context) async {
    final titleMatch = RegExp(r'^#+\s+(.+)$', multiLine: true).firstMatch(message.content);
    final title = titleMatch?.group(1)?.trim() ??
        'AI Study Insight (${DateTime.now().month}/${DateTime.now().day})';

    try {
      final db = await LocalDbService.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.insert('notes', {
        'id': 'note_ai_${DateTime.now().millisecondsSinceEpoch}',
        'user_id': 'guest',
        'title': title,
        'content': message.content,
        'created_at': now,
        'updated_at': now,
        'sync_status': 'synced'
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$title" to Vault Notes'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final isPartial = message.isPartial;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              )
            else ...[
              // Assistant Message Content
              if (message.content.isEmpty && isPartial)
                _buildGeneratingPlaceholder()
              else
                _buildMarkdownContent(context, message.content),

              // Streaming Progress / Typing Indicator
              if (isPartial) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Generating response...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (onStop != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 14, color: AppColors.rose),
                        label: const Text(
                          'Stop',
                          style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onStop,
                      ),
                  ],
                ),
              ],

              // Source Citations
              if (message.sources != null && message.sources!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                _buildSourcesSection(context, message.sources!),
              ],

              // Action Bar
              if (!isPartial) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (onListen != null)
                          IconButton(
                            icon: const Icon(Icons.volume_up_outlined, size: 16),
                            color: AppColors.textSecondary,
                            tooltip: 'Read aloud',
                            onPressed: onListen,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(right: 12),
                          ),
                        IconButton(
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          color: AppColors.textSecondary,
                          tooltip: 'Copy response',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: message.content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied response to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                          color: AppColors.emerald,
                          tooltip: 'Save as Note',
                          onPressed: () => _saveAsNote(context),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 8),
                        ),
                      ],
                    ),
                    if (message.content.contains('⚠️') && onRetry != null)
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Retry', style: TextStyle(fontSize: 12)),
                        onPressed: onRetry,
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
          ),
          SizedBox(width: 8),
          Text(
            'Retrieving vault context...',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(BuildContext context, String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          height: 1.55,
        ),
        h1: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h2: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h3: const TextStyle(
          color: AppColors.primaryLight,
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
        ),
        strong: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        em: const TextStyle(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        tableBorder: TableBorder.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
        tableHead: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryLight,
        ),
        code: const TextStyle(
          backgroundColor: AppColors.surfaceVariant,
          color: AppColors.cyan,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        blockquote: const TextStyle(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
        ),
      ),
    );
  }

  Widget _buildSourcesSection(BuildContext context, List<AiSource> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.source_outlined, size: 14, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text(
              'Grounded Sources (${sources.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sources.map((source) {
            final label = CitationBuilder.formatCitationChip(source);
            return ActionChip(
              avatar: const Icon(Icons.description_outlined, size: 12, color: AppColors.primaryLight),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: () {
                if (onOpenSource != null) {
                  onOpenSource!(source);
                } else {
                  _showSourceDetail(context, source);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showSourceDetail(BuildContext context, AiSource source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    source.fileName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Page ${source.pageNumber} • Grounding Confidence: ${(source.similarity * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (source.snippet != null && source.snippet!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  source.snippet!,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
