import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_item.dart';
import 'notification_service.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// סורק את המשימות הפתוחות ומעדכן את כמות המשימות הדחופות בהתראות
  Future<void> updateDueTasksNotification() async {
    try {
      // משיכת כל המשימות שעדיין לא הושלמו ממסד הנתונים
      final snapshot = await _db
          .collection('tasks')
          .where('isCompleted', isEqualTo: false)
          .get();

      int dueTasksCount = 0;
      final now = DateTime.now();

      // נגדיר "קרוב" כמשימה שפגת תוקף או שתאריך היעד שלה הוא עד 48 שעות מעכשיו
      final inTwoDays = now.add(const Duration(days: 2));

      for (var doc in snapshot.docs) {
        final task = TaskItem.fromMap(doc.id, doc.data());

        // אם יש תאריך יעד והוא לפני "עוד יומיים" (כולל משימות שכבר באיחור)
        if (task.dueDate != null && task.dueDate!.isBefore(inTwoDays)) {
          dueTasksCount++;
        }
      }

      // מעדכן את ההתראה עם המספר האמיתי
      await NotificationService().refreshDueDateReminder(dueTasksCount);
    } catch (e) {
      print('Error updating due tasks notification: $e');
    }
  }

  Future<bool> saveTask(TaskItem task) async {
    try {
      await _db.collection('tasks').doc(task.id).set(task.toMap());

      // עדכון התראת תאריכי היעד לאחר שמירת המשימה!
      await updateDueTasksNotification();

      return true;
    } catch (e) {
      print('Error saving task: $e');
      throw Exception('error saving task');
    }
  }

  /// Saves multiple tasks in a single write batch — one round trip and
  /// one local-cache snapshot event instead of one per task. Use this for
  /// reordering/sorting where many tasks change orderIndex at once.
  Future<bool> saveTasksBatch(List<TaskItem> tasks) async {
    if (tasks.isEmpty) return true;
    try {
      final batch = _db.batch();
      for (final task in tasks) {
        batch.set(_db.collection('tasks').doc(task.id), task.toMap());
      }
      await batch.commit();
      return true;
    } catch (e) {
      print('Error saving tasks batch: $e');
      throw Exception('error saving tasks batch');
    }
  }

  Stream<List<TaskItem>> streamTasks() {
    try {
      return _db
          .collection('tasks')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => TaskItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming tasks: $e');
      return const Stream.empty();
    }
  }

  /// מחיקת משימה
  Future<bool> deleteTask(String taskId) async {
    try {
      await _db.collection('tasks').doc(taskId).delete();

      // עדכון התראת תאריכי היעד לאחר מחיקת המשימה!
      await updateDueTasksNotification();

      return true;
    } catch (e) {
      print('Error deleting task: $e');
      throw Exception('task deletion faild');
    }
  }

  /// Deletes completed tasks ONLY if they were completed before today
  Future<void> clearCompletedTasks() async {
    try {
      final snapshot = await _db
          .collection('tasks')
          .where('isCompleted', isEqualTo: true)
          .get();

      final now = DateTime.now();
      // Creates a timestamp for today exactly at 00:00:00 (Midnight)
      final startOfToday = DateTime(now.year, now.month, now.day);

      final batch = _db.batch();
      var hasDeletes = false;

      for (var doc in snapshot.docs) {
        // Convert the raw Firebase data into our TaskItem object to read it easily
        final task = TaskItem.fromMap(doc.id, doc.data());

        if (task.completedAt != null &&
            task.completedAt!.isBefore(startOfToday)) {
          // If the task was completed before today started, delete it
          batch.delete(doc.reference);
          hasDeletes = true;
        } else if (task.completedAt == null) {
          // Fallback: If it's an old task from before we added this feature, delete it
          batch.delete(doc.reference);
          hasDeletes = true;
        }
      }

      if (hasDeletes) {
        await batch.commit();
      }
    } catch (e) {
      print('Error clearing completed tasks: $e');
    }
  }
}
