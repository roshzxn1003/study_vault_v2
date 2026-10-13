import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study_vault/core/ai/ai_models.dart';
import 'package:study_vault/core/database/local_db_service.dart';
import 'package:study_vault/features/ai/ai_screen.dart';
import 'package:study_vault/features/ai/data/repositories/ai_conversation_repository.dart';
import 'package:study_vault/features/ai/presentation/providers/chat_provider.dart';
import 'package:study_vault/features/ai/presentation/widgets/material_attachment_dialog.dart';
import 'package:study_vault/features/vault/presentation/providers/vault_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDbService localDb;
  late Directory tempDir;
  late AiConversationRepository conversationRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('study_vault_chat_test_');
    localDb = LocalDbService.instance;
    localDb.setCustomPathForTesting('${tempDir.path}/test_chat.db');

    final db = await localDb.database;
    await db.delete('ai_messages');
    await db.delete('ai_conversations');

    conversationRepo = AiConversationRepository(localDb: localDb);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('ChatGPT AI Chat — Conversation Repository Persistence', () {
    test('createConversation creates and persists new session', () async {
      final conv = await conversationRepo.createConversation(
        title: 'Operating Systems Deadlock Discussion',
        workspaceId: 'ws_college',
        subjectId: 'subj_os',
        materialId: 'mat_pdf_1',
        mode: 'tutor',
        userId: 'student_1',
      );

      expect(conv.id, startsWith('conv_'));
      expect(conv.title, equals('Operating Systems Deadlock Discussion'));
      expect(conv.materialId, equals('mat_pdf_1'));
      expect(conv.mode, equals('tutor'));

      final list = await conversationRepo.listConversations(userId: 'student_1');
      expect(list.length, equals(1));
      expect(list.first.id, equals(conv.id));
      expect(list.first.title, equals(conv.title));
    });

    test('saveMessage and loadMessages store and retrieve user & assistant messages with citations', () async {
      final conv = await conversationRepo.createConversation(
        title: 'DBMS ACID Q&A',
        userId: 'student_1',
      );

      final userMsg = ChatMessage(
        id: 'msg_u1',
        role: 'user',
        content: 'Explain Atomicity in transactions',
      );
      await conversationRepo.saveMessage(conv.id, userMsg, userId: 'student_1');

      final assistantMsg = ChatMessage(
        id: 'msg_a1',
        role: 'assistant',
        content: 'Atomicity ensures all operations within a transaction succeed or all fail together.',
        sources: [
          AiSource(
            chunkId: 'chunk_dbms_1',
            fileId: 'mat_dbms',
            fileName: 'Database_Concepts.pdf',
            pageNumber: 42,
            similarity: 0.94,
            snippet: 'Atomicity: All changes to data are performed as if they were a single operation.',
          ),
        ],
      );
      await conversationRepo.saveMessage(conv.id, assistantMsg, userId: 'student_1');

      final messages = await conversationRepo.loadMessages(conv.id);
      expect(messages.length, equals(2));
      expect(messages[0].id, equals('msg_u1'));
      expect(messages[0].role, equals('user'));
      expect(messages[0].content, equals('Explain Atomicity in transactions'));

      expect(messages[1].id, equals('msg_a1'));
      expect(messages[1].role, equals('assistant'));
      expect(messages[1].sources, isNotNull);
      expect(messages[1].sources!.length, equals(1));
      expect(messages[1].sources!.first.fileName, equals('Database_Concepts.pdf'));
      expect(messages[1].sources!.first.pageNumber, equals(42));
    });

    test('renameConversation updates session title', () async {
      final conv = await conversationRepo.createConversation(
        title: 'Initial Title',
        userId: 'student_1',
      );

      await conversationRepo.renameConversation(conv.id, 'Renamed Study Topic');

      final list = await conversationRepo.listConversations(userId: 'student_1');
      expect(list.first.title, equals('Renamed Study Topic'));
    });

    test('deleteConversation cascades to delete session and all messages', () async {
      final conv = await conversationRepo.createConversation(
        title: 'To Be Deleted',
        userId: 'student_1',
      );

      await conversationRepo.saveMessage(
        conv.id,
        ChatMessage(role: 'user', content: 'Temporary message'),
        userId: 'student_1',
      );

      await conversationRepo.deleteConversation(conv.id);

      final list = await conversationRepo.listConversations(userId: 'student_1');
      expect(list.isEmpty, isTrue);

      final messages = await conversationRepo.loadMessages(conv.id);
      expect(messages.isEmpty, isTrue);
    });
  });

  group('ChatGPT AI Chat — ChatNotifier State Management', () {
    test('Initial ChatState has default model gemini-1.5-flash and ask mode', () {
      final container = ProviderContainer(
        overrides: [
          aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(chatProvider);
      expect(state.activeModel, equals('gemini-1.5-flash'));
      expect(state.currentMode, equals('ask'));
      expect(state.activeMaterialId, isNull);
      expect(state.messages.isEmpty, isTrue);
    });

    test('setModel switches model properly', () {
      final container = ProviderContainer(
        overrides: [
          aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.setModel('gemini-1.5-pro');

      expect(container.read(chatProvider).activeModel, equals('gemini-1.5-pro'));
    });

    test('setMaterial and clearMaterial toggle document grounding context', () {
      final container = ProviderContainer(
        overrides: [
          aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.setMaterial('mat_os_pdf', 'Operating Systems Syllabus.pdf');

      expect(container.read(chatProvider).activeMaterialId, equals('mat_os_pdf'));
      expect(container.read(chatProvider).activeMaterialTitle, equals('Operating Systems Syllabus.pdf'));

      notifier.clearMaterial();
      expect(container.read(chatProvider).activeMaterialId, isNull);
      expect(container.read(chatProvider).activeMaterialTitle, isNull);
    });

    test('startNewChat resets current conversation session safely', () {
      final container = ProviderContainer(
        overrides: [
          aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.setMaterial('mat_1', 'Notes.pdf');
      notifier.setModel('gemini-1.5-pro');

      notifier.startNewChat();

      final state = container.read(chatProvider);
      expect(state.conversationId, isNull);
      expect(state.messages.isEmpty, isTrue);
      expect(state.activeModel, equals('gemini-1.5-pro'));
      expect(state.activeMaterialId, equals('mat_1'));
    });
  });

  group('ChatGPT AI Chat — UI & Widget Tests', () {
    testWidgets('MaterialAttachmentDialog renders search and all materials option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
            vaultProvider.overrideWith(
              (ref) => _FakeVaultNotifier(const VaultState(materials: [])),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MaterialAttachmentDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Material to Ask'), findsOneWidget);
      expect(find.text('Search All Materials'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AIScreen renders model picker pill, mode chips, and ChatGPT input bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
            vaultProvider.overrideWith(
              (ref) => _FakeVaultNotifier(const VaultState(materials: [])),
            ),
          ],
          child: const MaterialApp(
            home: AIScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Model picker in AppBar
      expect(find.text('Gemini 1.5 Flash'), findsOneWidget);

      // Empty state greeting
      expect(find.text('What do you want to learn today?'), findsOneWidget);

      // Study Mode Selector Chips
      expect(find.text('Ask Q&A'), findsOneWidget);
      expect(find.text('Socratic Tutor'), findsOneWidget);
      expect(find.text('Explain Simply'), findsOneWidget);

      // ChatGPT style input area
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // Drawer toggle button
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    });

    testWidgets('AIScreen opens history drawer when menu icon is tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiConversationRepositoryProvider.overrideWithValue(conversationRepo),
            vaultProvider.overrideWith(
              (ref) => _FakeVaultNotifier(const VaultState(materials: [])),
            ),
          ],
          child: const MaterialApp(
            home: AIScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap drawer button
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Drawer contents visible
      expect(find.text('Study Vault AI'), findsOneWidget);
      expect(find.text('New Chat'), findsOneWidget);
      expect(find.text('No previous chats'), findsOneWidget);
    });
  });
}

class _FakeVaultNotifier extends StateNotifier<VaultState> implements VaultNotifier {
  _FakeVaultNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
