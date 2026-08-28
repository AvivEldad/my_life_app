import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit_item.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

class HabitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Deterministic, positive notification id derived from the habit's
  /// Firestore doc id. Offset so it never collides with the small
  /// hardcoded ids used elsewhere (coin reminder = 2, due-date = 3, ...).
  int _notificationIdFor(String habitId) =>
      (1000000 + habitId.hashCode.abs()) & 0x7fffffff;

  Future<bool> saveHabit(HabitItem habit) async {
    try {
      await _db.collection('habits').doc(habit.id).set(habit.toMap());
      await _scheduleReminder(habit);
      return true;
    } catch (e) {
      print('Error saving habit: $e');
      throw Exception('error saving habit');
    }
  }

  Stream<List<HabitItem>> streamHabits() {
    try {
      return _db
          .collection('habits')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => HabitItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming habits: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteHabit(String habitId) async {
    try {
      await _db.collection('habits').doc(habitId).delete();
      await _notificationService.cancelNotification(
        _notificationIdFor(habitId),
      );
      return true;
    } catch (e) {
      print('Error deleting habit: $e');
      throw Exception('habit deletion failed');
    }
  }

  /// Marks [habit] done for its current occurrence, persists the updated
  /// streak/nextDueDate, and reschedules its reminder. Coin/XP reward is
  /// the caller's job (it needs GamificationService) — see HabitsPage.
  Future<bool> markHabitDone(HabitItem habit) async {
    habit.markDone();
    return saveHabit(habit);
  }

  /// Pushes [habit]'s reminder 30 hours later (up to 2 times per
  /// occurrence — see HabitItem.canSnooze). Snoozing only delays the
  /// notification; it does not move back the eventual miss penalty check,
  /// which uses HabitItem.effectiveDeadline (nextDueDate + any snoozes).
  Future<bool> snoozeHabit(HabitItem habit) async {
    if (!habit.canSnooze) return false;
    habit.snooze();
    try {
      await _db.collection('habits').doc(habit.id).update(habit.toMap());
      final id = _notificationIdFor(habit.id);
      await _notificationService.cancelNotification(id);
      await _notificationService.scheduleOneShotNotification(
        id: id,
        title: habit.summary,
        body: habit.description ?? '',
        dateTime: habit.snoozedUntil!,
      );
      return true;
    } catch (e) {
      print('Error snoozing habit: $e');
      throw Exception('error snoozing habit');
    }
  }

  Future<void> _scheduleReminder(HabitItem habit) async {
    final id = _notificationIdFor(habit.id);
    final body = habit.description ?? '';
    switch (habit.recurrence) {
      case HabitRecurrence.daily:
        await _notificationService.scheduleDailyNotification(
          id: id,
          title: habit.summary,
          body: body,
          hour: habit.reminderTime.hour,
          minute: habit.reminderTime.minute,
          channelId: 'habit_reminders',
          channelName: 'Habit Reminders',
          channelDescription: 'Reminders for daily habits',
        );
        break;
      case HabitRecurrence.weekly:
        await _notificationService.scheduleWeeklyNotification(
          id: id,
          title: habit.summary,
          body: body,
          weekday: habit.weekday ?? DateTime.monday,
          hour: habit.reminderTime.hour,
          minute: habit.reminderTime.minute,
        );
        break;
      case HabitRecurrence.monthly:
        await _notificationService.scheduleOneShotNotification(
          id: id,
          title: habit.summary,
          body: body,
          dateTime: habit.nextDueDate,
        );
        break;
    }
  }

  /// Call this once when the habits list loads (e.g. in
  /// HabitsPage.initState). For every habit whose effectiveDeadline
  /// (nextDueDate, pushed back by any snoozes) has passed without being
  /// marked done, this applies the coin/XP miss penalty via
  /// [gamificationService], breaks the streak, and advances the habit to
  /// its next occurrence — looping per habit in case more than one
  /// occurrence was missed while the app was closed (e.g. several days of
  /// a daily habit). This also covers monthly habits' one-shot reminders,
  /// which otherwise would never get their next notification scheduled.
  Future<void> processDueAndMissedHabits(
    List<HabitItem> habits,
    GamificationService gamificationService,
  ) async {
    final now = DateTime.now();
    for (final habit in habits) {
      var missed = false;
      while (now.isAfter(habit.effectiveDeadline)) {
        missed = true;
        habit.markMissed();
        await gamificationService.processHabitMiss();
      }
      if (missed) {
        await saveHabit(habit);
      }
    }
  }
}
