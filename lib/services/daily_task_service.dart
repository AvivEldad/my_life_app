import 'package:cloud_firestore/cloud_firestore.dart';
// ודא שיש לך קובץ daily_task_item.dart בתיקיית models עם המודל שיצרנו
import '../models/daily_task_item.dart';

class DailyTaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveDailyTask(DailyTaskItem dailyTask) async {
    try {
      await _db
          .collection('daily_tasks')
          .doc(dailyTask.id)
          .set(dailyTask.toMap());
      return true;
    } catch (e) {
      print('Error saving daily task: $e');
      throw Exception('שגיאה בשמירת המשימה היומית.');
    }
  }

  Stream<List<DailyTaskItem>> streamDailyTasks() {
    try {
      return _db
          .collection('daily_tasks')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => DailyTaskItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming daily tasks: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteDailyTask(String taskId) async {
    try {
      await _db.collection('daily_tasks').doc(taskId).delete();
      return true;
    } catch (e) {
      print('Error deleting daily task: $e');
      throw Exception('לא הצלחנו למחוק את המשימה היומית.');
    }
  }

  //delete all the tasks in daily list
  Future<bool> clearAllDailyTasks() async {
    try {
      final snapshot = await _db.collection('daily_tasks').get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      return true;
    } catch (e) {
      print('Error clearing daily tasks: $e');
      throw Exception('failed to delete daily list');
    }
  }
}
