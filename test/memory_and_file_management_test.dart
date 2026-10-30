import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/services/memory_manager_service.dart';
import 'package:study_vault/core/services/storage_manager_service.dart';
import 'package:study_vault/features/profile/storage_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('study_vault_mem_file_test_');
    StorageManagerService.instance.setCustomBaseDirForTesting(tempDir);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('MemoryManagerService Unit Tests', () {
    test('enforces 40MB image cache ceiling and 100 image limit for low-RAM mobile', () {
      MemoryManagerService.instance.init();

      expect(
        PaintingBinding.instance.imageCache.maximumSizeBytes,
        equals(40 * 1024 * 1024),
      );
      expect(
        PaintingBinding.instance.imageCache.maximumSize,
        equals(100),
      );
    });

    test('trimMemory flushes image cache without throwing', () {
      expect(() => MemoryManagerService.instance.trimMemory(), returnsNormally);
      expect(() => MemoryManagerService.instance.didHaveMemoryPressure(), returnsNormally);
    });
  });

  group('StorageManagerService Sandboxing & Safe Cache Clearing Tests', () {
    test('directories are isolated between documents, cache, and scans', () async {
      final docsDir = await StorageManagerService.instance.getDocumentsDirectory();
      final cacheDir = await StorageManagerService.instance.getCacheDirectory();
      final scansDir = await StorageManagerService.instance.getTempScansDirectory();

      expect(docsDir.path, contains('vault_documents'));
      expect(cacheDir.path, contains('vault_cache'));
      expect(scansDir.path, contains('vault_scans'));
      expect(docsDir.path != cacheDir.path, isTrue);
    });

    test('savePermanentMaterialFile copies into permanent documents sandbox', () async {
      final sampleSource = File('${tempDir.path}/sample_note.txt');
      await sampleSource.writeAsString('Study notes on Operating Systems');

      final savedFile = await StorageManagerService.instance.savePermanentMaterialFile(
        sourceFile: sampleSource,
        fileName: 'OS_Notes.txt',
      );

      expect(await savedFile.exists(), isTrue);
      expect(savedFile.path, contains('vault_documents'));
      expect(await savedFile.readAsString(), equals('Study notes on Operating Systems'));
    });

    test('clearSafeCache deletes cache and scans while 100% preserving permanent vault documents', () async {
      // 1. Create a permanent document
      final docsDir = await StorageManagerService.instance.getDocumentsDirectory();
      final permanentDoc = File('${docsDir.path}/permanent_syllabus.pdf');
      await permanentDoc.writeAsString('Critical Course Syllabus - Do Not Delete');

      // 2. Create transient cache files
      final cacheDir = await StorageManagerService.instance.getCacheDirectory();
      final cachedPreview = File('${cacheDir.path}/preview_temp.jpg');
      await cachedPreview.writeAsString('Temporary image preview bytes');

      // 3. Create temp scan
      final scansDir = await StorageManagerService.instance.getTempScansDirectory();
      final tempScan = File('${scansDir.path}/ocr_capture.jpg');
      await tempScan.writeAsString('Temporary camera scan bytes');

      // 4. Verify all exist before clear
      expect(await permanentDoc.exists(), isTrue);
      expect(await cachedPreview.exists(), isTrue);
      expect(await tempScan.exists(), isTrue);

      // 5. Run safe cache clear
      final bytesFreed = await StorageManagerService.instance.clearSafeCache();
      expect(bytesFreed, greaterThan(0));

      // 6. Verify cache and scans are wiped, but permanent document is 100% INTACT
      expect(await cachedPreview.exists(), isFalse);
      expect(await tempScan.exists(), isFalse);
      expect(await permanentDoc.exists(), isTrue);
      expect(await permanentDoc.readAsString(), equals('Critical Course Syllabus - Do Not Delete'));
    });

    test('calculateStorageBreakdown accurately measures category sizes', () async {
      final docsDir = await StorageManagerService.instance.getDocumentsDirectory();
      final docFile = File('${docsDir.path}/doc_1.txt');
      await docFile.writeAsString('A' * 1024); // 1 KB

      final cacheDir = await StorageManagerService.instance.getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/cache_1.txt');
      await cacheFile.writeAsString('B' * 2048); // 2 KB

      final breakdown = await StorageManagerService.instance.calculateStorageBreakdown();

      expect(breakdown.documentsBytes, greaterThanOrEqualTo(1024));
      expect(breakdown.cacheBytes, greaterThanOrEqualTo(2048));
      expect(breakdown.formattedDocuments, contains('KB'));
      expect(breakdown.formattedCache, contains('KB'));
    });
  });

  group('StorageManagementScreen Widget Tests', () {
    testWidgets('StorageManagementScreen renders header, actions, and storage breakdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StorageManagementScreen(
            initialLoading: false,
            initialBreakdown: StorageBreakdown(
              documentsBytes: 1024 * 1024 * 10,
              cacheBytes: 1024 * 1024 * 4,
              scansBytes: 1024 * 512,
              databaseBytes: 1024 * 256,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Storage & File Manager'), findsOneWidget);
      expect(find.text('App Storage Usage'), findsOneWidget);
      expect(find.text('Clear Cache (Safe)'), findsOneWidget);
      expect(find.text('Flush RAM'), findsOneWidget);
      expect(find.text('Vault Files'), findsOneWidget);
      expect(find.text('Temp Cache'), findsOneWidget);
    });
  });
}
