import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:study_vault/core/design/tokens/tokens.dart';
import '../../domain/models/models.dart';

/// Universal High-Fidelity Material Preview Widget.
/// Renders an appropriate, rich visual preview for every material type:
/// PDF, Image, Markdown Note, Web Link, and Document.
class MaterialPreviewWidget extends StatelessWidget {
  final MaterialItem material;
  final double? height;
  final double? width;
  final bool isCompact;
  final bool showInteractiveOverlay;
  final VoidCallback? onTap;

  const MaterialPreviewWidget({
    super.key,
    required this.material,
    this.height,
    this.width,
    this.isCompact = false,
    this.showInteractiveOverlay = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filePath = material.filePath ?? material.storagePath ?? '';
    final hasLocalFile = filePath.isNotEmpty && File(filePath).existsSync();
    final remoteUrl = material.remoteUrl ?? '';
    final hasRemoteUrl = remoteUrl.isNotEmpty;

    Widget previewContent;

    switch (material.type) {
      case VaultMaterialType.image:
        previewContent = _buildImagePreview(hasLocalFile, filePath, hasRemoteUrl, remoteUrl);
        break;
      case VaultMaterialType.pdf:
        previewContent = isCompact
            ? _buildCompactPdfPreview()
            : _buildFullPdfPreview(hasLocalFile, filePath, hasRemoteUrl, remoteUrl);
        break;
      case VaultMaterialType.note:
        previewContent = isCompact ? _buildCompactNotePreview() : _buildFullNotePreview();
        break;
      case VaultMaterialType.link:
        previewContent = isCompact ? _buildCompactLinkPreview() : _buildFullLinkPreview();
        break;
      case VaultMaterialType.document:
        previewContent = isCompact
            ? _buildCompactDocumentPreview()
            : _buildFullDocumentPreview(hasLocalFile, filePath);
        break;
    }

    return Container(
      height: height,
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              previewContent,

              // Top Type Badge (non-compact)
              if (!isCompact)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: material.type.color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(material.type.icon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          material.type.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Interactive Fullscreen/Reader Overlay
              if (showInteractiveOverlay && !isCompact)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Open Viewer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // IMAGE PREVIEWS
  // ===========================================================================
  Widget _buildImagePreview(bool hasLocal, String localPath, bool hasRemote, String remoteUrl) {
    if (hasLocal) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackCard(Icons.broken_image_outlined, 'Image missing'),
      );
    } else if (hasRemote) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackCard(Icons.broken_image_outlined, 'Image unavailable'),
      );
    }
    return _buildFallbackCard(Icons.image_outlined, 'Image');
  }

  // ===========================================================================
  // PDF PREVIEWS
  // ===========================================================================
  Widget _buildCompactPdfPreview() {
    return Container(
      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(height: 2),
            Text(
              'PDF',
              style: TextStyle(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPdfPreview(bool hasLocal, String localPath, bool hasRemote, String remoteUrl) {
    if (hasLocal || hasRemote) {
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: hasLocal
                ? SfPdfViewer.file(
                    File(localPath),
                    canShowScrollHead: false,
                    canShowScrollStatus: false,
                    enableDoubleTapZooming: false,
                  )
                : SfPdfViewer.network(
                    remoteUrl,
                    canShowScrollHead: false,
                    canShowScrollStatus: false,
                    enableDoubleTapZooming: false,
                  ),
          ),
          // Subtle bottom shading
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _buildFallbackCard(Icons.picture_as_pdf_rounded, 'PDF Document');
  }

  // ===========================================================================
  // NOTE PREVIEWS
  // ===========================================================================
  Widget _buildCompactNotePreview() {
    return Container(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(height: 2),
            Text(
              'NOTE',
              style: TextStyle(
                color: const Color(0xFFF59E0B),
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullNotePreview() {
    final text = material.content?.trim() ?? '';
    final hasContent = text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: const Color(0xFF1F1E29),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24), // Clearance for badge
          Expanded(
            child: Text(
              hasContent ? text : 'Empty note. Tap to write academic summary...',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
                color: hasContent ? AppColors.textPrimary : AppColors.textMuted,
              ),
              maxLines: 7,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.text_snippet_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LINK PREVIEWS
  // ===========================================================================
  Widget _buildCompactLinkPreview() {
    return Container(
      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF8B5CF6), size: 24),
            const SizedBox(height: 2),
            Text(
              'LINK',
              style: TextStyle(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullLinkPreview() {
    final url = material.remoteUrl ?? material.filePath ?? 'https://...';
    String domain = url;
    try {
      final uri = Uri.parse(url);
      if (uri.host.isNotEmpty) domain = uri.host;
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: const Color(0xFF1E1B2E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.language_rounded, color: Color(0xFFA78BFA), size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            domain,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            url,
            style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DOCUMENT PREVIEWS (Office, TXT, etc.)
  // ===========================================================================
  Widget _buildCompactDocumentPreview() {
    return Container(
      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_rounded, color: Color(0xFF3B82F6), size: 24),
            const SizedBox(height: 2),
            Text(
              'DOC',
              style: TextStyle(
                color: const Color(0xFF3B82F6),
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullDocumentPreview(bool hasLocal, String localPath) {
    final fileName = material.originalFileName ?? material.title;
    final ext = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'DOC';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: const Color(0xFF182234),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.article_rounded, color: Color(0xFF60A5FA), size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              '.$ext Document',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            if (material.formattedFileSize.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                material.formattedFileSize,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackCard(IconData icon, String label) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: material.type.color.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
