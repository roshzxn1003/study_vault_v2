import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import '../../domain/models/import_item.dart';
import 'import_storage_service.dart';

/// Service interfacing with native Android share targets and platform intent channels.
class IncomingShareService {
  static const MethodChannel _channel = MethodChannel('com.example.study_vault/share_receiver');
  final ImportStorageService _storageService;
  final Uuid _uuid = const Uuid();

  final _shareStreamController = StreamController<List<ImportItem>>.broadcast();
  Stream<List<ImportItem>> get incomingShareStream => _shareStreamController.stream;

  IncomingShareService({ImportStorageService? storageService})
      : _storageService = storageService ?? ImportStorageService();

  /// Initializes listening for runtime intents (e.g. app already in memory / onNewIntent).
  void initIntentListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewSharedData') {
        try {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          final items = await parseSharedData(data);
          if (items.isNotEmpty) {
            _shareStreamController.add(items);
          }
        } catch (e) {
          debugPrint('Error handling onNewSharedData: $e');
        }
      }
    });
  }

  /// Checks for shared content when the app was launched cold from the Android share sheet.
  Future<List<ImportItem>?> getInitialSharedItems() async {
    try {
      final result = await _channel.invokeMethod('getInitialSharedData');
      if (result != null && result is Map) {
        final data = Map<String, dynamic>.from(result);
        final items = await parseSharedData(data);
        if (items.isNotEmpty) {
          return items;
        }
      }
    } catch (e) {
      debugPrint('IncomingShareService: No initial intent or error: $e');
    }
    return null;
  }

  /// Converts a native payload map into typed ImportItems.
  Future<List<ImportItem>> parseSharedData(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    final subject = data['subject'] as String?;

    if (type == 'files') {
      final rawFiles = data['files'] as List<dynamic>? ?? [];
      final items = <ImportItem>[];

      for (final f in rawFiles) {
        if (f is Map) {
          final map = Map<String, dynamic>.from(f);
          final fileName = map['fileName'] as String? ?? 'Shared Document';
          final filePath = map['filePath'] as String?;
          final fileSize = (map['fileSize'] as num?)?.toInt() ?? 0;
          final mimeType = map['mimeType'] as String?;

          final materialType = _storageService.detectMaterialType(
            fileName: fileName,
            mimeType: mimeType,
          );

          // Use title without extension for clean display
          final cleanTitle = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');

          items.add(ImportItem(
            id: _uuid.v4(),
            title: cleanTitle.isEmpty ? fileName : cleanTitle,
            originalFileName: fileName,
            filePath: filePath,
            fileSize: fileSize,
            mimeType: mimeType,
            type: materialType,
            source: 'Shared File',
          ));
        }
      }
      return items;
    }

    if (type == 'url') {
      final url = data['url'] as String? ?? data['text'] as String? ?? '';
      if (url.trim().isNotEmpty) {
        var displayTitle = subject?.trim();
        if (displayTitle == null || displayTitle.isEmpty) {
          try {
            final uri = Uri.parse(url.trim());
            displayTitle = uri.host.isNotEmpty ? 'Resource from ${uri.host}' : 'Web Resource';
          } catch (_) {
            displayTitle = 'Web Resource';
          }
        }

        return [
          ImportItem(
            id: _uuid.v4(),
            title: displayTitle,
            type: VaultMaterialType.link,
            content: url.trim(),
            source: 'Chrome',
          ),
        ];
      }
    }

    if (type == 'text') {
      final text = data['text'] as String? ?? '';
      if (text.trim().isNotEmpty) {
        var displayTitle = subject?.trim();
        if (displayTitle == null || displayTitle.isEmpty) {
          final firstLine = text.trim().split('\n').first.trim();
          displayTitle = firstLine.length > 40 ? '${firstLine.substring(0, 40)}...' : firstLine;
          if (displayTitle.isEmpty) displayTitle = 'Shared Note';
        }

        return [
          ImportItem(
            id: _uuid.v4(),
            title: displayTitle,
            type: VaultMaterialType.note,
            content: text.trim(),
            source: 'Shared Text',
          ),
        ];
      }
    }

    return [];
  }

  /// Converts locally selected files (file picker, gallery, camera) into staged ImportItems.
  Future<List<ImportItem>> createItemsFromFiles(
    List<File> files, {
    String source = 'Files',
  }) async {
    final items = <ImportItem>[];

    for (final file in files) {
      if (!await file.exists()) continue;

      final fileName = p.basename(file.path);
      final size = await file.length();
      final materialType = _storageService.detectMaterialType(fileName: fileName);
      final cleanTitle = p.basenameWithoutExtension(fileName).replaceAll('_', ' ');

      items.add(ImportItem(
        id: _uuid.v4(),
        title: cleanTitle.isEmpty ? fileName : cleanTitle,
        originalFileName: fileName,
        filePath: file.path,
        fileSize: size,
        type: materialType,
        source: source,
      ));
    }

    return items;
  }

  void dispose() {
    _shareStreamController.close();
  }
}
