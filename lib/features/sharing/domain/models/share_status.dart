import 'package:flutter/material.dart';

/// Lifecycle status of a student share.
enum ShareStatus {
  pending(
    key: 'pending',
    displayName: 'Pending',
    color: Color(0xFFF59E0B),
    icon: Icons.hourglass_top_rounded,
  ),
  accepted(
    key: 'accepted',
    displayName: 'Accepted',
    color: Color(0xFF10B981),
    icon: Icons.check_circle_outline_rounded,
  ),
  active(
    key: 'active',
    displayName: 'Active',
    color: Color(0xFF10B981),
    icon: Icons.lock_open_rounded,
  ),
  expired(
    key: 'expired',
    displayName: 'Access Expired',
    color: Color(0xFF94A3B8),
    icon: Icons.timer_off_outlined,
  ),
  revoked(
    key: 'revoked',
    displayName: 'Access Revoked',
    color: Color(0xFFEF4444),
    icon: Icons.block_outlined,
  );

  final String key;
  final String displayName;
  final Color color;
  final IconData icon;

  const ShareStatus({
    required this.key,
    required this.displayName,
    required this.color,
    required this.icon,
  });

  bool get isActive => this == ShareStatus.active || this == ShareStatus.accepted;

  static ShareStatus fromString(String? raw) {
    if (raw == null) return ShareStatus.active;
    final lower = raw.trim().toLowerCase();
    switch (lower) {
      case 'pending':
        return ShareStatus.pending;
      case 'accepted':
        return ShareStatus.accepted;
      case 'expired':
        return ShareStatus.expired;
      case 'revoked':
        return ShareStatus.revoked;
      case 'active':
      default:
        return ShareStatus.active;
    }
  }
}
