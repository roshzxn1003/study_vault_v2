import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

enum AppFileType { pdf, note, document, image, audio, folder, generic }

/// Clean academic file type badge component with restrained color indicators.
class AppFileTypeIcon extends StatelessWidget {
  final AppFileType type;
  final double size;

  const AppFileTypeIcon({
    super.key,
    required this.type,
    this.size = 38.0,
  });

  factory AppFileTypeIcon.fromExtension(String extension, {double size = 38.0}) {
    final ext = extension.toLowerCase().replaceAll('.', '').trim();
    switch (ext) {
      case 'pdf':
        return AppFileTypeIcon(type: AppFileType.pdf, size: size);
      case 'md':
      case 'note':
      case 'txt':
        return AppFileTypeIcon(type: AppFileType.note, size: size);
      case 'doc':
      case 'docx':
        return AppFileTypeIcon(type: AppFileType.document, size: size);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return AppFileTypeIcon(type: AppFileType.image, size: size);
      case 'mp3':
      case 'm4a':
      case 'wav':
        return AppFileTypeIcon(type: AppFileType.audio, size: size);
      case 'folder':
        return AppFileTypeIcon(type: AppFileType.folder, size: size);
      default:
        return AppFileTypeIcon(type: AppFileType.generic, size: size);
    }
  }

  Color get _color {
    switch (type) {
      case AppFileType.pdf:
        return AppColors.filePdf;
      case AppFileType.note:
        return AppColors.fileNote;
      case AppFileType.document:
        return AppColors.primaryLight;
      case AppFileType.image:
        return AppColors.fileImage;
      case AppFileType.audio:
        return AppColors.fileAudio;
      case AppFileType.folder:
        return AppColors.fileFolder;
      case AppFileType.generic:
        return AppColors.fileGeneric;
    }
  }

  IconData get _icon {
    switch (type) {
      case AppFileType.pdf:
        return AppIcons.pdf;
      case AppFileType.note:
        return AppIcons.note;
      case AppFileType.document:
        return AppIcons.document;
      case AppFileType.image:
        return AppIcons.image;
      case AppFileType.audio:
        return AppIcons.audio;
      case AppFileType.folder:
        return AppIcons.folder;
      case AppFileType.generic:
        return AppIcons.document;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: _color.withValues(alpha: 0.28),
          width: AppBorders.subtleWidth,
        ),
      ),
      child: Center(
        child: Icon(
          _icon,
          size: size * 0.52,
          color: _color,
        ),
      ),
    );
  }
}
