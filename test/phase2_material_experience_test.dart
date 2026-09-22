import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/services/file_action_service.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/widgets/material_action_sheet.dart';
import 'package:study_vault/features/sharing/presentation/screens/create_study_pack_screen.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';
import 'package:study_vault/features/vault/presentation/screens/vault_screen.dart';
import 'package:study_vault/features/vault/presentation/widgets/vault_search_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: FileActionService & Material Types', () {
    test('VaultMaterialType fileExtension maps correctly', () {
      expect(VaultMaterialType.pdf.fileExtension, 'pdf');
      expect(VaultMaterialType.image.fileExtension, 'jpg');
      expect(VaultMaterialType.note.fileExtension, 'txt');
      expect(VaultMaterialType.document.fileExtension, 'pdf');
      expect(VaultMaterialType.link.fileExtension, 'html');
    });

    testWidgets('FileActionService handles missing file gracefully on download', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => FileActionService.instance.downloadFile(
                  context: ctx,
                  sourceFilePath: '/nonexistent/path/file.pdf',
                  fileName: 'test.pdf',
                ),
                child: const Text('Download'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(find.text('Source file not found.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('FileActionService handles missing file gracefully on openWith', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => FileActionService.instance.openWith(
                  context: ctx,
                  filePath: '/nonexistent/path/file.pdf',
                  title: 'Test Material',
                ),
                child: const Text('OpenWith'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenWith'));
      await tester.pump();
      expect(find.text('File not found on device storage.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Phase 2: MaterialActionSheet Widget Tests', () {
    final sampleMaterial = MaterialItem(
      id: 'mat_test_1',
      userId: 'user_1',
      title: 'Operating Systems Chapter 3',
      type: VaultMaterialType.pdf,
      filePath: '/tmp/os_ch3.pdf',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('MaterialActionSheet renders all expected actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MaterialActionSheet.show(
                  context: context,
                  material: sampleMaterial,
                  onDelete: () {},
                ),
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Operating Systems Chapter 3'), findsOneWidget);
      expect(find.text('Open in Study Vault'), findsOneWidget);
      expect(find.text('Open with...'), findsOneWidget);
      expect(find.text('Download / Export File'), findsOneWidget);
      expect(find.text('Share File via Android'), findsOneWidget);
      expect(find.text('Share with Student'), findsOneWidget);
      expect(find.text('Share to Study Group'), findsOneWidget);
      expect(find.text('Add to Study Pack'), findsOneWidget);
      expect(find.text('Material Details'), findsOneWidget);
      expect(find.text('Delete Material'), findsOneWidget);
    });
  });

  group('Phase 2: CreateStudyPackScreen Selection Controls', () {
    final sampleMaterials = [
      MaterialItem(
        id: 'mat_1',
        userId: 'user_1',
        title: 'Algorithms Homework 1',
        type: VaultMaterialType.pdf,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      MaterialItem(
        id: 'mat_2',
        userId: 'user_1',
        title: 'Database Normalization Notes',
        type: VaultMaterialType.note,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    testWidgets('CreateStudyPackScreen supports Select All and Clear Selection', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultProvider.overrideWith(
              (ref) => _FakeVaultNotifier(
                VaultState(
                  materials: sampleMaterials,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: CreateStudyPackScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Create Study Pack'), findsOneWidget);
      expect(find.text('Pack Name'), findsOneWidget);
      expect(find.text('Materials (0/2)'), findsOneWidget);
      expect(find.text('Create Study Pack (0)'), findsOneWidget);

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();

      expect(find.text('Materials (2/2)'), findsOneWidget);
      expect(find.text('Create Study Pack (2)'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Materials (0/2)'), findsOneWidget);
      expect(find.text('Create Study Pack (0)'), findsOneWidget);
    });
  });

  group('Phase 2: VaultScreen Controls Hierarchy', () {
    testWidgets('VaultScreen renders correct visual hierarchy: Title, Search, Tabs, Action Row', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultProvider.overrideWith(
              (ref) => _FakeVaultNotifier(
                const VaultState(
                  materials: [],
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Title Row
      expect(find.text('My Vault'), findsOneWidget);
      expect(find.text('Central Academic Library'), findsOneWidget);

      // 2. Search Bar
      expect(find.byType(VaultSearchBar), findsOneWidget);

      // 3. Tabs
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Folders'), findsOneWidget);

      // 4. Secondary Action Row
      expect(find.text('Filter'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.swap_vert_rounded), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
    });
  });
}

class _FakeVaultNotifier extends StateNotifier<VaultState> implements VaultNotifier {
  _FakeVaultNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

