import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/providers/database_providers.dart';
import 'package:study_vault/core/database/local_db_service.dart';

class HomeData {
  final List<Map<String, dynamic>> folders;
  final List<Map<String, dynamic>> recentFiles;

  HomeData({required this.folders, required this.recentFiles});
}

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final folderRepo = ref.watch(folderRepositoryProvider);
  final fileRepo = ref.watch(fileRepositoryProvider);

  final folders = await folderRepo.getFolders();
  final files = await fileRepo.getFiles();
  
  // Get the 5 most recent files
  final recentFiles = files.take(5).toList();

  return HomeData(folders: folders, recentFiles: recentFiles);
});

final allFilesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final fileRepo = ref.watch(fileRepositoryProvider);
  return await fileRepo.getFiles();
});

final vaultStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await LocalDbService.instance.getVaultStats();
});

final examGoalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await LocalDbService.instance.getExamGoals();
});


