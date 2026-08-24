class IdeaItem {
  final String id;
  String summary;
  String description;
  DateTime createdAt;
  int orderIndex; // השדה החדש ששומר את סדר התצוגה

  IdeaItem({
    required this.id,
    required this.summary,
    required this.description,
    DateTime? createdAt,
    this.orderIndex = 0, // ברירת מחדל
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'orderIndex': orderIndex,
    };
  }

  factory IdeaItem.fromMap(String id, Map<String, dynamic> map) {
    return IdeaItem(
      id: id,
      summary: map['summary'] ?? '',
      description: map['description'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      orderIndex: map['orderIndex'] ?? 0,
    );
  }
}
