import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import '../models/habit_item.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

class HabitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Action id for the "Snooze" button shown directly on a habit
  /// notification. Handled by habitNotificationBackgroundHandler below,
  /// which is wired up in main.dart and works whether the app is open,
  /// backgrounded, or fully closed.
  static const String kSnoozeActionId = 'snooze_habit';

  /// Deterministic, positive notification id derived from the habit's
  /// Firestore doc id. Offset so it never collides with the small
  /// hardcoded ids used elsewhere (coin reminder = 2, due-date = 3, ...).
  int _notificationIdFor(String habitId) =>
      (1000000 + habitId.hashCode.abs()) & 0x7fffffff;

  /// The action buttons a habit's notification should show. Only offers
  /// "Snooze" while snoozes remain for this occurrence.
  List<AndroidNotificationAction>? _actionsFor(HabitItem habit) {
    if (!habit.canSnooze) return null;
    return const [
      AndroidNotificationAction(
        kSnoozeActionId,
        'דחה ⏰',
        showsUserInterface: false,
      ),
    ];
  }

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

  /// Pushes [habit]'s reminder 30 minutes later (up to 2 times per
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
        payload: habit.id,
        actions: _actionsFor(habit),
      );
      return true;
    } catch (e) {
      print('Error snoozing habit: $e');
      throw Exception('error snoozing habit');
    }
  }

  /// Snoozes a habit by its Firestore doc id alone, without needing an
  /// in-memory HabitItem — used when the "Snooze" button on a notification
  /// is tapped (see habitNotificationBackgroundHandler below), where all we
  /// have is the habit id carried in the notification's payload.
  Future<bool> snoozeHabitById(String habitId) async {
    final doc = await _db.collection('habits').doc(habitId).get();
    final data = doc.data();
    if (data == null) return false;
    final habit = HabitItem.fromMap(habitId, data);
    return snoozeHabit(habit);
  }

  Future<void> _scheduleReminder(HabitItem habit) async {
    final id = _notificationIdFor(habit.id);
    final body = habit.description ?? '';
    final actions = _actionsFor(habit);
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
          payload: habit.id,
          actions: actions,
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
          payload: habit.id,
          actions: actions,
        );
        break;
      case HabitRecurrence.monthly:
        await _notificationService.scheduleOneShotNotification(
          id: id,
          title: habit.summary,
          body: body,
          dateTime: habit.nextDueDate,
          payload: habit.id,
          actions: actions,
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

/// Handles the "Snooze" button on a habit's notification. Registered as
/// both the foreground and background notification-response callback in
/// main.dart's NotificationService.init() call. Must stay a top-level
/// function (not a class method) and keep the @pragma('vm:entry-point')
/// annotation — Android invokes it in a fresh, standalone isolate when the
/// action is tapped while the app process isn't running, so it can't rely
/// on any state from the running app (hence re-initializing Firebase here
/// if needed, and creating a fresh HabitService instance).
@pragma('vm:entry-point')
void habitNotificationBackgroundHandler(NotificationResponse response) {
  _handleHabitNotificationResponse(response);
}

Future<void> _handleHabitNotificationResponse(
  NotificationResponse response,
) async {
  if (response.actionId != HabitService.kSnoozeActionId) return;
  final habitId = response.payload;
  if (habitId == null || habitId.isEmpty) return;

  try {
    if (Firebase.apps.isEmpty) {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await HabitService().snoozeHabitById(habitId);
  } catch (e) {
    debugPrint(
      'habitNotificationBackgroundHandler: failed to snooze habit $habitId: $e',
    );
  }
}
