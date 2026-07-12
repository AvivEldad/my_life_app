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
}
