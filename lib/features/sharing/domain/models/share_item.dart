import 'share_permission.dart';
import 'share_status.dart';

/// Represents an individual or collective academic share between students.
class ShareItem {
  final String id;
  final String ownerId;
  final String? recipientId;
  final String resourceType; // 'material', 'folder', 'study_pack'
  final String resourceId;
  final Set<SharePermission> permissions;
  final ShareStatus status;
  final String? message;
  final String? ownerUsername;
  final String? ownerName;
  final String? recipientUsername;
  final String? recipientName;
  final String resourceTitle;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  const ShareItem({
    required this.id,
    required this.ownerId,
    this.recipientId,
    this.resourceType = 'material',
    required this.resourceId,
    this.permissions = const {SharePermission.view},
    this.status = ShareStatus.active,
    this.message,
    this.ownerUsername,
    this.ownerName,
    this.recipientUsername,
    this.recipientName,
    required this.resourceTitle,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
  });

  /// Whether this share has exceeded its configured expiry time.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this share is actively granting access right now.
  bool get isActive {
    if (revokedAt != null) return false;
    if (isExpired) return false;
    return status.isActive;
  }

  /// User-facing display status text.
  String get displayStatusText {
    if (revokedAt != null || status == ShareStatus.revoked) {
      return 'Access Revoked';
    }
    if (isExpired || status == ShareStatus.expired) {
      return 'Access Expired';
    }
    return status.displayName;
  }

  bool get isRevoked => status == ShareStatus.revoked || revokedAt != null;
  bool hasPermission(SharePermission p) => permissions.contains(p);
  bool get canDownload => permissions.contains(SharePermission.download);
  bool get canSaveCopy => permissions.contains(SharePermission.saveCopy);

  /// Humanized relative creation time.
  String get relativeCreatedTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Formatted expiry description.
  String get expiryDescription {
    if (expiresAt == null) return 'Never expires';
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) {
      return 'Expired';
    }
    final diff = expiresAt!.difference(now);
    if (diff.inHours < 1) return 'Expires in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Expires in ${diff.inHours}h';
    if (diff.inDays == 1) return 'Expires tomorrow';
    return 'Expires in ${diff.inDays} days';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'recipient_id': recipientId,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'permission': SharePermission.serializeSet(permissions),
      'status': isExpired ? ShareStatus.expired.key : (revokedAt != null ? ShareStatus.revoked.key : status.key),
      'message': message,
      'owner_username': ownerUsername,
      'owner_name': ownerName,
      'recipient_username': recipientUsername,
      'resource_title': resourceTitle,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
    };
  }

  factory ShareItem.fromMap(Map<String, dynamic> map) {
    final expiresAt = map['expires_at'] != null ? DateTime.tryParse(map['expires_at'].toString()) : null;
    final revokedAt = map['revoked_at'] != null ? DateTime.tryParse(map['revoked_at'].toString()) : null;
    var status = ShareStatus.fromString(map['status']?.toString());
    if (revokedAt != null) {
      status = ShareStatus.revoked;
    } else if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      status = ShareStatus.expired;
    }

    return ShareItem(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      recipientId: map['recipient_id']?.toString(),
      resourceType: map['resource_type']?.toString() ?? 'material',
      resourceId: map['resource_id']?.toString() ?? '',
      permissions: SharePermission.parseSet(map['permission']?.toString()),
      status: status,
      message: map['message']?.toString(),
      ownerUsername: map['owner_username']?.toString(),
      ownerName: map['owner_name']?.toString(),
      recipientUsername: map['recipient_username']?.toString(),
      recipientName: map['recipient_name']?.toString(),
      resourceTitle: map['resource_title']?.toString() ?? 'Academic Material',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: expiresAt,
      revokedAt: revokedAt,
    );
  }

  ShareItem copyWith({
    String? id,
    String? ownerId,
    String? recipientId,
    String? resourceType,
    String? resourceId,
    Set<SharePermission>? permissions,
    ShareStatus? status,
    String? message,
    String? ownerUsername,
    String? ownerName,
    String? recipientUsername,
    String? recipientName,
    String? resourceTitle,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
  }) {
    return ShareItem(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      recipientId: recipientId ?? this.recipientId,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      message: message ?? this.message,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      ownerName: ownerName ?? this.ownerName,
      recipientUsername: recipientUsername ?? this.recipientUsername,
      recipientName: recipientName ?? this.recipientName,
      resourceTitle: resourceTitle ?? this.resourceTitle,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }
}
