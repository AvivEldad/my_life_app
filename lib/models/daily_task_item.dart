class DailyTaskItem {
  final String id;
  String title;
  bool isCompleted;

  DailyTaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {'title': title, 'isCompleted': isCompleted};
  }

  factory DailyTaskItem.fromMap(String id, Map<String, dynamic> map) {
    return DailyTaskItem(
      id: id,
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}
