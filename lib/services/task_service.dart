import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_item.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveTask(TaskItem task) async {
    try {
      await _db.collection('tasks').doc(task.id).set(task.toMap());
      return true;
    } catch (e) {
      print('Error saving task: $e');
      throw Exception('error saving task');
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

      for (var doc in snapshot.docs) {
        // Convert the raw Firebase data into our TaskItem object to read it easily
        final task = TaskItem.fromMap(doc.id, doc.data());

        if (task.completedAt != null &&
            task.completedAt!.isBefore(startOfToday)) {
          // If the task was completed before today started, delete it
          await doc.reference.delete();
        } else if (task.completedAt == null) {
          // Fallback: If it's an old task from before we added this feature, delete it
          await doc.reference.delete();
        }
      }
    } catch (e) {
      print('Error clearing completed tasks: $e');
    }
  }
}
