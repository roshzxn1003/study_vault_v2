import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import 'package:study_vault/core/services/material_upload_service.dart';
import 'package:study_vault/features/academic/presentation/providers/academic_workspace_provider.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/vault/presentation/widgets/create_folder_dialog.dart';

enum AddMaterialStep { chooseType, enterDetails, completion }

enum MaterialSourceType {
  document(title: 'Document', subtitle: 'Word, PowerPoint, Excel, text files', icon: Icons.description_rounded, color: AppColors.primaryLight),
  pdf(title: 'PDF Document', subtitle: 'Lecture slides, textbook chapters, exams', icon: Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444)),
  note(title: 'Study Note', subtitle: 'Markdown notes, formulas, lecture summaries', icon: Icons.edit_note_rounded, color: AppColors.amber),
  scan(title: 'Scan Document', subtitle: 'Camera OCR, handwritten sheets, textbooks', icon: Icons.document_scanner_rounded, color: AppColors.emerald),
  image(title: 'Photos & Diagrams', subtitle: 'Whiteboard photos, diagrams, illustrations', icon: Icons.photo_library_rounded, color: AppColors.cyan),
  link(title: 'Web Link', subtitle: 'Online references, YouTube lectures, articles', icon: Icons.link_rounded, color: Color(0xFF8B5CF6)),
  folder(title: 'New Folder', subtitle: 'Create a unit or topic folder', icon: Icons.create_new_folder_rounded, color: Color(0xFF38BDF8));

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const MaterialSourceType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  AddMaterialStep _currentStep = AddMaterialStep.chooseType;
  MaterialSourceType _selectedType = MaterialSourceType.pdf;

  // Step 2 Form controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];

  String? _selectedSubjectId;
  String? _selectedFolderId;
  bool _isProcessing = false;
  double _uploadProgress = 0.0;
  String? _createdMaterialId;
  String? _createdMaterialTitle;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _onSelectType(MaterialSourceType type) {
    if (type == MaterialSourceType.scan) {
      context.push('/scan');
      return;
    }

    if (type == MaterialSourceType.folder) {
      _showCreateFolderModal();
      return;
    }

    setState(() {
      _selectedType = type;
      _currentStep = AddMaterialStep.enterDetails;
    });
  }

  void _showCreateFolderModal() async {
    final folderName = await CreateFolderDialog.show(context: context);
    if (folderName != null && folderName.trim().isNotEmpty && mounted) {
      await ref.read(vaultProvider.notifier).createFolder(folderName.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder "$folderName" created successfully!'),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/library');
      }
    }
  }

  Future<void> _handleSave() async {
    final uploadService = ref.read(materialUploadServiceProvider);
    final title = _titleController.text.trim();

    setState(() {
      _isProcessing = true;
      _uploadProgress = 0.2;
    });

    try {
      if (_selectedType == MaterialSourceType.note) {
        if (title.isEmpty && _contentController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter note title or content')),
          );
          setState(() => _isProcessing = false);
          return;
        }

        setState(() => _uploadProgress = 0.6);
        final noteItem = await uploadService.createMarkdownNote(
          context: context,
          title: title.isEmpty ? 'Untitled Study Note' : title,
          content: _contentController.text.trim(),
          subjectId: _selectedSubjectId,
          folderId: _selectedFolderId,
        );

        setState(() {
          _uploadProgress = 1.0;
          _createdMaterialId = noteItem?.id;
          _createdMaterialTitle = noteItem?.title ?? title;
          _currentStep = AddMaterialStep.completion;
        });
      } else if (_selectedType == MaterialSourceType.link) {
        final url = _linkController.text.trim();
        if (url.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid web URL')),
          );
          setState(() => _isProcessing = false);
          return;
        }

        setState(() => _uploadProgress = 0.7);
        final linkItem = await uploadService.addLinkMaterial(
          context: context,
          url: url,
          title: title.isNotEmpty ? title : url,
          subjectId: _selectedSubjectId,
          folderId: _selectedFolderId,
        );

        setState(() {
          _uploadProgress = 1.0;
          _createdMaterialId = linkItem?.id;
          _createdMaterialTitle = linkItem?.title ?? (title.isNotEmpty ? title : url);
          _currentStep = AddMaterialStep.completion;
        });
      } else if (_selectedType == MaterialSourceType.image) {
        setState(() => _uploadProgress = 0.5);
        final items = await uploadService.pickFromGallery(
          context: context,
          subjectId: _selectedSubjectId,
          folderId: _selectedFolderId,
        );

        if (items.isNotEmpty) {
          setState(() {
            _uploadProgress = 1.0;
            _createdMaterialId = items.first.id;
            _createdMaterialTitle = items.first.title;
            _currentStep = AddMaterialStep.completion;
          });
        } else {
          setState(() => _isProcessing = false);
        }
      } else {
        // Document or PDF
        setState(() => _uploadProgress = 0.5);
        final customExts = _selectedType == MaterialSourceType.pdf ? ['pdf'] : null;
        final items = await uploadService.pickAndUploadFiles(
          context: context,
          subjectId: _selectedSubjectId,
          folderId: _selectedFolderId,
          customAllowedExtensions: customExts,
        );

        if (items.isNotEmpty) {
          setState(() {
            _uploadProgress = 1.0;
            _createdMaterialId = items.first.id;
            _createdMaterialTitle = items.first.title;
            _currentStep = AddMaterialStep.completion;
          });
        } else {
          setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving material: $e'), backgroundColor: AppColors.rose),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = AddMaterialStep.chooseType;
      _titleController.clear();
      _contentController.clear();
      _linkController.clear();
      _tagController.clear();
      _tags.clear();
      _uploadProgress = 0.0;
      _createdMaterialId = null;
      _createdMaterialTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Material'),
        leading: _currentStep != AddMaterialStep.chooseType && _currentStep != AddMaterialStep.completion
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _currentStep = AddMaterialStep.chooseType),
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.go('/home'),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Indicator
              _buildStepIndicator(),
              const SizedBox(height: AppSpacing.lg),

              // Step Content
              if (_currentStep == AddMaterialStep.chooseType)
                _buildChooseTypeStep()
              else if (_currentStep == AddMaterialStep.enterDetails)
                _buildEnterDetailsStep()
              else
                _buildCompletionStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepBadge(1, 'Type', _currentStep == AddMaterialStep.chooseType, _currentStep != AddMaterialStep.chooseType),
        Expanded(child: Container(height: 2, color: _currentStep != AddMaterialStep.chooseType ? AppColors.primaryLight : AppColors.border)),
        _buildStepBadge(2, 'Details', _currentStep == AddMaterialStep.enterDetails, _currentStep == AddMaterialStep.completion),
        Expanded(child: Container(height: 2, color: _currentStep == AddMaterialStep.completion ? AppColors.primaryLight : AppColors.border)),
        _buildStepBadge(3, 'Saved', _currentStep == AddMaterialStep.completion, false),
      ],
    );
  }

  Widget _buildStepBadge(int step, String label, bool isActive, bool isDone) {
    final color = isActive
        ? AppColors.primaryLight
        : isDone
            ? AppColors.emerald
            : AppColors.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDone ? AppColors.emerald.withValues(alpha: 0.2) : (isActive ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceSecondary),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 14, color: AppColors.emerald)
                : Text(
                    '$step',
                    style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildChooseTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Material Format',
          style: AppTypography.headline.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose what you would like to store and index into your academic vault.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        ...MaterialSourceType.values.map((type) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onSelectType(type),
                borderRadius: AppRadius.card,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: type.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(type.icon, color: type.color, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.title,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type.subtitle,
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEnterDetailsStep() {
    final academicState = ref.watch(academicWorkspaceProvider);
    final vaultState = ref.watch(vaultProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_selectedType.icon, color: _selectedType.color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add ${_selectedType.title}',
              style: AppTypography.headline.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Fill in academic tags, topic, and details to organize accurately.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Title Field
        Text('TITLE', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'e.g., Chapter 4: Database Transactions',
            prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primaryLight),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: AppRadius.field, borderSide: BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Type Specific Field
        if (_selectedType == MaterialSourceType.link) ...[
          Text('WEB URL', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: _linkController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://...',
              prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF8B5CF6)),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: AppRadius.field, borderSide: BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else if (_selectedType == MaterialSourceType.note) ...[
          Text('NOTE CONTENT (MARKDOWN)', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          TextField(
            controller: _contentController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Write or paste formulas, lecture points, code snippets...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: AppRadius.field, borderSide: BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Subject Selector
        Text('ACADEMIC SUBJECT', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.field,
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedSubjectId,
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              hint: Text('Select Subject (Optional)', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('General / Unassigned', style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                ),
                ...academicState.subjects.map((sub) => DropdownMenuItem<String?>(
                      value: sub.id,
                      child: Text(
                        sub.code?.isNotEmpty == true ? '${sub.code} - ${sub.name}' : sub.name,
                        style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                      ),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedSubjectId = val),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Folder Selector
        if (vaultState.folders.isNotEmpty) ...[
          Text('FOLDER / TOPIC', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.field,
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedFolderId,
                isExpanded: true,
                dropdownColor: AppColors.surfaceElevated,
                hint: Text('Select Folder (Optional)', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Root Directory', style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                  ),
                  ...vaultState.folders.map((f) => DropdownMenuItem<String?>(
                        value: f.id,
                        child: Text(f.name, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedFolderId = val),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Tags Input
        Text('TAGS & LABELS', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Add tag (e.g. Unit 3, Exam Prep)',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: AppRadius.field, borderSide: BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (tag) {
                  if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
                    setState(() {
                      _tags.add(tag.trim());
                      _tagController.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                final tag = _tagController.text.trim();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() {
                    _tags.add(tag);
                    _tagController.clear();
                  });
                }
              },
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _tags.map((t) {
              return Chip(
                label: Text(t, style: AppTypography.caption.copyWith(color: AppColors.primaryLight)),
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                onDeleted: () => setState(() => _tags.remove(t)),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // Progress Bar (if processing)
        if (_isProcessing) ...[
          LinearProgressIndicator(value: _uploadProgress, color: AppColors.primaryLight, backgroundColor: AppColors.surfaceSecondary),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Saving & indexing material...',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Action Buttons
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
            child: Text(
              _selectedType == MaterialSourceType.document || _selectedType == MaterialSourceType.pdf
                  ? 'Select File & Save'
                  : 'Save to Vault',
              style: AppTypography.button,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionStep() {
    final title = _createdMaterialTitle ?? 'Material';

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 54, color: AppColors.emerald),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Saved Successfully!',
          style: AppTypography.headline.copyWith(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        const SizedBox(height: 6),
        Text(
          '"$title" is now indexed in your study vault.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Quick Actions
        if (_createdMaterialId != null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Material'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
              ),
              onPressed: () {
                context.go('/vault/material/$_createdMaterialId');
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Another Material'),
            onPressed: _resetForm,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () => context.go('/library'),
            child: Text('Return to Library', style: AppTypography.button.copyWith(color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }
}
