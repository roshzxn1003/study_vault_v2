import "package:study_vault/features/files/data/repositories/storage_repository.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/features/profile/data/repositories/profile_repository.dart';
import 'package:study_vault/features/folders/data/repositories/folder_repository.dart';
import 'package:study_vault/features/notes/data/repositories/note_repository.dart';
import 'package:study_vault/features/files/data/repositories/file_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());
final folderRepositoryProvider = Provider((ref) => FolderRepository());
final noteRepositoryProvider = Provider((ref) => NoteRepository());
final fileRepositoryProvider = Provider((ref) => FileRepository());
final storageRepositoryProvider = Provider((ref) => StorageRepository());
