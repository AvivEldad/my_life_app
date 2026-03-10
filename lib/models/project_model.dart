import 'todo_item.dart';

class Project {
  final String id;
  String title;
  String? description;
  DateTime? dueDate;
  List<TodoItem> subTasks;

  Project({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    List<TodoItem>? subTasks,
  }) : subTasks = subTasks ?? [];

  // פונקציית עזר להחזרת המשימה הפעילה (הראשונה שלא בוצעה)
  TodoItem? get nextActiveTask {
    return subTasks.firstWhere((task) => !task.isCompleted, orElse: () => subTasks.last);
  }
}