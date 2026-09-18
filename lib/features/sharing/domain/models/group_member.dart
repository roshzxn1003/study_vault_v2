/// Roles within a Study Group.
enum GroupRole {
  owner(key: 'owner', label: 'Owner'),
  moderator(key: 'moderator', label: 'Moderator'),
  member(key: 'member', label: 'Member');

  final String key;
  final String label;

  const GroupRole({required this.key, required this.label});

  static GroupRole fromString(String? val) {
    if (val == null) return GroupRole.member;
    switch (val.toLowerCase().trim()) {
      case 'owner':
        return GroupRole.owner;
      case 'moderator':
        return GroupRole.moderator;
      case 'member':
      default:
        return GroupRole.member;
    }
  }
}

/// Membership status of a user in a Study Group.
enum GroupMemberStatus {
  active(key: 'active', label: 'Active'),
  invited(key: 'invited', label: 'Invited'),
  declined(key: 'declined', label: 'Declined');

  final String key;
  final String label;

  const GroupMemberStatus({required this.key, required this.label});

  static GroupMemberStatus fromString(String? val) {
    if (val == null) return GroupMemberStatus.invited;
    switch (val.toLowerCase().trim()) {
      case 'active':
        return GroupMemberStatus.active;
      case 'declined':
        return GroupMemberStatus.declined;
      case 'invited':
      default:
        return GroupMemberStatus.invited;
    }
  }
}

/// Member representation in a Study Group.
class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String? username;
  final String? fullName;
  final GroupRole role;
  final GroupMemberStatus status;
  final DateTime createdAt;
  final DateTime? joinedAt;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    this.username,
    this.fullName,
    this.role = GroupRole.member,
    this.status = GroupMemberStatus.invited,
    required this.createdAt,
    this.joinedAt,
  });

  String get displayUsername => username != null ? '@${username!.replaceAll('@', '')}' : '@scholar';
  String get displayName => fullName?.isNotEmpty == true ? fullName! : displayUsername;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'username': username,
      'full_name': fullName,
      'role': role.key,
      'status': status.key,
      'created_at': createdAt.toIso8601String(),
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      username: map['username'] as String?,
      fullName: map['full_name'] as String?,
      role: GroupRole.fromString(map['role'] as String?),
      status: GroupMemberStatus.fromString(map['status'] as String?),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      joinedAt: map['joined_at'] != null ? DateTime.tryParse(map['joined_at'].toString()) : null,
    );
  }
}
