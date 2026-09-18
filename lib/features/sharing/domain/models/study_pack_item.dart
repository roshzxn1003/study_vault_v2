/// Individual item inside a curated Study Pack.
class StudyPackItem {
  final String id;
  final String studyPackId;
  final String materialId;
  final String materialTitle;
  final String materialType; // 'PDF', 'IMAGE', 'NOTE', etc.
  final int orderIndex;

  const StudyPackItem({
    required this.id,
    required this.studyPackId,
    required this.materialId,
    required this.materialTitle,
    this.materialType = 'PDF',
    this.orderIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'study_pack_id': studyPackId,
      'material_id': materialId,
      'material_title': materialTitle,
      'material_type': materialType,
      'order_index': orderIndex,
    };
  }

  factory StudyPackItem.fromMap(Map<String, dynamic> map) {
    return StudyPackItem(
      id: map['id']?.toString() ?? '',
      studyPackId: map['study_pack_id']?.toString() ?? '',
      materialId: map['material_id']?.toString() ?? '',
      materialTitle: map['material_title']?.toString() ?? 'Material',
      materialType: map['material_type']?.toString() ?? 'PDF',
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
    );
  }
}
