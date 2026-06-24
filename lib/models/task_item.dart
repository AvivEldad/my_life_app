class TaskItem {
  final String id;
  String title;
  String? description;
  DateTime? dueDate;
  int level;
  bool isCompleted;
  bool isGolden;
  String? categoryId;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.level = 1,
    this.isCompleted = false,
    this.isGolden = false,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'level': level,
      'isCompleted': isCompleted,
      'isGolden': isGolden,
      'categoryId': categoryId,
    };
  }

  factory TaskItem.fromMap(String id, Map<String, dynamic> map) {
    final dueDateMs = map['dueDate'] as int?;

    return TaskItem(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      dueDate: dueDateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dueDateMs)
          : null,
      level: (map['level'] as int?) ?? 1,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      isGolden: (map['isGolden'] as bool?) ?? false,
      categoryId: map['categoryId'] as String?,
    );
  }
}
