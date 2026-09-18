import 'package:flutter/material.dart';

/// Supported permissions when sharing academic materials or packs with other students.
enum SharePermission {
  view(
    key: 'view',
    label: 'View',
    description: 'Can preview and read material in app',
    icon: Icons.visibility_outlined,
  ),
  download(
    key: 'download',
    label: 'Download',
    description: 'Can download original document or file',
    icon: Icons.download_outlined,
  ),
  saveCopy(
    key: 'save_copy',
    label: 'Save a Copy',
    description: 'Can copy material into personal Vault',
    icon: Icons.save_alt_rounded,
  );

  final String key;
  final String label;
  final String description;
  final IconData icon;

  const SharePermission({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
  });

  static SharePermission fromString(String? val) {
    if (val == null) return SharePermission.view;
    final lower = val.trim().toLowerCase();
    if (lower.contains('save') || lower == 'save_copy') return SharePermission.saveCopy;
    if (lower.contains('down') || lower == 'download') return SharePermission.download;
    return SharePermission.view;
  }

  /// Serializes a set of permissions into a stored database string (e.g. 'view,download,save_copy').
  static String serializeSet(Set<SharePermission> perms) {
    if (perms.isEmpty) return 'view';
    return perms.map((p) => p.key).toSet().join(',');
  }

  /// Parses a stored database string into a set of permissions.
  static Set<SharePermission> parseSet(String? raw) {
    final result = <SharePermission>{SharePermission.view};
    if (raw == null || raw.trim().isEmpty) return result;
    final tokens = raw.split(',').map((e) => e.trim().toLowerCase());
    for (final token in tokens) {
      if (token == 'download') result.add(SharePermission.download);
      if (token == 'save_copy' || token == 'savecopy') result.add(SharePermission.saveCopy);
    }
    return result;
  }
}
