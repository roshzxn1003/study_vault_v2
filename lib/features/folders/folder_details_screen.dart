import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:study_vault/core/services/document_import_service.dart';
import '../../core/providers/database_providers.dart';
import '../../core/theme/app_colors.dart';

final folderDetailsNameProvider = FutureProvider.family<String, String>((ref, folderId) async {
  final db = await ref.read(folderRepositoryProvider).getFolders();
  final folder = db.firstWhere((f) => f['id'] == folderId, orElse: () => {'name': 'Folder'});
  return folder['name'] ?? 'Folder';
});

final folderContentProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, folderId) async {
  final fileRepo = ref.read(fileRepositoryProvider);
  final noteRepo = ref.read(noteRepositoryProvider);
  
  return {
    'files': await fileRepo.getFiles(folderId: folderId),
    'notes': await noteRepo.getNotes(folderId: folderId),
  };
});

class FolderDetailsScreen extends ConsumerStatefulWidget {
  final String id;
  const FolderDetailsScreen({super.key, required this.id});

  @override
  ConsumerState<FolderDetailsScreen> createState() => _FolderDetailsScreenState();
}

class _FolderDetailsScreenState extends ConsumerState<FolderDetailsScreen> {
  int _selectedFilter = 0; // 0 = All, 1 = Notes, 2 = Files

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A6366F1),
                  child: Icon(Icons.edit_note, color: AppColors.primary),
                ),
                title: const Text('Write New Note', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Create formatted markdown note in this folder'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/notes/create?folderId=${widget.id}');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A10B981),
                  child: Icon(Icons.document_scanner, color: AppColors.emerald),
                ),
                title: const Text('Scan Study Material', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('OCR text extraction from photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/scan');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A06B6D4),
                  child: Icon(Icons.upload_file, color: AppColors.cyan),
                ),
                title: const Text('Upload PDF / Document', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Index slides, textbooks, or syllabus files'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final importService = ref.read(documentImportServiceProvider);
                  final fileData = await importService.pickAndImportDocument(
                    folderId: widget.id,
                    context: context,
                  );
                  if (fileData != null) {
                    ref.invalidate(folderContentProvider(widget.id));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Imported '${fileData['name']}' to this folder!"),
                          backgroundColor: AppColors.emerald,
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'View PDF',
                            textColor: Colors.white,
                            onPressed: () => context.push('/files/${fileData['id']}'),
                          ),
                        ),
                      );
                      context.push('/files/${fileData['id']}');
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folderNameAsync = ref.watch(folderDetailsNameProvider(widget.id));
    final contentAsync = ref.watch(folderContentProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: folderNameAsync.when(
          data: (name) => Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          loading: () => const Text("Folder Contents"),
          error: (e, _) => const Text("Folder Contents"),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Material',
            onPressed: () => _showAddOptions(context),
          ),
        ],
      ),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (data) {
          final files = data['files'] as List<Map<String, dynamic>>;
          final notes = data['notes'] as List<Map<String, dynamic>>;

          if (files.isEmpty && notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.folder_open, size: 54, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text("Folder is empty", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text("Add your study notes, PDF slides, and syllabus to organize this subject.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddOptions(context),
                      icon: const Icon(Icons.add),
                      label: const Text("Add Study Material"),
                    ),
                  ],
                ),
              ),
            );
          }

          final showNotes = _selectedFilter == 0 || _selectedFilter == 1;
          final showFiles = _selectedFilter == 0 || _selectedFilter == 2;

          return Column(
            children: [
              // Segmented Filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    _filterChip(0, 'All (${notes.length + files.length})'),
                    const SizedBox(width: 8),
                    _filterChip(1, 'Notes (${notes.length})'),
                    const SizedBox(width: 8),
                    _filterChip(2, 'Documents (${files.length})'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Items List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (showNotes && notes.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text("Study Notes", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ),
                      ...notes.map((note) => _buildNoteTile(note)),
                      const SizedBox(height: 16),
                    ],
                    if (showFiles && files.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text("Files & Documents", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ),
                      ...files.map((file) => _buildFileTile(file)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Material'),
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.cardBorder),
      onSelected: (_) => setState(() => _selectedFilter = index),
    );
  }

  Widget _buildNoteTile(Map<String, dynamic> note) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A6366F1),
          child: Icon(Icons.note_alt_rounded, color: AppColors.primary, size: 22),
        ),
        title: Text(note['title'] ?? 'Untitled Note', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          (note['content'] ?? '').replaceAll('#', '').replaceAll('*', '').trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        onTap: () => context.push('/notes/${note['id']}'),
      ),
    );
  }

  Widget _buildFileTile(Map<String, dynamic> file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A3B82F6),
          child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF3B82F6), size: 22),
        ),
        title: Text(file['name'] ?? 'Document.pdf', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${file['file_type'] ?? 'PDF'} • Indexed for AI', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        onTap: () => context.push('/files/${file['id']}'),
      ),
    );
  }
}

