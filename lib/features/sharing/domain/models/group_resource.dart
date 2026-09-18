import 'share_permission.dart';

/// Resource shared within a Study Group feed.
class GroupResource {
  final String id;
  final String groupId;
  final String resourceId;
  final String resourceType; // 'material', 'study_pack'
  final String sharedBy;
  final String? sharedByUsername;
  final String resourceTitle;
  final Set<SharePermission> permissions;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const GroupResource({
    required this.id,
    required this.groupId,
    required this.resourceId,
    this.resourceType = 'material',
    required this.sharedBy,
    this.sharedByUsername,
    required this.resourceTitle,
    this.permissions = const {SharePermission.view},
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get canSaveCopy => permissions.contains(SharePermission.saveCopy);
  bool get canDownload => permissions.contains(SharePermission.download);

  String get displaySharer => sharedByUsername != null ? '@${sharedByUsername!.replaceAll('@', '')}' : 'Member';

  String get relativeCreatedTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'resource_id': resourceId,
      'resource_type': resourceType,
      'shared_by': sharedBy,
      'shared_by_username': sharedByUsername,
      'resource_title': resourceTitle,
      'permission': SharePermission.serializeSet(permissions),
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  factory GroupResource.fromMap(Map<String, dynamic> map) {
    return GroupResource(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      resourceId: map['resource_id']?.toString() ?? '',
      resourceType: map['resource_type']?.toString() ?? 'material',
      sharedBy: map['shared_by']?.toString() ?? '',
      sharedByUsername: map['shared_by_username'] as String?,
      resourceTitle: map['resource_title']?.toString() ?? 'Shared Resource',
      permissions: SharePermission.parseSet(map['permission'] as String?),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: map['expires_at'] != null ? DateTime.tryParse(map['expires_at'].toString()) : null,
    );
  }
}
