class Flashcard {
  final String id;
  final String topicId;
  final String front;
  final String back;
  final String? sourceFile;
  final int? sourcePage;
  final DateTime nextReview;

  Flashcard({
    required this.id,
    required this.topicId,
    required this.front,
    required this.back,
    this.sourceFile,
    this.sourcePage,
    required this.nextReview,
  });

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'],
      topicId: map['topic_id'],
      front: map['front'],
      back: map['back'],
      sourceFile: map['source_file'],
      sourcePage: map['source_page'],
      nextReview: DateTime.parse(map['next_review']),
    );
  }
}
