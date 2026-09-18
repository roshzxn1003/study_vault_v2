/// Public student identity in Study Vault.
/// Protects private student records while facilitating peer discovery and collaboration.
class StudentProfile {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? institution;
  final String? degree;
  final String? branch;
  final String? semester;
  final bool isSearchable;
  final String allowGroupInvites;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentProfile({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.institution,
    this.degree,
    this.branch,
    this.semester,
    this.isSearchable = true,
    this.allowGroupInvites = 'anyone',
    this.createdAt,
    this.updatedAt,
  });

  /// Canonical formatted username with leading '@'.
  String get displayUsername {
    final clean = username.trim().replaceAll('@', '');
    return '@$clean';
  }

  /// Initial letter for fallback avatar.
  String get initial {
    if (fullName.trim().isNotEmpty) return fullName.trim()[0].toUpperCase();
    if (username.trim().isNotEmpty) return username.trim().replaceAll('@', '')[0].toUpperCase();
    return 'S';
  }

  /// Clean public academic summary (e.g. "CSE • Semester 3" or "B.Tech CSE").
  String get publicAcademicSummary {
    final parts = <String>[];
    if (branch != null && branch!.isNotEmpty) {
      parts.add(branch!);
    } else if (degree != null && degree!.isNotEmpty) {
      parts.add(degree!);
    }
    if (semester != null && semester!.isNotEmpty) {
      parts.add(semester!);
    }
    if (institution != null && institution!.isNotEmpty && parts.isEmpty) {
      parts.add(institution!);
    }
    return parts.join(' • ');
  }

  /// Safe QR discovery payload string. Never exposes email, password, or sensitive tokens.
  String toQrPayload() {
    final cleanUsername = username.replaceAll('@', '');
    return 'studyvault://user/$cleanUsername?id=$id&name=${Uri.encodeComponent(fullName)}';
  }

  /// Parses safe QR discovery payload.
  static Map<String, String>? parseQrPayload(String raw) {
    if (!raw.startsWith('studyvault://user/')) return null;
    try {
      final uri = Uri.parse(raw);
      final cleanUsername = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final id = uri.queryParameters['id'] ?? '';
      final name = uri.queryParameters['name'] ?? cleanUsername;
      return {
        'id': id,
        'username': cleanUsername,
        'fullName': Uri.decodeComponent(name),
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username.replaceAll('@', '').toLowerCase(),
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'institution': institution,
      'degree': degree,
      'branch': branch,
      'semester': semester,
      'is_searchable': isSearchable ? 1 : 0,
      'allow_group_invites': allowGroupInvites,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory StudentProfile.fromMap(Map<String, dynamic> map) {
    final rawUsername = (map['username'] as String?)?.trim() ?? '';
    final username = rawUsername.isNotEmpty ? rawUsername : 'student_${map['id']?.toString().substring(0, 6) ?? 'user'}';

    return StudentProfile(
      id: map['id']?.toString() ?? '',
      username: username,
      fullName: (map['full_name'] as String?)?.trim() ?? 'Scholar',
      avatarUrl: map['avatar_url'] as String?,
      institution: map['institution'] as String?,
      degree: map['degree'] as String?,
      branch: map['branch'] as String?,
      semester: map['semester'] as String?,
      isSearchable: map['is_searchable'] is bool
          ? map['is_searchable'] as bool
          : (map['is_searchable'] as num?)?.toInt() != 0,
      allowGroupInvites: (map['allow_group_invites'] as String?) ?? 'anyone',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  StudentProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? institution,
    String? degree,
    String? branch,
    String? semester,
    bool? isSearchable,
    String? allowGroupInvites,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      institution: institution ?? this.institution,
      degree: degree ?? this.degree,
      branch: branch ?? this.branch,
      semester: semester ?? this.semester,
      isSearchable: isSearchable ?? this.isSearchable,
      allowGroupInvites: allowGroupInvites ?? this.allowGroupInvites,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
