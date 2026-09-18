import 'package:flutter/material.dart';

/// Notification events for student sharing and collaboration.
enum ShareNotificationType {
  materialShared(
    key: 'material_shared',
    label: 'Material Shared',
    icon: Icons.share_rounded,
    color: Color(0xFF3B82F6),
  ),
  packShared(
    key: 'pack_shared',
    label: 'Study Pack Shared',
    icon: Icons.folder_zip_outlined,
    color: Color(0xFF8B5CF6),
  ),
  groupInvitation(
    key: 'group_invitation',
    label: 'Group Invitation',
    icon: Icons.group_add_outlined,
    color: Color(0xFFF59E0B),
  ),
  groupAccepted(
    key: 'group_accepted',
    label: 'Invitation Accepted',
    icon: Icons.how_to_reg_outlined,
    color: Color(0xFF10B981),
  ),
  shareExpiring(
    key: 'share_expiring',
    label: 'Share Expiring Soon',
    icon: Icons.access_time_rounded,
    color: Color(0xFFF97316),
  ),
  shareExpired(
    key: 'share_expired',
    label: 'Share Expired',
    icon: Icons.timer_off_outlined,
    color: Color(0xFF94A3B8),
  );

  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const ShareNotificationType({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  static ShareNotificationType fromString(String? val) {
    if (val == null) return ShareNotificationType.materialShared;
    switch (val.toLowerCase().trim()) {
      case 'pack_shared':
        return ShareNotificationType.packShared;
      case 'group_invitation':
        return ShareNotificationType.groupInvitation;
      case 'group_accepted':
        return ShareNotificationType.groupAccepted;
      case 'share_expiring':
        return ShareNotificationType.shareExpiring;
      case 'share_expired':
        return ShareNotificationType.shareExpired;
      case 'material_shared':
      default:
        return ShareNotificationType.materialShared;
    }
  }
}

/// In-app notification for sharing activities.
class ShareNotification {
  final String id;
  final String userId;
  final ShareNotificationType type;
  final String title;
  final String message;
  final String? referenceId;
  final String? referenceType; // 'material', 'study_pack', 'study_group'
  final bool isRead;
  final DateTime createdAt;

  const ShareNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.referenceId,
    this.referenceType,
    this.isRead = false,
    required this.createdAt,
  });

  String get relativeTime {
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
      'user_id': userId,
      'type': type.key,
      'title': title,
      'message': message,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ShareNotification.fromMap(Map<String, dynamic> map) {
    return ShareNotification(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: ShareNotificationType.fromString(map['type'] as String?),
      title: map['title'] as String? ?? 'Notification',
      message: map['message'] as String? ?? '',
      referenceId: map['reference_id'] as String?,
      referenceType: map['reference_type'] as String?,
      isRead: (map['is_read'] is bool)
          ? map['is_read'] as bool
          : (map['is_read'] as num?)?.toInt() == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  ShareNotification copyWith({
    String? id,
    String? userId,
    ShareNotificationType? type,
    String? title,
    String? message,
    String? referenceId,
    String? referenceType,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ShareNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
