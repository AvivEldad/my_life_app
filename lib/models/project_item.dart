import 'task_item.dart';

class ProjectItem {
  final String id;
  String title;
  String description;
  DateTime? dueDate;
  int level;
  String? categoryId;
  List<TaskItem> subtasks;
  bool isSequential;

  ProjectItem({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.level = 1,
    this.categoryId,
    List<TaskItem>? subtasks,
    this.isSequential = false,
  }) : subtasks = subtasks ?? [];

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'level': level,
      'categoryId': categoryId,
      'subtasks': subtasks.map((e) => e.toMap()).toList(),
      'isSequential': isSequential,
    };
  }

  factory ProjectItem.fromMap(String id, Map<String, dynamic> map) {
    final subtasksList = map['subtasks'] as List<dynamic>?;
    return ProjectItem(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
          : null,
      level: map['level'] as int? ?? 1,
      categoryId: map['categoryId'] as String?,
      subtasks: subtasksList != null
          ? subtasksList.map((e) => TaskItem.fromMap('', e)).toList()
          : [],
      isSequential: map['isSequential'] as bool? ?? false,
    );
  }
}
