import 'package:study_vault/features/academic/domain/models/academic_subject_entity.dart';

/// Wraps an academic subject with its real material count for dashboard presentation.
class SubjectWithCount {
  final AcademicSubjectEntity subject;
  final int materialCount;

  const SubjectWithCount({
    required this.subject,
    this.materialCount = 0,
  });

  /// Displays clear, non-statistic count text adhering to Phase 5 specs.
  String get materialCountLabel {
    if (materialCount == 0) {
      return 'No materials yet';
    } else if (materialCount == 1) {
      return '1 material';
    } else {
      return '$materialCount materials';
    }
  }

  SubjectWithCount copyWith({
    AcademicSubjectEntity? subject,
    int? materialCount,
  }) {
    return SubjectWithCount(
      subject: subject ?? this.subject,
      materialCount: materialCount ?? this.materialCount,
    );
  }
}

/// Represents a recently accessed or added academic material for the dashboard preview.
class DashboardRecentMaterial {
  final String id;
  final String title;
  final String type; // 'PDF', 'Note', 'Image', etc.
  final String? subjectName;
  final DateTime createdAt;

  const DashboardRecentMaterial({
    required this.id,
    required this.title,
    required this.type,
    this.subjectName,
    required this.createdAt,
  });

  /// Formatted relative timestamp (e.g., '2h ago', '3d ago').
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Combined subtitle, e.g. "PDF • Operating Systems • 2h ago"
  String get formattedSubtitle {
    final parts = <String>[type.toUpperCase()];
    if (subjectName != null && subjectName!.trim().isNotEmpty) {
      parts.add(subjectName!.trim());
    }
    parts.add(relativeTime);
    return parts.join(' • ');
  }
}

/// Preview representation of an unorganized/pending material in the Inbox.
class DashboardInboxItem {
  final String id;
  final String title;
  final String type;
  final DateTime createdAt;

  const DashboardInboxItem({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
  });

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
