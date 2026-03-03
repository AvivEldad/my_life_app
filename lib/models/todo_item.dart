class TodoItem {
  final String id;
  String title;
  String? description;
  DateTime? dueDate;
  int level;
  bool isCompleted;
  bool isGolden;

  TodoItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.level = 1,
    this.isCompleted = false,
    this.isGolden = false,
  });
}