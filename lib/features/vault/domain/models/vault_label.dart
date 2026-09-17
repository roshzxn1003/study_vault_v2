import 'package:flutter/material.dart';

/// Represents a user or system tag that can be attached to materials.
/// Enforces many-to-many relational tagging separate from physical folder hierarchies.
class VaultLabel {
  final String id;
  final String userId;
  final String? workspaceId;
  final String name;
  final String? colorHex;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const VaultLabel({
    required this.id,
    required this.userId,
    this.workspaceId,
    required this.name,
    this.colorHex,
    required this.createdAt,
    this.updatedAt,
  });

  /// Resolves the label color, defaulting to an academic palette when none provided.
  Color get color {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        final hex = colorHex!.replaceAll('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      } catch (_) {}
    }
    return const Color(0xFF6366F1); // Indigo default
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'workspace_id': workspaceId,
      'name': name,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toIso8601String(),
    };
  }

  factory VaultLabel.fromMap(Map<String, dynamic> map) {
    return VaultLabel(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? 'guest',
      workspaceId: map['workspace_id'] as String?,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
    );
  }

  VaultLabel copyWith({
    String? id,
    String? userId,
    String? workspaceId,
    String? name,
    String? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultLabel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultLabel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
