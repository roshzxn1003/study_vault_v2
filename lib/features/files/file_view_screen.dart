import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/database_providers.dart';
import '../ai/presentation/providers/chat_provider.dart';

final fileDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final repo = ref.watch(fileRepositoryProvider);
  return await repo.getFileById(id);
});

class FileViewScreen extends ConsumerStatefulWidget {
  final String id;
  const FileViewScreen({super.key, required this.id});

  @override
  ConsumerState<FileViewScreen> createState() => _FileViewScreenState();
}

class _FileViewScreenState extends ConsumerState<FileViewScreen> {
  late PdfViewerController _pdfViewerController;
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchOpen = false;
  int _currentPageNumber = 1;
  int _totalPageCount = 1;
  bool _isDarkModeInvert = false;
  String? _textContent;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _searchResult = PdfTextSearchResult();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${file['name']}" from your vault?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ref.read(fileRepositoryProvider).deleteFile(widget.id, file['storage_path'] ?? '');
              ref.invalidate(fileRepositoryProvider);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.pop();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJumpToPageDialog() {
    final pageCtrl = TextEditingController(text: _currentPageNumber.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Jump to Page', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pageCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - $_totalPageCount)',
            hintText: 'e.g., 2',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(pageCtrl.text.trim());
              if (page != null && page >= 1 && page <= _totalPageCount) {
                _pdfViewerController.jumpToPage(page);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showAiStudyDrawer(BuildContext context, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "AI Study Assistant",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Active Document: $fileName (Page $_currentPageNumber of $_totalPageCount)",
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A6366F1),
                  child: Icon(Icons.school_outlined, color: AppColors.primary, size: 22),
                ),
                title: const Text('Socratic AI Tutor Lesson', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Step-by-step interactive lesson based on this document'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/study/learn/$fileName');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A10B981),
                  child: Icon(Icons.quiz_outlined, color: AppColors.emerald, size: 22),
                ),
                title: const Text('Generate 5-Minute Practice Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Instant MCQ testing with explanations and grading'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/study/quiz/$fileName');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1AF59E0B),
                  child: Icon(Icons.style_outlined, color: AppColors.amber, size: 22),
                ),
                title: const Text('Active Recall Flashcards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Test memory with key terms and definitions'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/study/flashcards/$fileName');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A06B6D4),
                  child: Icon(Icons.summarize_outlined, color: AppColors.cyan, size: 22),
                ),
                title: const Text('Executive Document Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('High-yield exam review notes & invariant rules'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(chatProvider.notifier).setMode('summarize');
                  ref.read(chatProvider.notifier).sendMessage('Provide a structured summary of $fileName for exam preparation.');
                  context.push('/ai');
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
    final fileAsync = ref.watch(fileDetailsProvider(widget.id));

    return Scaffold(
      backgroundColor: _isDarkModeInvert ? const Color(0xFF0F172A) : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: fileAsync.when(
          data: (file) => Text(
            file?['name'] ?? 'Document Viewer',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          loading: () => const Text("Loading Document..."),
          error: (e, _) => const Text("Document Viewer"),
        ),
        actions: [
          // Find in document
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.search_off : Icons.search),
            tooltip: 'Search Document',
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchResult.clear();
                  _searchController.clear();
                }
              });
            },
          ),
          // Jump to page
          IconButton(
            icon: const Icon(Icons.my_location_outlined),
            tooltip: 'Jump to Page',
            onPressed: _showJumpToPageDialog,
          ),
          // Dark Mode / Contrast Toggle
          IconButton(
            icon: Icon(_isDarkModeInvert ? Icons.light_mode : Icons.dark_mode_outlined),
            tooltip: 'Invert Reading Contrast',
            onPressed: () => setState(() => _isDarkModeInvert = !_isDarkModeInvert),
          ),
          // Delete
          fileAsync.when(
            data: (file) => file != null
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete File',
                    onPressed: () => _confirmDelete(context, file),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: fileAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Opening Document...", style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text("Error: $err")),
        data: (file) {
          final fileName = file?['name'] ?? 'Study Document.pdf';
          final storagePath = file?['storage_path'] ?? '';
          final fileType = file?['file_type'] ?? 'PDF';

          return Column(
            children: [
              // Search Toolbar (if active)
              if (_isSearchOpen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.surfaceElevated,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search text in PDF...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            isDense: true,
                          ),
                          onSubmitted: (text) {
                            if (text.isNotEmpty) {
                              _searchResult = _pdfViewerController.searchText(text);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _searchResult.totalInstanceCount > 0
                            ? '${_searchResult.currentInstanceIndex}/${_searchResult.totalInstanceCount}'
                            : '',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                      ),
                      IconButton(
                        icon: const Icon(Icons.navigate_before, size: 20),
                        onPressed: () {
                          _searchResult.previousInstance();
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.navigate_next, size: 20),
                        onPressed: () {
                          _searchResult.nextInstance();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),

              // Document Body (PDF Viewer / Text Reader)
              Expanded(
                child: _buildDocumentContent(fileName, storagePath, fileType),
              ),

              // Bottom Reader & AI Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  border: const Border(top: BorderSide(color: AppColors.cardBorder)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              "Page $_currentPageNumber of $_totalPageCount",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),

                      // AI Study Action Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _showAiStudyDrawer(context, fileName),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text(
                          "AI Study Tools",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocumentContent(String fileName, String storagePath, String fileType) {
    // 1. Text/Markdown reader
    if (fileType == 'TXT' || fileType == 'MD') {
      if (_textContent == null && storagePath.isNotEmpty && File(storagePath).existsSync()) {
        try {
          _textContent = File(storagePath).readAsStringSync();
        } catch (_) {}
      }

      final textToDisplay = _textContent ?? "# $fileName\n\nStudy Vault indexed document content.";

      return SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: MarkdownBody(
          data: textToDisplay,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textPrimary),
            h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
            code: const TextStyle(backgroundColor: AppColors.surfaceVariant, color: AppColors.cyan),
          ),
        ),
      );
    }

    // 2. Real PDF from local file system
    if (storagePath.isNotEmpty && File(storagePath).existsSync()) {
      return SfPdfViewer.file(
        File(storagePath),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPageCount = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() {
            _currentPageNumber = details.newPageNumber;
          });
        },
      );
    }

    // 3. Real PDF from Network URL
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      return SfPdfViewer.network(
        storagePath,
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (details) {
          setState(() {
            _totalPageCount = details.document.pages.count;
          });
        },
        onPageChanged: (details) {
          setState(() {
            _currentPageNumber = details.newPageNumber;
          });
        },
      );
    }

    // 4. File not found or inaccessible state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.file_present_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Material file not found or inaccessible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The underlying document could not be located locally or remotely.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
