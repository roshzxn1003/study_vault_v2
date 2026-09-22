import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_vault/core/services/connectivity_service.dart';
import 'package:study_vault/features/auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/sharing_repository.dart';
import '../../domain/models/models.dart';

/// Provider for SharingRepository.
final sharingRepositoryProvider = Provider<SharingRepository>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return SharingRepository(connectivity: connectivity);
});

/// Current student's public profile and identity.
final currentStudentProfileProvider = FutureProvider<StudentProfile?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = authRepo.getCurrentUser();
  if (user == null) return null;

  final repo = ref.watch(sharingRepositoryProvider);
  var profile = await repo.getStudentProfile(user.id);
  if (profile == null) {
    // Generate default public student identity
    final defaultUsername = user.email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    final defaultName = user.fullName ?? 'Study Vault Scholar';
    profile = StudentProfile(
      id: user.id,
      username: defaultUsername,
      fullName: defaultName,
      isSearchable: true,
    );
    await repo.updatePublicProfile(
      userId: user.id,
      username: defaultUsername,
      fullName: defaultName,
    );
  }
  return profile;
});

/// Student search query state.
final studentSearchQueryProvider = StateProvider<String>((ref) => '');

/// Debounced student search results provider.
final studentSearchResultsProvider = FutureProvider.autoDispose<List<StudentProfile>>((ref) async {
  final query = ref.watch(studentSearchQueryProvider);
  if (query.trim().isEmpty) return [];

  // Debounce delay
  await Future.delayed(const Duration(milliseconds: 300));

  final authRepo = ref.read(authRepositoryProvider);
  final currentUserId = authRepo.getCurrentUser()?.id ?? '';
  final repo = ref.read(sharingRepositoryProvider);

  return await repo.searchStudents(query: query, currentUserId: currentUserId);
});

/// State of "Shared with me" feed.
class SharedWithMeState {
  final List<ShareItem> items;
  final bool isLoading;
  final String? errorMessage;

  const SharedWithMeState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SharedWithMeState copyWith({
    List<ShareItem>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SharedWithMeState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SharedWithMeNotifier extends StateNotifier<SharedWithMeState> {
  final SharingRepository _repo;
  final Ref _ref;

  SharedWithMeNotifier(this._repo, this._ref) : super(const SharedWithMeState()) {
    loadItems();
  }

  String get _userId => _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.getSharedWithMe(_userId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load materials shared with you.',
      );
    }
  }

  Future<void> removeItem(String shareId) async {
    await _repo.removeSharedWithMe(shareId);
    state = state.copyWith(
      items: state.items.where((i) => i.id != shareId).toList(),
    );
  }
}

final sharedWithMeProvider = StateNotifierProvider<SharedWithMeNotifier, SharedWithMeState>((ref) {
  final repo = ref.watch(sharingRepositoryProvider);
  return SharedWithMeNotifier(repo, ref);
});

/// State of "Shared by me" feed.
class SharedByMeState {
  final List<ShareItem> items;
  final bool isLoading;
  final String? errorMessage;

  const SharedByMeState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SharedByMeState copyWith({
    List<ShareItem>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SharedByMeState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SharedByMeNotifier extends StateNotifier<SharedByMeState> {
  final SharingRepository _repo;
  final Ref _ref;

  SharedByMeNotifier(this._repo, this._ref) : super(const SharedByMeState()) {
    loadItems();
  }

  String get _userId => _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.getSharedByMe(_userId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load materials shared by you.',
      );
    }
  }

  Future<void> revokeShare(String shareId) async {
    await _repo.revokeShare(shareId);
    await loadItems();
  }

  Future<void> updatePermission(String shareId, Set<SharePermission> perms) async {
    await _repo.updateSharePermission(shareId: shareId, permissions: perms);
    await loadItems();
  }
}

final sharedByMeProvider = StateNotifierProvider<SharedByMeNotifier, SharedByMeState>((ref) {
  final repo = ref.watch(sharingRepositoryProvider);
  return SharedByMeNotifier(repo, ref);
});

/// State of Study Groups.
class StudyGroupsState {
  final List<StudyGroup> groups;
  final bool isLoading;
  final String? errorMessage;

  const StudyGroupsState({
    this.groups = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  StudyGroupsState copyWith({
    List<StudyGroup>? groups,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudyGroupsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class StudyGroupsNotifier extends StateNotifier<StudyGroupsState> {
  final SharingRepository _repo;
  final Ref _ref;

  StudyGroupsNotifier(this._repo, this._ref) : super(const StudyGroupsState()) {
    loadGroups();
  }

  String get _userId => _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final groups = await _repo.getGroups(_userId);
      state = state.copyWith(groups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load study groups.',
      );
    }
  }

  Future<StudyGroup> createGroup({required String name, String? description}) async {
    final profile = await _ref.read(currentStudentProfileProvider.future);
    final group = await _repo.createGroup(
      ownerId: _userId,
      name: name,
      description: description,
      ownerUsername: profile?.username,
    );
    await loadGroups();
    return group;
  }

  Future<void> leaveGroup(String groupId) async {
    await _repo.leaveGroup(groupId: groupId, userId: _userId);
    await loadGroups();
  }

  Future<void> deleteGroup(String groupId) async {
    await _repo.deleteGroup(groupId);
    await loadGroups();
  }

  Future<void> respondToInvitation(String groupId, bool accept) async {
    await _repo.respondToInvitation(groupId: groupId, userId: _userId, accept: accept);
    await loadGroups();
  }
}

final studyGroupsProvider = StateNotifierProvider<StudyGroupsNotifier, StudyGroupsState>((ref) {
  final repo = ref.watch(sharingRepositoryProvider);
  return StudyGroupsNotifier(repo, ref);
});

/// Group details provider family.
final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
  final repo = ref.watch(sharingRepositoryProvider);
  return await repo.getGroupMembers(groupId);
});

final groupResourcesProvider = FutureProvider.family<List<GroupResource>, String>((ref, groupId) async {
  final repo = ref.watch(sharingRepositoryProvider);
  return await repo.getGroupResources(groupId);
});

/// State of Study Packs.
class StudyPacksState {
  final List<StudyPack> packs;
  final bool isLoading;
  final String? errorMessage;

  const StudyPacksState({
    this.packs = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  StudyPacksState copyWith({
    List<StudyPack>? packs,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudyPacksState(
      packs: packs ?? this.packs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class StudyPacksNotifier extends StateNotifier<StudyPacksState> {
  final SharingRepository _repo;
  final Ref _ref;

  StudyPacksNotifier(this._repo, this._ref) : super(const StudyPacksState()) {
    loadPacks();
  }

  String get _userId => _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';

  Future<void> loadPacks() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final packs = await _repo.getMyStudyPacks(_userId);
      state = state.copyWith(packs: packs, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load study packs.',
      );
    }
  }

  Future<StudyPack> createStudyPack({
    required String name,
    String? description,
    required List<String> materialIds,
    required Map<String, String> materialTitles,
    required Map<String, String> materialTypes,
  }) async {
    final profile = await _ref.read(currentStudentProfileProvider.future);
    final pack = await _repo.createStudyPack(
      ownerId: _userId,
      name: name,
      description: description,
      materialIds: materialIds,
      materialTitles: materialTitles,
      materialTypes: materialTypes,
      ownerUsername: profile?.username,
    );
    await loadPacks();
    return pack;
  }
}

final studyPacksProvider = StateNotifierProvider<StudyPacksNotifier, StudyPacksState>((ref) {
  final repo = ref.watch(sharingRepositoryProvider);
  return StudyPacksNotifier(repo, ref);
});

final studyPackDetailProvider = FutureProvider.family<StudyPack?, String>((ref, packId) async {
  final repo = ref.watch(sharingRepositoryProvider);
  return await repo.getStudyPackDetails(packId);
});

/// State of Collaboration Notifications.
class NotificationsState {
  final List<ShareNotification> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<ShareNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final SharingRepository _repo;
  final Ref _ref;

  NotificationsNotifier(this._repo, this._ref) : super(const NotificationsState()) {
    loadNotifications();
  }

  String get _userId => _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);
    try {
      final notifs = await _repo.getNotifications(_userId);
      final count = await _repo.getUnreadNotificationCount(_userId);
      state = state.copyWith(notifications: notifs, unreadCount: count, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAsRead(String notifId) async {
    await _repo.markNotificationAsRead(notifId);
    await loadNotifications();
  }

  Future<void> markAllAsRead() async {
    await _repo.markAllNotificationsAsRead(_userId);
    await loadNotifications();
  }
}

final shareNotificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repo = ref.watch(sharingRepositoryProvider);
  return NotificationsNotifier(repo, ref);
});

/// Privacy settings provider.
final sharingPrivacySettingsProvider = StateNotifierProvider<SharingPrivacySettingsNotifier, SharingPrivacySettings>((ref) {
  final repo = ref.watch(sharingRepositoryProvider);
  return SharingPrivacySettingsNotifier(repo, ref);
});

class SharingPrivacySettingsNotifier extends StateNotifier<SharingPrivacySettings> {
  final SharingRepository _repo;
  final Ref _ref;

  SharingPrivacySettingsNotifier(this._repo, this._ref) : super(const SharingPrivacySettings()) {
    _load();
  }

  String get _userId => _ref.read(authRepositoryProvider).getCurrentUser()?.id ?? 'guest';

  Future<void> _load() async {
    try {
      final settings = await _repo.getPrivacySettings(_userId);
      state = settings;
    } catch (e) {
      debugPrint('SharingPrivacySettingsNotifier: Failed to load privacy settings: $e');
    }
  }

  Future<void> updateSettings({bool? isSearchable, String? allowGroupInvites}) async {
    final updated = state.copyWith(
      isSearchable: isSearchable,
      allowGroupInvites: allowGroupInvites,
    );
    state = updated;
    await _repo.updatePrivacySettings(_userId, updated);
    _ref.invalidate(currentStudentProfileProvider);
  }
}
