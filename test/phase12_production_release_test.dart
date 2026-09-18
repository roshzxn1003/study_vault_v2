import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/config/environment_config.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/core/services/monitoring_service.dart';
import 'package:study_vault/features/profile/data/services/account_management_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 12: Production Release & Launch Preparation', () {
    test('1. Official Logo Asset & Launcher Icons Verification', () {
      // 1.1 Verify root source logo
      final rootLogo = File('sv-logo.png');
      expect(rootLogo.existsSync(), isTrue, reason: 'Root sv-logo.png must exist');
      final rootBytes = rootLogo.readAsBytesSync();
      expect(rootBytes.length, greaterThan(1000));
      // PNG header magic numbers: 0x89, 0x50, 0x4E, 0x47 (‰PNG)
      expect(rootBytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));

      // 1.2 Verify asset catalog images
      final assetLogo = File('assets/images/logo.png');
      expect(assetLogo.existsSync(), isTrue, reason: 'assets/images/logo.png must exist');
      final assetBytes = assetLogo.readAsBytesSync();
      expect(assetBytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));

      final assetSvLogo = File('assets/images/sv-logo.png');
      expect(assetSvLogo.existsSync(), isTrue, reason: 'assets/images/sv-logo.png must exist');

      // 1.3 Verify Android mipmap launcher densities
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final iconFile = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(iconFile.existsSync(), isTrue, reason: 'mipmap-$density/ic_launcher.png must exist');
        final iconBytes = iconFile.readAsBytesSync();
        expect(iconBytes.length, greaterThan(100));
        expect(iconBytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
      }
    });

    test('2. Environment Configuration & Secret Masking Diagnostics', () {
      // 2.1 Enum and active environment
      final env = EnvironmentConfig.current;
      expect([AppEnvironment.development, AppEnvironment.staging, AppEnvironment.production], contains(env));

      // 2.2 Masking secrets
      expect(EnvironmentConfig.maskSecret(null), equals('(not set)'));
      expect(EnvironmentConfig.maskSecret(''), equals('(not set)'));
      expect(EnvironmentConfig.maskSecret('12345'), equals('****'));
      expect(EnvironmentConfig.maskSecret('AIzaSy1234567890abcdef'), equals('AIza...cdef'));

      // 2.3 Diagnostic summary without secret leakage
      final summary = EnvironmentConfig.getDiagnosticSummary();
      expect(summary.containsKey('environment'), isTrue);
      expect(summary.containsKey('isReleaseMode'), isTrue);
      expect(summary.containsKey('supabaseConfigured'), isTrue);
      expect(summary.containsKey('supabaseKeyMasked'), isTrue);
      expect(summary.containsKey('geminiKeyConfigured'), isTrue);
      expect(summary.containsKey('geminiKeyMasked'), isTrue);

      // Verify no raw keys leaked in diagnostics
      final summaryStr = summary.toString();
      expect(summaryStr.contains('AIzaSy'), isFalse);
    });

    test('3. Privacy-Preserving Crash Monitoring & Breadcrumbs', () {
      final crashMonitor = CrashMonitoringService.instance;
      crashMonitor.clearForTesting();

      // 3.1 Record error with secret scrub test
      const testSecretKey = 'AIzaSySecretApiKey123456789012345678';
      const testEmail = 'student.scholar@university.edu';
      crashMonitor.recordError(
        'Network exception while contacting $testEmail with key $testSecretKey',
        StackTrace.current,
        reason: 'Sync operation failure',
        metadata: {
          'api_key': testSecretKey,
          'user_email': testEmail,
          'status': 500,
        },
      );

      final errors = crashMonitor.recordedErrors;
      expect(errors.length, equals(1));
      final record = errors.first;
      expect(record['exception'], isNot(contains(testSecretKey)));
      expect(record['exception'], contains('[MASKED_KEY]'));
      expect(record['exception'], isNot(contains(testEmail)));
      expect(record['exception'], contains('[MASKED_EMAIL]'));

      final metadata = record['metadata'] as Map<String, dynamic>;
      expect(metadata['api_key'], equals('[REDACTED]'));
      expect(metadata['user_email'], equals('[REDACTED]'));
      expect(metadata['status'], equals(500));

      // 3.2 Add breadcrumb with scrubbing
      crashMonitor.addBreadcrumb('Navigation to settings with token Bearer eyJhbGciOiJIUz', category: 'nav');
      final crumbs = crashMonitor.recentBreadcrumbs;
      expect(crumbs.length, equals(1));
      expect(crumbs.first['message'], contains('Bearer [MASKED_TOKEN]'));
    });

    test('4. Product Analytics Service & Sanitization', () {
      final analytics = AnalyticsService.instance;
      analytics.clearForTesting();

      analytics.logEvent(AnalyticsService.appLaunch);
      analytics.logEvent(AnalyticsService.materialImported, parameters: {
        'format': 'pdf',
        'page_count': 14,
        'user_notes': 'Secret exam questions leaked here',
        'api_token': 'secret123',
      });

      final events = analytics.loggedEvents;
      expect(events.length, equals(2));
      expect(events[0]['name'], equals('app_launch'));
      expect(events[1]['name'], equals('material_imported'));

      final params = events[1]['parameters'] as Map<String, dynamic>;
      expect(params['format'], equals('pdf'));
      expect(params['page_count'], equals(14));
      // Sensitive keys must be scrubbed
      expect(params['user_notes'], equals('[REDACTED]'));
      expect(params['api_token'], equals('[REDACTED]'));
    });

    test('5. Cascading Local Account Deletion across All SQLite Tables', () async {
      final testDbPath = 'test_phase12_account_deletion.db';
      final file = File(testDbPath);
      if (file.existsSync()) file.deleteSync();

      LocalDbService.instance.setCustomPathForTesting(testDbPath);
      final db = await LocalDbService.instance.database;
      await LocalDbService.instance.clearAllData();

      const testUser = 'user_release_test_42';
      final now = DateTime.now().toUtc().toIso8601String();

      // Seed user records across major Phase 0-11 tables
      await db.insert('workspaces', {'id': 'ws_1', 'user_id': testUser, 'name': 'Engineering', 'created_at': now, 'updated_at': now});
      await db.insert('folders', {'id': 'f_1', 'user_id': testUser, 'name': 'Algorithms', 'created_at': now, 'updated_at': now});
      await db.insert('notes', {'id': 'n_1', 'user_id': testUser, 'folder_id': 'f_1', 'title': 'Graph Search', 'content': 'BFS and DFS', 'created_at': now, 'updated_at': now});
      await db.insert('materials', {'id': 'm_1', 'user_id': testUser, 'title': 'Syllabus', 'type': 'PDF', 'created_at': now, 'updated_at': now});
      await db.insert('flashcards', {'id': 'fc_1', 'user_id': testUser, 'topic': 'Trees', 'front': 'AVL Tree', 'back': 'Balanced BST', 'created_at': now});
      await db.insert('study_packs', {'id': 'sp_1', 'owner_id': testUser, 'name': 'Midterm Prep', 'created_at': now, 'updated_at': now});
      await db.insert('ai_conversations', {'id': 'conv_1', 'user_id': testUser, 'title': 'Tree Algorithms', 'mode': 'tutor', 'created_at': now, 'updated_at': now});
      await db.insert('document_chunks', {'id': 'chunk_1', 'material_id': 'm_1', 'user_id': testUser, 'text': 'Binary Search Tree traversal', 'created_at': now, 'updated_at': now});
      await db.insert('student_profiles', {'id': testUser, 'username': 'scholar42', 'full_name': 'Scholar FortyTwo', 'created_at': now, 'updated_at': now});

      // Verify records are present
      final wsBefore = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM workspaces WHERE user_id = ?', [testUser])) ?? 0;
      expect(wsBefore, equals(1));
      final notesBefore = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM notes WHERE user_id = ?', [testUser])) ?? 0;
      expect(notesBefore, equals(1));
      final chunksBefore = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM document_chunks WHERE user_id = ?', [testUser])) ?? 0;
      expect(chunksBefore, equals(1));

      // Execute cascading wipe via clearUserData
      await LocalDbService.instance.clearUserData(testUser);

      // Verify all tables have 0 rows for this user
      final wsAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM workspaces WHERE user_id = ?', [testUser])) ?? 0;
      expect(wsAfter, equals(0));
      final foldersAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM folders WHERE user_id = ?', [testUser])) ?? 0;
      expect(foldersAfter, equals(0));
      final notesAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM notes WHERE user_id = ?', [testUser])) ?? 0;
      expect(notesAfter, equals(0));
      final matsAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM materials WHERE user_id = ?', [testUser])) ?? 0;
      expect(matsAfter, equals(0));
      final chunksAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM document_chunks WHERE user_id = ?', [testUser])) ?? 0;
      expect(chunksAfter, equals(0));
      final convsAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM ai_conversations WHERE user_id = ?', [testUser])) ?? 0;
      expect(convsAfter, equals(0));
      final profileAfter = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM student_profiles WHERE id = ?', [testUser])) ?? 0;
      expect(profileAfter, equals(0));

      await LocalDbService.instance.closeForTesting();
      if (file.existsSync()) file.deleteSync();
    });

    test('6. User Data Export Archive Integrity & Zero Secret Leakage', () async {
      final testDbPath = 'test_phase12_data_export.db';
      final file = File(testDbPath);
      if (file.existsSync()) file.deleteSync();

      LocalDbService.instance.setCustomPathForTesting(testDbPath);
      final db = await LocalDbService.instance.database;
      await LocalDbService.instance.clearAllData();

      const testUser = 'export_user_99';
      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert('workspaces', {'id': 'ws_exp', 'user_id': testUser, 'name': 'Computer Science', 'created_at': now, 'updated_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('folders', {'id': 'f_exp', 'user_id': testUser, 'name': 'Data Structures', 'created_at': now, 'updated_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('notes', {'id': 'n_exp', 'user_id': testUser, 'folder_id': 'f_exp', 'title': 'Binary Heaps', 'content': 'Priority Queue implementation', 'created_at': now, 'updated_at': now}, conflictAlgorithm: ConflictAlgorithm.replace);

      final accountService = AccountManagementService(localDb: LocalDbService.instance);
      final jsonResult = await accountService.exportUserData(userId: testUser);

      expect(jsonResult.isNotEmpty, isTrue);
      final decoded = jsonDecode(jsonResult) as Map<String, dynamic>;

      expect(decoded['app'], equals('Study Vault'));
      expect(decoded['export_version'], equals('1.0.0'));
      expect(decoded['user_id'], equals(testUser));
      expect(decoded['vault_data'], isNotNull);

      final vaultData = decoded['vault_data'] as Map<String, dynamic>;
      final workspaces = vaultData['workspaces'] as List;
      expect(workspaces.length, equals(1));
      expect(workspaces[0]['name'], equals('Computer Science'));

      final notes = vaultData['notes'] as List;
      expect(notes.length, equals(1));
      expect(notes[0]['title'], equals('Binary Heaps'));

      // Strict security check: Ensure no API keys or passwords exist in the export
      final rawExportString = jsonResult.toLowerCase();
      expect(rawExportString.contains('password_hash'), isFalse);
      expect(rawExportString.contains('anonkey'), isFalse);
      expect(rawExportString.contains('service_role'), isFalse);
      expect(rawExportString.contains('aizasy'), isFalse);

      await LocalDbService.instance.closeForTesting();
      if (file.existsSync()) file.deleteSync();
    });
  });
}
