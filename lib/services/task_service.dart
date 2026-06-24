import '../models/task_item.dart';

class TaskService {
  // מיון לפי רמה - לכל המשימות
  static List<TaskItem> sortByLevel(List<TaskItem> tasks) {
    List<TaskItem> sorted = List.from(tasks);
    sorted.sort((a, b) {
      // 1. קודם כל: משימות שהושלמו תמיד יורדות לסוף
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;

      // 2. משימות מוזהבות מקבלות עדיפות
      if (a.isGolden && !b.isGolden) return -1;
      if (!a.isGolden && b.isGolden) return 1;

      // 3. מיון לפי רמה
      return b.level.compareTo(a.level);
    });
    return sorted;
  }

  // מיון לפי תאריך - רק למשימות רגילות
  static List<TaskItem> sortByDueDate(List<TaskItem> tasks) {
    List<TaskItem> sorted = List.from(tasks);
    sorted.sort((a, b) {
      // 1. קודם כל: משימות שהושלמו תמיד יורדות לסוף
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;

      // 2. משימות מוזהבות מקבלות עדיפות
      if (a.isGolden && !b.isGolden) return -1;
      if (!a.isGolden && b.isGolden) return 1;

      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;

      return a.dueDate!.compareTo(b.dueDate!);
    });
    return sorted;
  }
}
