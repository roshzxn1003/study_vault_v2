class MockFolder {
  final String id;
  final String name;
  final int fileCount;

  MockFolder({required this.id, required this.name, required this.fileCount});
}

class MockFile {
  final String id;
  final String name;
  final String type;
  final String updated;
  final String folderId;

  MockFile({required this.id, required this.name, required this.type, required this.updated, required this.folderId});
}

class MockNote {
  final String id;
  final String title;
  final String content;
  final String folderId;
  final String updated;

  MockNote({required this.id, required this.title, required this.content, required this.folderId, required this.updated});
}

final List<MockFolder> mockFolders = [
  MockFolder(id: '1', name: 'DBMS', fileCount: 24),
  MockFolder(id: '2', name: 'Operating Systems', fileCount: 18),
  MockFolder(id: '3', name: 'Computer Networks', fileCount: 21),
  MockFolder(id: '4', name: 'Java', fileCount: 15),
  MockFolder(id: '5', name: 'Software Engineering', fileCount: 10),
];

final List<MockFile> mockFiles = [
  MockFile(id: 'f1', name: 'DBMS Unit 1.pdf', type: 'PDF', updated: '2 days ago', folderId: '1'),
  MockFile(id: 'f2', name: 'DBMS Unit 2.pdf', type: 'PDF', updated: 'Yesterday', folderId: '1'),
  MockFile(id: 'f3', name: 'Transactions.pdf', type: 'PDF', updated: '1 week ago', folderId: '1'),
  MockFile(id: 'f4', name: 'OS Unit 3.pdf', type: 'PDF', updated: '3 days ago', folderId: '2'),
  MockFile(id: 'f5', name: 'CN Important Questions.pdf', type: 'PDF', updated: '5 days ago', folderId: '3'),
];

final List<MockNote> mockNotes = [
  MockNote(id: 'n1', title: 'ACID Properties', content: 'A transaction is a logical unit of work... \n\nAtomicity: All or nothing.\nConsistency: Database remains consistent.\nIsolation: Concurrent transactions don\'t interfere.\nDurability: Changes are permanent.', folderId: '1', updated: 'Yesterday'),
  MockNote(id: 'n2', title: 'Transaction States', content: 'The different states of a transaction include Active, Partially Committed, Committed, and Aborted.', folderId: '1', updated: '2 days ago'),
  MockNote(id: 'n3', title: 'Deadlock', content: 'A state where two or more processes are waiting for each other to release resources.', folderId: '2', updated: '1 week ago'),
  MockNote(id: 'n4', title: 'TCP vs UDP', content: 'TCP is connection-oriented and reliable, while UDP is connectionless and faster.', folderId: '3', updated: '3 days ago'),
];
