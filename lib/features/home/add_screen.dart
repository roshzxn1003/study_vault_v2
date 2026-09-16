import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/features/add/presentation/providers/add_provider.dart';
import 'package:study_vault/features/home/presentation/providers/home_provider.dart';
import 'package:study_vault/features/folders/presentation/providers/folders_provider.dart';
import 'package:study_vault/core/services/document_import_service.dart';
import 'package:study_vault/core/theme/app_colors.dart';

class AddScreen extends ConsumerStatefulWidget {
  const AddScreen({super.key});

  @override
  ConsumerState<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends ConsumerState<AddScreen> {
  int _selectedIndex = 1; // Default to Note
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedFolderId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() => _isLoading = true);
    try {
      final actions = ref.read(addActionProvider);
      if (_selectedIndex == 0) {
        if (_nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a folder name")));
          return;
        }
        await actions.createFolder(name: _nameController.text.trim());
        ref.invalidate(foldersProvider);
      } else if (_selectedIndex == 1) {
        if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter note title or content")));
          return;
        }
        await actions.createNote(
          title: _titleController.text.trim().isEmpty ? "Untitled Note" : _titleController.text.trim(),
          content: _contentController.text.trim(),
        );
        ref.invalidate(homeDataProvider);
      } else if (_selectedIndex == 2) {
        final importService = ref.read(documentImportServiceProvider);
        final fileData = await importService.pickAndImportDocument(
          folderId: _selectedFolderId ?? 'folder_dbms',
          context: context,
        );
        if (fileData != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Document '${fileData['name']}' added to Study Vault!"),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.push('/files/${fileData['id']}');
          return;
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added to Study Vault successfully!"),
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Add to Study Vault")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segmented Header
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _tabBtn(0, "Folder", Icons.folder_outlined),
                  _tabBtn(1, "Note", Icons.note_alt_outlined),
                  _tabBtn(2, "Upload PDF", Icons.picture_as_pdf_outlined),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_selectedIndex == 0) ...[
              // Create Folder
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Create Subject Folder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    const Text("Organize lecture slides, notes, and quizzes by academic subject.", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: "Folder / Subject Name",
                        hintText: "e.g., Computer Architecture, Linear Algebra",
                        prefixIcon: Icon(Icons.create_new_folder_outlined, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedIndex == 1) ...[
              // Create Note
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Study Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        foldersAsync.when(
                          data: (folders) => DropdownButton<String>(
                            value: _selectedFolderId ?? (folders.isNotEmpty ? folders.first['id'] : null),
                            dropdownColor: AppColors.surfaceElevated,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryLight),
                            items: folders.map((f) => DropdownMenuItem<String>(
                              value: f['id'],
                              child: Text(f['name'], style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedFolderId = val),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (e, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "Note Title",
                        hintText: "e.g., ACID Properties & Serializability",
                        prefixIcon: Icon(Icons.title, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: "Markdown Content",
                        hintText: "Write your study notes, formulas, or copy AI explanations...",
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Upload File
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Upload Course Material",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Supports PDF, DOCX, TXT, and Markdown files.\nDocuments are indexed with vector embeddings for AI Q&A and active exam recall.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/scan'),
                      icon: const Icon(Icons.document_scanner_outlined, size: 18),
                      label: const Text("Or Scan Handwritten Notes via Camera"),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading 
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : Text(
                      _selectedIndex == 2 ? "Select & Upload Document" : (_selectedIndex == 0 ? "Create Folder" : "Save Note"),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int index, String label, IconData icon) {
    final isSel = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSel ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  color: isSel ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

