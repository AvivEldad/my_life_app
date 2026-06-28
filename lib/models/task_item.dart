class SubTask {
  final String id;
  String title;
  bool isCompleted;

  SubTask({required this.id, required this.title, this.isCompleted = false});

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'isCompleted': isCompleted};
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}

class TaskItem {
  final String id;
  String title;
  String? description;
  DateTime? dueDate;
  int level;
  bool isCompleted;
  bool isGolden;
  String? categoryId;
  bool isActive;
  List<SubTask> subTasks;
  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.level = 1,
    this.isCompleted = false,
    this.isGolden = false,
    this.categoryId,
    this.isActive = false,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [];
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'level': level,
      'isCompleted': isCompleted,
      'isGolden': isGolden,
      'categoryId': categoryId,
      'isActive': isActive,
      'subTasks': subTasks
          .map((e) => e.toMap())
          .toList(), // שומר את כל תתי-המשימות
    };
  }

  factory TaskItem.fromMap(String id, Map<String, dynamic> map) {
    final dueDateMs = map['dueDate'] as int?;
    final subTasksList = map['subTasks'] as List<dynamic>?;

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
      isActive: (map['isActive'] as bool?) ?? false,
      subTasks: subTasksList != null
          ? subTasksList
                .map((e) => SubTask.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
    );
  }
}
