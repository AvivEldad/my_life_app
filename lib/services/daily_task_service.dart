import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_task_item.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

class DailyTaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _hasCheckedMidnightReset = false;
  static Future<void> _reminderRefresh = Future<void>.value();

  Future<void> refreshReminder() {
    final refresh = _reminderRefresh
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (!(prefs.getBool('isDailyListReminderEnabled') ?? false)) {
            await NotificationService().refreshDailyListReminder(false);
            return;
          }
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          final end = DateTime(now.year, now.month, now.day + 1);
          final snapshot = await _db
              .collection('daily_tasks')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: start.millisecondsSinceEpoch,
              )
              .where('createdAt', isLessThan: end.millisecondsSinceEpoch)
              .get();
          final hasPending = snapshot.docs.any(
            (doc) => doc.data()['isCompleted'] != true,
          );
          await NotificationService().refreshDailyListReminder(hasPending);
        })
        .catchError((Object error) {
          print('Error refreshing daily list reminder: $error');
        });
    _reminderRefresh = refresh;
    return refresh;
  }

  // This is called when the page opens to process old tasks and grant rewards
  Future<void> processMidnightReset(
    GamificationService gamificationService,
  ) async {
    if (_hasCheckedMidnightReset) return; // Only run once per session
    _hasCheckedMidnightReset = true;

    final now = DateTime.now();
    // Midnight of the current day
    final startOfToday = DateTime(now.year, now.month, now.day);

    try {
      final snapshot = await _db.collection('daily_tasks').get();
      int completedOldTasks = 0;
      WriteBatch batch = _db.batch();

      for (var doc in snapshot.docs) {
        final task = DailyTaskItem.fromMap(doc.id, doc.data());

        // If the task was created before 00:00 today, it belongs to a previous day
        if (task.createdAt.isBefore(startOfToday)) {
          if (task.isCompleted) {
            completedOldTasks++;
          }
          batch.delete(doc.reference); // Delete it regardless of completion
        }
      }

      // Grant rewards if any were completed
      if (completedOldTasks > 0) {
        double coinsReward = completedOldTasks * 0.5;
        int xpReward = completedOldTasks * 3;
        await gamificationService.addDailyRewards(coinsReward, xpReward);
      }

      await batch.commit(); // Execute all deletions at once
      await refreshReminder();
    } catch (e) {
      print('Error processing midnight reset: $e');
    }
  }

  // Splits multi-line text and saves each as a separate task
  Future<void> saveMultipleTasks(String multiLineText) async {
    final lines = multiLineText.split('\n');
    WriteBatch batch = _db.batch();

    for (String line in lines) {
      if (line.trim().isEmpty) continue; // Skip empty lines

      final docRef = _db.collection('daily_tasks').doc();
      final task = DailyTaskItem(id: docRef.id, summary: line.trim());
      batch.set(docRef, task.toMap());
    }

    await batch.commit();
    await refreshReminder();
  }

  Future<void> toggleTaskCompletion(DailyTaskItem task) async {
    task.isCompleted = !task.isCompleted;
    await _db.collection('daily_tasks').doc(task.id).update({
      'isCompleted': task.isCompleted,
    });
    await refreshReminder();
  }

  Future<void> deleteSingleTask(String id) async {
    await _db.collection('daily_tasks').doc(id).delete();
    await refreshReminder();
  }

  // Only streams tasks created from today's midnight onwards
  Stream<List<DailyTaskItem>> streamTodayTasks() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return _db
        .collection('daily_tasks')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: startOfToday.millisecondsSinceEpoch,
        )
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => DailyTaskItem.fromMap(doc.id, doc.data()))
              .toList();
        });
  }
}
