import 'todo_item.dart';

class ProjectItem {
  String id;
  String title;
  String description;
  DateTime? dueDate;
  int level;
  List<TodoItem> subtasks;
  String? categoryId;

  ProjectItem({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.level = 1,
    List<TodoItem>? subtasks,
    this.categoryId,
  }) : subtasks = subtasks ?? [];

  int get completedCount => subtasks.where((t) => t.isCompleted).length;
  double get progress =>
      subtasks.isEmpty ? 0.0 : completedCount / subtasks.length;

  int get activeSubtaskIndex {
    for (int i = 0; i < subtasks.length; i++) {
      if (!subtasks[i].isCompleted) return i;
    }
    return -1;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'level': level,
      'categoryId': categoryId,
      'subtasks': subtasks.map((s) => {'id': s.id, ...s.toMap()}).toList(),
    };
  }

  factory ProjectItem.fromMap(String id, Map<String, dynamic> map) {
    final rawSubtasks = (map['subtasks'] as List<dynamic>?) ?? [];
    final subtasks = rawSubtasks.map((s) {
      final sMap = Map<String, dynamic>.from(s as Map);
      final sid = sMap.remove('id') as String? ??
          DateTime.now().millisecondsSinceEpoch.toString();
      return TodoItem.fromMap(sid, sMap);
    }).toList();

    return ProjectItem(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : null,
      level: (map['level'] as int?) ?? 1,
      subtasks: subtasks,
      categoryId: map['categoryId'] as String?,
    );
  }
}