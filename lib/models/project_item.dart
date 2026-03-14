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
  double get progress => subtasks.isEmpty ? 0.0 : completedCount / subtasks.length;

  /// Index of the first subtask that is not yet completed.
  /// Returns -1 if all are done (or list is empty).
  int get activeSubtaskIndex {
    for (int i = 0; i < subtasks.length; i++) {
      if (!subtasks[i].isCompleted) return i;
    }
    return -1;
  }
}