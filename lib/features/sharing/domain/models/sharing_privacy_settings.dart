/// Student Privacy & Sharing Configuration.
class SharingPrivacySettings {
  final bool isSearchable; // true: anyone can search by @username; false: hidden from public discovery
  final String allowGroupInvites; // 'anyone' or 'nobody'

  const SharingPrivacySettings({
    this.isSearchable = true,
    this.allowGroupInvites = 'anyone',
  });

  bool get allowsInvitesFromAnyone => allowGroupInvites == 'anyone';

  Map<String, dynamic> toMap() {
    return {
      'is_searchable': isSearchable ? 1 : 0,
      'allow_group_invites': allowGroupInvites,
    };
  }

  factory SharingPrivacySettings.fromMap(Map<String, dynamic> map) {
    return SharingPrivacySettings(
      isSearchable: map['is_searchable'] is bool
          ? map['is_searchable'] as bool
          : (map['is_searchable'] as num?)?.toInt() != 0,
      allowGroupInvites: (map['allow_group_invites'] as String?) ?? 'anyone',
    );
  }

  SharingPrivacySettings copyWith({
    bool? isSearchable,
    String? allowGroupInvites,
  }) {
    return SharingPrivacySettings(
      isSearchable: isSearchable ?? this.isSearchable,
      allowGroupInvites: allowGroupInvites ?? this.allowGroupInvites,
    );
  }
}
