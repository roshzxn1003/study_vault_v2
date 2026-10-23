import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/vault/domain/models/models.dart';
import 'package:study_vault/features/vault/presentation/widgets/material_preview_widget.dart';
import 'package:study_vault/features/vault/presentation/widgets/material_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleNote = MaterialItem(
    id: 'mat_1',
    userId: 'user_1',
    workspaceId: 'ws_1',
    title: 'Operating Systems Virtual Memory Summary',
    type: VaultMaterialType.note,
    content: 'Paging is a memory management scheme that eliminates the need for contiguous allocation.',
    fileSize: 1024,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final samplePdf = MaterialItem(
    id: 'mat_2',
    userId: 'user_1',
    workspaceId: 'ws_1',
    title: 'Computer Networks Lecture 5.pdf',
    type: VaultMaterialType.pdf,
    filePath: '/tmp/test_cn.pdf',
    fileSize: 2048500,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleLink = MaterialItem(
    id: 'mat_3',
    userId: 'user_1',
    workspaceId: 'ws_1',
    title: 'MIT Operating Systems Courseware',
    type: VaultMaterialType.link,
    remoteUrl: 'https://ocw.mit.edu/courses/electrical-engineering-and-computer-science',
    fileSize: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleDoc = MaterialItem(
    id: 'mat_4',
    userId: 'user_1',
    workspaceId: 'ws_1',
    title: 'Database Assignment 1.docx',
    type: VaultMaterialType.document,
    originalFileName: 'Database Assignment 1.docx',
    fileSize: 524288,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('MaterialPreviewWidget Unit & Component Tests', () {
    testWidgets('renders compact note preview correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialPreviewWidget(
              material: sampleNote,
              isCompact: true,
            ),
          ),
        ),
      );

      expect(find.text('NOTE'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });

    testWidgets('renders full note preview with word count and text snippet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialPreviewWidget(
              material: sampleNote,
              height: 250,
              showInteractiveOverlay: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Paging is a memory management'), findsOneWidget);
      expect(find.textContaining('words'), findsOneWidget);
      expect(find.text('Open Viewer'), findsOneWidget);
    });

    testWidgets('renders compact PDF preview correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialPreviewWidget(
              material: samplePdf,
              isCompact: true,
            ),
          ),
        ),
      );

      expect(find.text('PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });

    testWidgets('renders link preview with domain', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialPreviewWidget(
              material: sampleLink,
              height: 200,
            ),
          ),
        ),
      );

      expect(find.text('ocw.mit.edu'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    });

    testWidgets('renders document preview with file extension', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialPreviewWidget(
              material: sampleDoc,
              height: 200,
            ),
          ),
        ),
      );

      expect(find.text('.DOCX Document'), findsOneWidget);
      expect(find.byIcon(Icons.article_rounded), findsOneWidget);
    });

    testWidgets('MaterialCard includes preview thumbnail', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialCard(
              material: sampleNote,
            ),
          ),
        ),
      );

      expect(find.byType(MaterialPreviewWidget), findsOneWidget);
      expect(find.text('Operating Systems Virtual Memory Summary'), findsOneWidget);
      expect(find.text('NOTE'), findsOneWidget);
    });
  });
}
