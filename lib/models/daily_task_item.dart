class DailyTaskItem {
  final String id;
  final String summary;
  bool isCompleted;
  final DateTime createdAt;

  DailyTaskItem({
    required this.id,
    required this.summary,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'isCompleted': isCompleted,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DailyTaskItem.fromMap(String id, Map<String, dynamic> map) {
    return DailyTaskItem(
      id: id,
      summary: map['summary'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}
