import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/providers/database_providers.dart';
import 'package:study_vault/features/home/presentation/providers/home_provider.dart';
import 'package:study_vault/features/folders/presentation/providers/folders_provider.dart';

final documentImportServiceProvider = Provider<DocumentImportService>((ref) {
  return DocumentImportService(ref);
});

class DocumentImportService {
  final Ref _ref;
  DocumentImportService(this._ref);

  /// Launches the system file picker to import any document (PDF, Markdown, TXT, DOCX)
  /// into the local Study Vault database and indexes it for AI Q&A and active exam recall.
  Future<Map<String, dynamic>?> pickAndImportDocument({
    String? folderId,
    BuildContext? context,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.path == null) return null;

      final fileId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      final ext = file.extension?.toUpperCase() ?? 'PDF';
      final fileName = file.name;
      final targetFolder = folderId ?? 'folder_dbms';

      // 1. Save metadata in Local DB
      final db = await LocalDbService.instance.database;
      final fileData = {
        'id': fileId,
        'user_id': 'guest',
        'folder_id': targetFolder,
        'name': fileName,
        'storage_path': file.path!,
        'mime_type': file.extension == 'pdf' ? 'application/pdf' : 'text/plain',
        'file_size': file.size,
        'file_type': ext,
        'created_at': now,
        'updated_at': now,
        'sync_status': 'synced',
      };

      await db.insert('files', fileData);

      // 2. Extract text if PDF or Text for local AI search
      try {
        String extractedText = "";
        if (ext == 'PDF') {
          final bytes = await File(file.path!).readAsBytes();
          final PdfDocument pdfDoc = PdfDocument(inputBytes: bytes);
          final buffer = StringBuffer();
          for (int i = 0; i < pdfDoc.pages.count; i++) {
            final pageText = PdfTextExtractor(pdfDoc).extractText(startPageIndex: i, endPageIndex: i);
            if (pageText.trim().isNotEmpty) {
              buffer.writeln("--- Page ${i + 1} ---");
              buffer.writeln(pageText);
            }
          }
          pdfDoc.dispose();
          extractedText = buffer.toString();
        } else if (ext == 'TXT' || ext == 'MD') {
          extractedText = await File(file.path!).readAsString();
        }

        if (extractedText.isNotEmpty) {
          // Store an associated search index note
          await db.insert('notes', {
            'id': 'note_doc_$fileId',
            'user_id': 'guest',
            'folder_id': targetFolder,
            'title': fileName,
            'content': extractedText.length > 5000 ? extractedText.substring(0, 5000) : extractedText,
            'created_at': now,
            'updated_at': now,
            'sync_status': 'synced',
          });
        }
      } catch (e) {
        debugPrint('Text extraction for $fileName skipped/failed: $e');
      }

      // Invalidate providers
      _ref.invalidate(homeDataProvider);
      _ref.invalidate(fileRepositoryProvider);
      _ref.invalidate(foldersProvider);

      return fileData;
    } catch (e) {
      debugPrint('Error picking and importing document: $e');
      rethrow;
    }
  }
}
