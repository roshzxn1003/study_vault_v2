import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';

class MaterialAttachmentDialog extends ConsumerStatefulWidget {
  const MaterialAttachmentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MaterialAttachmentDialog(),
    );
  }

  @override
  ConsumerState<MaterialAttachmentDialog> createState() => _MaterialAttachmentDialogState();
}

class _MaterialAttachmentDialogState extends ConsumerState<MaterialAttachmentDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vaultState = ref.watch(vaultProvider);
    final chatState = ref.watch(chatProvider);
    final isDark = theme.brightness == Brightness.dark;

    final allMaterials = vaultState.materials;
    final filtered = _filterQuery.isEmpty
        ? allMaterials
        : allMaterials.where((m) {
            final t = m.title.toLowerCase();
            final s = (m.subjectName ?? '').toLowerCase();
            return t.contains(_filterQuery.toLowerCase()) || s.contains(_filterQuery.toLowerCase());
          }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Material to Ask',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'AI will focus answers on the selected document',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _filterQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search study materials...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _filterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filterQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF282830) : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Option: All Materials Scope
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: chatState.activeMaterialId == null
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                tileColor: chatState.activeMaterialId == null
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : (isDark ? const Color(0xFF282830) : const Color(0xFFF9FAFB)),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.all_inclusive_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(
                  'Search All Materials',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: chatState.activeMaterialId == null
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
                subtitle: const Text('AI retrieves across your entire Study Vault library'),
                trailing: chatState.activeMaterialId == null
                    ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(chatProvider.notifier).clearMaterial();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Material list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 44,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filterQuery.isEmpty
                              ? 'No study materials uploaded yet'
                              : 'No materials match "$_filterQuery"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = chatState.activeMaterialId == item.id;
                      final typeColor = item.type.color;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isDark ? Colors.white12 : Colors.black12),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            tileColor: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : (isDark ? const Color(0xFF25252D) : Colors.white),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item.type.icon,
                                color: typeColor,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? theme.colorScheme.primary : null,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (item.subjectName != null) ...[
                                  Text(
                                    item.subjectName!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('•', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  item.type.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                                : const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref.read(chatProvider.notifier).setMaterial(item.id, item.title);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
