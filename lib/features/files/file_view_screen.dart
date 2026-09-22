import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/database_providers.dart';
import '../../core/services/file_action_service.dart';
import '../ai/presentation/providers/chat_provider.dart';

final fileDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final repo = ref.watch(fileRepositoryProvider);
  return await repo.getFileById(id);
});

/// Production-ready document and PDF viewer supporting:
/// - Stored local PDF and signed network PDF rendering
/// - Error handling with "PDF unavailable", "Try Again", and "Go Back"
/// - Search in PDF with navigation
/// - Android system "Open with", "Share", and "Download"
/// - Page navigation, jump-to-page, fit-to-width, pinch-zoom, and dark mode reading
/// - Image and Markdown/Text viewing
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
  String? _pdfLoadError;
  int _retryKey = 0;

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

  void _zoomIn() {
    try {
      _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0);
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0);
    } catch (_) {}
  }

  void _fitToWidth() {
    try {
      _pdfViewerController.zoomLevel = 1.0;
    } catch (_) {}
  }

  void _retryLoading() {
    setState(() {
      _pdfLoadError = null;
      _retryKey++;
    });
    ref.invalidate(fileDetailsProvider(widget.id));
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(fileRepositoryProvider).deleteFile(widget.id, file['storage_path'] ?? '');
                if (context.mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                  ref.invalidate(fileRepositoryProvider);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Something went wrong: $e'),
                      action: SnackBarAction(
                        label: 'Retry',
                        onPressed: () => _confirmDelete(context, file),
                      ),
                    ),
                  );
                }
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

  void _handleOpenWith(String filePath, String title, String? mimeType) {
    FileActionService.instance.openWith(
      context: context,
      filePath: filePath,
      title: title,
      mimeType: mimeType,
    );
  }

  void _handleShare(String filePath, String title) {
    FileActionService.instance.shareSystemFile(
      context: context,
      filePath: filePath,
      title: title,
    );
  }

  void _handleDownload(String filePath, String fileName) {
    FileActionService.instance.downloadFile(
      context: context,
      sourceFilePath: filePath,
      fileName: fileName,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
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
          // Search in document
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
          // More options (Open with, Share, Download, Delete)
          fileAsync.when(
            data: (file) {
              if (file == null) return const SizedBox.shrink();
              final path = file['storage_path'] ?? '';
              final name = file['name'] ?? 'document.pdf';
              final mime = file['mime_type'] as String?;

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'More actions',
                onSelected: (val) {
                  switch (val) {
                    case 'zoom_in':
                      _zoomIn();
                      break;
                    case 'zoom_out':
                      _zoomOut();
                      break;
                    case 'fit_to_width':
                      _fitToWidth();
                      break;
                    case 'open_with':
                      _handleOpenWith(path, name, mime);
                      break;
                    case 'share':
                      _handleShare(path, name);
                      break;
                    case 'download':
                      _handleDownload(path, name);
                      break;
                    case 'delete':
                      _confirmDelete(context, file);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'zoom_in',
                    child: Row(
                      children: [
                        Icon(Icons.zoom_in_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Zoom In'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'zoom_out',
                    child: Row(
                      children: [
                        Icon(Icons.zoom_out_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Zoom Out'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fit_to_width',
                    child: Row(
                      children: [
                        Icon(Icons.fit_screen_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Fit to Width'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'open_with',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Open with...'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Share File'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Download / Export'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              );
            },
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
        error: (err, stack) => _buildFailureState(
          title: 'PDF unavailable',
          message: 'Error loading document: $err',
        ),
        data: (file) {
          if (file == null) {
            return _buildFailureState(
              title: 'PDF unavailable',
              message: 'The requested document record could not be found.',
            );
          }

          final fileName = file['name'] ?? 'Study Document.pdf';

          if (_pdfLoadError != null) {
            return _buildFailureState(
              title: 'PDF unavailable',
              message: _pdfLoadError!,
            );
          }

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

              // Document Body (PDF Viewer / Image / Text Reader)
              Expanded(
                child: _buildDocumentContent(file),
              ),

              // Bottom Reader & Navigation Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      // Page Status & Navigation Chip
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 22),
                            tooltip: 'Previous Page',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: _currentPageNumber > 1
                                ? () => _pdfViewerController.previousPage()
                                : null,
                          ),
                          InkWell(
                            onTap: _showJumpToPageDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 13, color: AppColors.primaryLight),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$_currentPageNumber/$_totalPageCount",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 22),
                            tooltip: 'Next Page',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: _currentPageNumber < _totalPageCount
                                ? () => _pdfViewerController.nextPage()
                                : null,
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: const Icon(Icons.zoom_out_rounded, size: 18),
                            tooltip: 'Zoom Out',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: _zoomOut,
                          ),
                          IconButton(
                            icon: const Icon(Icons.fit_screen_rounded, size: 18),
                            tooltip: 'Fit to Width',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: _fitToWidth,
                          ),
                          IconButton(
                            icon: const Icon(Icons.zoom_in_rounded, size: 18),
                            tooltip: 'Zoom In',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: _zoomIn,
                          ),
                        ],
                      ),

                      // AI Study Action Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showAiStudyDrawer(context, fileName),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text(
                          "AI Tools",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

  Widget _buildDocumentContent(Map<String, dynamic> file) {
    final fileName = file['name'] ?? 'Study Document.pdf';
    final storagePath = (file['storage_path'] ?? '') as String;
    final remoteUrl = (file['remote_url'] ?? '') as String;
    final fileType = (file['file_type'] ?? 'PDF').toString().toUpperCase();

    // 0. Link Material Viewer
    if (fileType == 'LINK' || (remoteUrl.isNotEmpty && (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://')) && !storagePath.endsWith('.pdf'))) {
      final targetUrl = remoteUrl.isNotEmpty ? remoteUrl : storagePath;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.link_rounded, size: 40, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fileName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      targetUrl,
                      style: const TextStyle(fontSize: 13, color: AppColors.primaryLight),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            FileActionService.instance.openWith(
                              context: context,
                              filePath: targetUrl,
                              title: fileName,
                            );
                          },
                          icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                          label: const Text('Open Link'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            FileActionService.instance.shareSystemFile(
                              context: context,
                              filePath: targetUrl,
                              title: fileName,
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 1. Image Viewer (JPG, PNG, WEBP, etc.)
    if (['JPG', 'JPEG', 'PNG', 'WEBP', 'IMAGE'].contains(fileType)) {
      if (storagePath.isNotEmpty && File(storagePath).existsSync()) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              File(storagePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildFailureState(
                title: 'Image unavailable',
                message: 'Could not render image file.',
              ),
            ),
          ),
        );
      } else if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              storagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _buildFailureState(
                title: 'Image unavailable',
                message: 'Could not load network image.',
              ),
            ),
          ),
        );
      }
    }

    // 2. Text/Markdown reader
    if (fileType == 'TXT' || fileType == 'MD') {
      if (_textContent == null && storagePath.isNotEmpty && File(storagePath).existsSync()) {
        try {
          _textContent = File(storagePath).readAsStringSync();
        } catch (e) {
          debugPrint('FileViewScreen: Failed to read text file at $storagePath: $e');
        }
      }

      final textToDisplay = _textContent ?? (file['content'] as String?) ?? "# $fileName\n\nStudy Vault indexed document content.";

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

    // 3. Real PDF from local file system
    if (storagePath.isNotEmpty && File(storagePath).existsSync()) {
      return _buildPdfViewerWidget(isNetwork: false, source: storagePath);
    }

    // 4. Real PDF from direct Network URL
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      return _buildPdfViewerWidget(isNetwork: true, source: storagePath);
    }

    if (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://')) {
      return _buildPdfViewerWidget(isNetwork: true, source: remoteUrl);
    }

    // 5. PDF in Supabase remote storage
    if (storagePath.isNotEmpty && !storagePath.startsWith('/')) {
      return FutureBuilder<String>(
        future: ref.read(fileRepositoryProvider).getAuthenticatedUrl(storagePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Retrieving secure document...", style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          final signedUrl = snapshot.data;
          if (signedUrl != null && (signedUrl.startsWith('http://') || signedUrl.startsWith('https://'))) {
            return _buildPdfViewerWidget(isNetwork: true, source: signedUrl);
          }
          return _buildFailureState(
            title: 'PDF unavailable',
            message: 'Could not retrieve document from cloud storage.',
          );
        },
      );
    }

    // 6. File not found or inaccessible state
    return _buildFailureState(
      title: 'PDF unavailable',
      message: 'The material file is missing or inaccessible on your device storage.',
    );
  }

  Widget _buildPdfViewerWidget({required bool isNetwork, required String source}) {
    if (isNetwork) {
      return SfPdfViewer.network(
        source,
        key: ValueKey('net_pdf_${source}_$_retryKey'),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (details) {
          if (mounted) {
            setState(() {
              _totalPageCount = details.document.pages.count;
              _pdfLoadError = null;
            });
          }
        },
        onDocumentLoadFailed: (details) {
          if (mounted) {
            setState(() {
              _pdfLoadError = 'Network error downloading PDF. Please check your internet connection.';
            });
          }
        },
        onPageChanged: (details) {
          if (mounted) {
            setState(() {
              _currentPageNumber = details.newPageNumber;
            });
          }
        },
      );
    } else {
      return SfPdfViewer.file(
        File(source),
        key: ValueKey('local_pdf_${source}_$_retryKey'),
        controller: _pdfViewerController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        onDocumentLoaded: (details) {
          if (mounted) {
            setState(() {
              _totalPageCount = details.document.pages.count;
              _pdfLoadError = null;
            });
          }
        },
        onDocumentLoadFailed: (details) {
          if (mounted) {
            setState(() {
              _pdfLoadError = details.description.isNotEmpty
                  ? details.description
                  : 'Failed to load PDF file. The file may be corrupt or encrypted.';
            });
          }
        },
        onPageChanged: (details) {
          if (mounted) {
            setState(() {
              _currentPageNumber = details.newPageNumber;
            });
          }
        },
      );
    }
  }

  Widget _buildFailureState({
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_outlined, size: 54, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Go Back'),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _retryLoading,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
