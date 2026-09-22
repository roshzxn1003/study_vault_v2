import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/material_upload_service.dart';
import 'package:study_vault/core/utils/permission_utils.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/vault/presentation/widgets/create_folder_dialog.dart';

/// Modal bottom sheet allowing students to add study materials from anywhere in the app.
/// Provides direct avenues for uploading files, scanning documents, creating notes, or importing photos.
class AddMaterialSheet extends ConsumerStatefulWidget {
  final String? subjectId;
  final String? folderId;
  final String? workspaceId;
  final String? academicPeriodId;
  final String? destinationLabel;

  const AddMaterialSheet({
    super.key,
    this.subjectId,
    this.folderId,
    this.workspaceId,
    this.academicPeriodId,
    this.destinationLabel,
  });

  /// Displays the modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    String? subjectId,
    String? folderId,
    String? workspaceId,
    String? academicPeriodId,
    String? destinationLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddMaterialSheet(
        subjectId: subjectId,
        folderId: folderId,
        workspaceId: workspaceId,
        academicPeriodId: academicPeriodId,
        destinationLabel: destinationLabel,
      ),
    );
  }

  @override
  ConsumerState<AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends ConsumerState<AddMaterialSheet> {
  late String? _selectedSubjectId;
  late String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
    _selectedFolderId = widget.folderId;
  }

  @override
  Widget build(BuildContext context) {
    final uploadService = ref.read(materialUploadServiceProvider);
    final academicState = ref.watch(academicWorkspaceProvider);
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    final currentSubject = _selectedSubjectId != null
        ? academicState.subjects.where((s) => s.id == _selectedSubjectId).firstOrNull
        : null;

    final destName = currentSubject?.name ?? widget.destinationLabel;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Study Vault',
                          style: AppTypography.title.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destName != null
                              ? 'Saving to: $destName'
                              : 'Select material type to organize into your vault',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              // Destination Subjects Row
              if (academicState.subjects.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'DESTINATION SUBJECT',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Inbox / General'),
                          selected: _selectedSubjectId == null,
                          onSelected: (_) => setState(() => _selectedSubjectId = null),
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundColor: AppColors.surfaceSecondary,
                          labelStyle: AppTypography.caption.copyWith(
                            color: _selectedSubjectId == null ? AppColors.primaryLight : AppColors.textSecondary,
                            fontWeight: _selectedSubjectId == null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      ...academicState.subjects.map((subject) {
                        final isSel = _selectedSubjectId == subject.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(subject.code?.isNotEmpty == true ? '${subject.code} - ${subject.name}' : subject.name),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedSubjectId = subject.id),
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundColor: AppColors.surfaceSecondary,
                            labelStyle: AppTypography.caption.copyWith(
                              color: isSel ? AppColors.primaryLight : AppColors.textSecondary,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Option 1: PDF Document
              _buildActionTile(
                context: context,
                icon: Icons.picture_as_pdf_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFEF4444).withValues(alpha: 0.15),
                title: 'PDF Document',
                subtitle: 'Syllabus, question papers, chapters, textbook PDFs',
                badge: 'PDF',
                onTap: () async {
                  Navigator.of(context).pop();
                  await uploadService.pickAndUploadFiles(
                    context: context,
                    subjectId: _selectedSubjectId,
                    folderId: _selectedFolderId,
                    workspaceId: widget.workspaceId,
                    academicPeriodId: widget.academicPeriodId,
                    customAllowedExtensions: ['pdf'],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 2: General Documents (Office & Slides)
              _buildActionTile(
                context: context,
                icon: Icons.upload_file_rounded,
                iconColor: AppColors.primaryLight,
                iconBg: AppColors.primary.withValues(alpha: 0.15),
                title: 'Office Documents & Slides',
                subtitle: 'PowerPoint presentations, Word notes, Excel sheets',
                badge: 'DOC, PPT, XLS',
                onTap: () async {
                  Navigator.of(context).pop();
                  await uploadService.pickAndUploadFiles(
                    context: context,
                    subjectId: _selectedSubjectId,
                    folderId: _selectedFolderId,
                    workspaceId: widget.workspaceId,
                    academicPeriodId: widget.academicPeriodId,
                    customAllowedExtensions: [
                      'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'rtf', 'csv', 'epub',
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 3: Create Study Note
              _buildActionTile(
                context: context,
                icon: Icons.edit_note_rounded,
                iconColor: AppColors.amber,
                iconBg: AppColors.amber.withValues(alpha: 0.15),
                title: 'Create Study Note',
                subtitle: 'Rich markdown, lecture summaries, key formulas',
                badge: 'Markdown',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/notes/create');
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 4: Scan Document / Camera OCR
              _buildActionTile(
                context: context,
                icon: Icons.document_scanner_rounded,
                iconColor: AppColors.emerald,
                iconBg: AppColors.emerald.withValues(alpha: 0.15),
                title: 'Scan Document (OCR)',
                subtitle: 'Capture textbook pages or handwritten notes with camera',
                badge: 'Camera',
                onTap: () async {
                  Navigator.of(context).pop();
                  final hasCam = await PermissionUtils.requestCameraPermission(context: context);
                  if (hasCam && context.mounted) {
                    context.push('/scan');
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 5: Import Photos / Gallery
              _buildActionTile(
                context: context,
                icon: Icons.photo_library_rounded,
                iconColor: AppColors.cyan,
                iconBg: AppColors.cyan.withValues(alpha: 0.15),
                title: 'Photos & Diagrams',
                subtitle: 'Board captures, assignment photos, diagrams',
                badge: 'Gallery',
                onTap: () async {
                  Navigator.of(context).pop();
                  await uploadService.pickFromGallery(
                    context: context,
                    subjectId: _selectedSubjectId,
                    folderId: _selectedFolderId,
                    workspaceId: widget.workspaceId,
                    academicPeriodId: widget.academicPeriodId,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 6: Add Web Link / Online Resource
              _buildActionTile(
                context: context,
                icon: Icons.link_rounded,
                iconColor: const Color(0xFF8B5CF6),
                iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                title: 'Add Web Link',
                subtitle: 'Online study guides, articles, references, YouTube lectures',
                badge: 'URL',
                onTap: () {
                  Navigator.of(context).pop();
                  _showAddLinkDialog(context, uploadService);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Option 7: New Folder
              _buildActionTile(
                context: context,
                icon: Icons.create_new_folder_rounded,
                iconColor: const Color(0xFF38BDF8),
                iconBg: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                title: 'New Folder',
                subtitle: 'Create a structured folder for units, modules, or lab files',
                badge: 'Folder',
                onTap: () async {
                  Navigator.of(context).pop();
                  final name = await CreateFolderDialog.show(context: context);
                  if (name != null && name.trim().isNotEmpty) {
                    await ref.read(vaultProvider.notifier).createFolder(name.trim(), parentId: _selectedFolderId);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddLinkDialog(BuildContext context, MaterialUploadService uploadService) {
    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        title: Text('Add Web Link', style: AppTypography.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL (https://...)',
                hintText: 'https://example.com/study-notes',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title (Optional)',
                hintText: 'e.g. Unit 2 Reference Article',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              await uploadService.addLinkMaterial(
                context: context,
                url: url,
                title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : url,
                subjectId: _selectedSubjectId,
                folderId: _selectedFolderId,
                workspaceId: widget.workspaceId,
                academicPeriodId: widget.academicPeriodId,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Link'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            badge,
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
