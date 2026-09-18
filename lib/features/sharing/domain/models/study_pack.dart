import 'study_pack_item.dart';

/// Curated collection of materials created for peer study and review.
class StudyPack {
  final String id;
  final String ownerId;
  final String? ownerUsername;
  final String name;
  final String? description;
  final int itemCount;
  final List<StudyPackItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyPack({
    required this.id,
    required this.ownerId,
    this.ownerUsername,
    required this.name,
    this.description,
    this.itemCount = 0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool isOwner(String userId) => ownerId == userId;

  String get displayOwner => ownerUsername != null ? '@${ownerUsername!.replaceAll('@', '')}' : 'Scholar';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_username': ownerUsername,
      'name': name,
      'description': description,
      'item_count': items.isNotEmpty ? items.length : itemCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyPack.fromMap(Map<String, dynamic> map, {List<StudyPackItem> items = const []}) {
    final count = (map['item_count'] as num?)?.toInt() ?? items.length;
    return StudyPack(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      ownerUsername: map['owner_username'] as String?,
      name: (map['name'] as String?)?.trim() ?? 'Untitled Study Pack',
      description: map['description'] as String?,
      itemCount: items.isNotEmpty ? items.length : count,
      items: items,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  StudyPack copyWith({
    String? id,
    String? ownerId,
    String? ownerUsername,
    String? name,
    String? description,
    int? itemCount,
    List<StudyPackItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyPack(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      name: name ?? this.name,
      description: description ?? this.description,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
