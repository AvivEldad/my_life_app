import '../models/todo_item.dart';

class TaskService {
  // מיון לפי רמה - לכל המשימות
  static List<TodoItem> sortByLevel(List<TodoItem> tasks) {
    List<TodoItem> sorted = List.from(tasks);
    sorted.sort((a, b) {
      if (a.isGolden) return -1;
      if (b.isGolden) return 1;
      return b.level.compareTo(a.level);
    });
    return sorted;
  }

  // מיון לפי תאריך - רק למשימות רגילות
  static List<TodoItem> sortByDueDate(List<TodoItem> tasks) {
    List<TodoItem> sorted = List.from(tasks);
    sorted.sort((a, b) {
      if (a.isGolden) return -1;
      if (b.isGolden) return 1;

      bool aIsReg = a.recurrence == RecurrenceType.none;
      bool bIsReg = b.recurrence == RecurrenceType.none;

      if (!aIsReg && !bIsReg) return 0;
      if (!aIsReg) return 1;
      if (!bIsReg) return -1;

      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      
      int dateCompare = a.dueDate!.compareTo(b.dueDate!);
      // Tie-breaker: אם התאריך זהה, מיין לפי רמה
      if (dateCompare == 0) return b.level.compareTo(a.level);
      return dateCompare;
    });
    return sorted;
  }
}