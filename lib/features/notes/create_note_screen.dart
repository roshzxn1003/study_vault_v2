import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/providers/database_providers.dart';
import '../../core/theme/app_colors.dart';
import '../folders/presentation/providers/folders_provider.dart';
import 'presentation/providers/notes_provider.dart';

class CreateNoteScreen extends ConsumerStatefulWidget {
  final String? initialFolderId;
  const CreateNoteScreen({super.key, this.initialFolderId});

  @override
  ConsumerState<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends ConsumerState<CreateNoteScreen> with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late TabController _tabController;
  String? _selectedFolderId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      await noteRepo.createNote(
        title: title.isEmpty ? "Untitled Note" : title,
        content: content,
        folderId: _selectedFolderId,
      );
      ref.invalidate(allNotesProvider);
      ref.invalidate(foldersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Note saved successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving note: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    final wordCount = _contentController.text.trim().isEmpty 
        ? 0 
        : _contentController.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Note"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Edit Note"),
            Tab(text: "Live Preview"),
          ],
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _saveNote,
                    child: const Text("Save"),
                  ),
                ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Edit Tab
          Column(
            children: [
              // Folder Selector & Stats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surfaceElevated,
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: foldersAsync.when(
                        data: (folders) => DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedFolderId,
                            hint: const Text("Select Subject Folder", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text("General / No Folder", style: TextStyle(fontSize: 13)),
                              ),
                              ...folders.map((f) => DropdownMenuItem<String?>(
                                    value: f['id'] as String,
                                    child: Text(f['name'] ?? 'Folder', style: const TextStyle(fontSize: 13)),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _selectedFolderId = val),
                          ),
                        ),
                        loading: () => const Text("Loading folders...", style: TextStyle(fontSize: 12)),
                        error: (e, _) => const Text("General", style: TextStyle(fontSize: 12)),
                      ),

                    ),
                    Text(
                      '$wordCount words',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Title & Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: "Note Title...",
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 20, fontWeight: FontWeight.bold),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Divider(color: AppColors.border, height: 1),
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: "Write your study notes here with markdown...\n\n# Heading 1\n## Heading 2\n* Bullet point\n1. Numbered item\n`code block`",
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                          style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textPrimary),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Formatting Toolbar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: Border(top: BorderSide(color: AppColors.cardBorder)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _toolbarItem(Icons.title, () => _insertText('# ', '')),
                      _toolbarItem(Icons.text_fields, () => _insertText('## ', '')),
                      _toolbarItem(Icons.format_bold, () => _insertText('**', '**')),
                      _toolbarItem(Icons.format_italic, () => _insertText('*', '*')),
                      _toolbarItem(Icons.format_list_bulleted, () => _insertText('\n* ', '')),
                      _toolbarItem(Icons.format_list_numbered, () => _insertText('\n1. ', '')),
                      _toolbarItem(Icons.check_box_outlined, () => _insertText('\n- [ ] ', '')),
                      _toolbarItem(Icons.code, () => _insertText('`', '`')),
                      _toolbarItem(Icons.format_quote, () => _insertText('\n> ', '')),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Preview Tab
          Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleController.text.trim().isEmpty ? "Untitled Note" : _titleController.text.trim(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  _contentController.text.trim().isEmpty
                      ? const Text("Start typing content in the Edit tab to preview formatted markdown here.", style: TextStyle(color: AppColors.textMuted))
                      : MarkdownBody(
                          data: _contentController.text,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.6),
                            h1: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                            h2: const TextStyle(color: AppColors.primaryLight, fontSize: 17, fontWeight: FontWeight.bold),
                            h3: const TextStyle(color: AppColors.cyan, fontSize: 15, fontWeight: FontWeight.bold),
                            code: const TextStyle(backgroundColor: AppColors.surfaceVariant, color: AppColors.cyan),
                            blockquote: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _insertText(String prefix, String suffix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, '$prefix${selection.textInside(text)}$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    } else {
      _contentController.text = '$text$prefix$suffix';
    }
    setState(() {});
  }

  Widget _toolbarItem(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: AppColors.textPrimary, size: 20),
      onPressed: onTap,
    );
  }
}

