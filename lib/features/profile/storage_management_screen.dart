import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/storage_manager_service.dart';
import 'package:study_vault/core/services/memory_manager_service.dart';

/// Screen offering full visibility into mobile storage, document files,
/// cache usage, and safe 1-tap memory/cache pruning.
class StorageManagementScreen extends ConsumerStatefulWidget {
  final bool initialLoading;
  final StorageBreakdown? initialBreakdown;

  const StorageManagementScreen({
    super.key,
    this.initialLoading = true,
    this.initialBreakdown,
  });

  @override
  ConsumerState<StorageManagementScreen> createState() => _StorageManagementScreenState();
}

class _StorageManagementScreenState extends ConsumerState<StorageManagementScreen> {
  StorageBreakdown? _breakdown;
  List<FileSystemEntity> _documentsList = [];
  late bool _isLoading;
  bool _isCleaning = false;

  @override
  void initState() {
    super.initState();
    _isLoading = widget.initialLoading;
    _breakdown = widget.initialBreakdown;
    if (_isLoading) {
      _loadStorageData();
    }
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    try {
      final breakdown = await StorageManagerService.instance.calculateStorageBreakdown();
      final docsDir = await StorageManagerService.instance.getDocumentsDirectory();
      List<FileSystemEntity> files = [];
      if (await docsDir.exists()) {
        files = await docsDir.list().toList();
      }
      if (mounted) {
        setState(() {
          _breakdown = breakdown;
          _documentsList = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSafeCacheClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: AppColors.primaryLight, size: 22),
            const SizedBox(width: 8),
            Text('Clear Temporary Cache?', style: AppTypography.title),
          ],
        ),
        content: Text(
          'This will safely delete temporary file previews, cloud download caches, and OCR scratchpad files.\n\nYour permanent Vault documents, notes, and study plans will remain 100% safe.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Cache', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isCleaning = true);
      final bytesFreed = await StorageManagerService.instance.clearSafeCache();
      MemoryManagerService.instance.trimMemory();

      await _loadStorageData();
      if (mounted) {
        setState(() => _isCleaning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleaned! Freed ${_breakdown?.formatBytes(bytesFreed) ?? "space"}.'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          'Storage & File Manager',
          style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh metrics',
            onPressed: _loadStorageData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : RefreshIndicator(
              color: AppColors.primaryLight,
              onRefresh: _loadStorageData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: AppSpacing.md),
                  _buildActionsRow(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDocumentsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    final b = _breakdown ?? const StorageBreakdown();
    final total = b.totalBytes > 0 ? b.totalBytes.toDouble() : 1.0;

    final docRatio = (b.documentsBytes / total).clamp(0.02, 1.0);
    final cacheRatio = (b.cacheBytes / total).clamp(0.02, 1.0);
    final dbRatio = (b.databaseBytes / total).clamp(0.02, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Storage Usage',
                    style: AppTypography.subtitle.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.formattedTotal,
                    style: AppTypography.headline.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: AppColors.primaryLight),
                    const SizedBox(width: 4),
                    Text(
                      'Optimized',
                      style: AppTypography.caption.copyWith(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Visual Multi-Color Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Flexible(flex: (docRatio * 100).toInt(), child: Container(color: AppColors.fileNote)),
                  const SizedBox(width: 2),
                  Flexible(flex: (cacheRatio * 100).toInt(), child: Container(color: AppColors.fileImage)),
                  const SizedBox(width: 2),
                  Flexible(flex: (dbRatio * 100).toInt(), child: Container(color: AppColors.fileFolder)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Vault Files', b.formattedDocuments, AppColors.fileNote),
              _buildLegendItem('Temp Cache', b.formattedCache, AppColors.fileImage),
              _buildLegendItem('Database', b.formattedDatabase, AppColors.fileFolder),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
            Text(value, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isCleaning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.cleaning_services_rounded, size: 18),
            label: const Text('Clear Cache (Safe)', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _isCleaning ? null : _handleSafeCacheClear,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.memory_rounded, size: 18, color: AppColors.primaryLight),
          label: const Text('Flush RAM', style: TextStyle(fontWeight: FontWeight.w600)),
          onPressed: () {
            MemoryManagerService.instance.trimMemory();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Decoded image caches flushed from RAM.'),
                backgroundColor: AppColors.emerald,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Permanent Vault Documents (${_documentsList.length})',
              style: AppTypography.title.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.shield_outlined, size: 16, color: AppColors.emerald),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Protected user documents. Stored securely and excluded from cache clearing.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_documentsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No local files saved in Vault yet.\nImport PDFs or Notes to see them here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          )
        else
          ..._documentsList.map((file) {
            final fileName = file.path.split('/').last;
            final isPdf = fileName.toLowerCase().endsWith('.pdf');
            final isTxt = fileName.toLowerCase().endsWith('.txt') || fileName.toLowerCase().endsWith('.md');

            int size = 0;
            if (file is File) {
              try {
                size = file.lengthSync();
              } catch (_) {}
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
                border: Border.all(color: AppColors.border, width: 1.1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPdf
                          ? AppColors.filePdf.withValues(alpha: 0.15)
                          : isTxt
                              ? AppColors.fileNote.withValues(alpha: 0.15)
                              : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : isTxt
                              ? Icons.description_rounded
                              : Icons.insert_drive_file_rounded,
                      color: isPdf
                          ? AppColors.filePdf
                          : isTxt
                              ? AppColors.fileNote
                              : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _breakdown?.formatBytes(size) ?? '',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20),
                    tooltip: 'Delete file',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Delete File?'),
                          content: Text('Are you sure you want to delete "$fileName"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && file is File) {
                        await file.delete();
                        await _loadStorageData();
                      }
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
