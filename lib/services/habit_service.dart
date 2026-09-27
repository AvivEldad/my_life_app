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
  final FirebaseFirestore _db;
  final NotificationService _notificationService = NotificationService();

  HabitService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Action id for the "Snooze" button shown directly on a habit
  /// notification. The app-level response handler delegates this action to
  /// habitNotificationBackgroundHandler below, which also handles it from a
  /// background isolate when the app is closed.
  static const String kSnoozeActionId = 'snooze_habit';

  /// Deterministic, positive notification id derived from the habit's
  /// Firestore doc id. Offset so it never collides with the small
  /// hardcoded ids used elsewhere (coin reminder = 2, due-date = 3, ...).
  static int notificationIdFor(String habitId) {
    var hash = 2166136261;
    for (final unit in habitId.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    // Reserve 64 IDs per habit for upcoming occurrences and a separate
    // high range for snoozes. No ID can overlap the app's fixed reminders.
    return 1000000 + (hash % ((0x40000000 - 1000000) ~/ 64)) * 64;
  }

  Future<void> _cancelReminders(String habitId) async {
    for (var slot = 0; slot < 30; slot++) {
      await _notificationService.cancelNotification(
        notificationIdFor(habitId) + slot,
      );
    }
    await _notificationService.cancelNotification(
      notificationIdFor(habitId) + 0x40000000,
    );
    // Remove notifications created before stable IDs were introduced.
    await _notificationService.cancelNotification(
      (1000000 + habitId.hashCode.abs()) & 0x7fffffff,
    );
    await _notificationService.cancelNotificationsForPayload(
      '${NotificationService.habitsPayloadPrefix}$habitId',
    );
    await _notificationService.cancelNotificationsForPayload(habitId);
  }

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
      await refreshReminder(habit);
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
      await _cancelReminders(habitId);
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
      await refreshReminder(habit);
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

  Future<void> refreshAllReminders() async {
    try {
      final snapshot = await _db.collection('habits').get();
      for (final doc in snapshot.docs) {
        await refreshReminder(HabitItem.fromMap(doc.id, doc.data()));
      }
    } catch (error) {
      debugPrint('Error refreshing habit reminders: $error');
    }
  }

  Future<void> refreshReminder(HabitItem habit) async {
    final id = notificationIdFor(habit.id);
    final body = habit.description ?? '';
    final actions = _actionsFor(habit);
    await _cancelReminders(habit.id);
    var firstOccurrence = habit.nextDueDate;
    if (habit.snoozedUntil != null) {
      if (habit.snoozedUntil!.isAfter(DateTime.now())) {
        await _notificationService.scheduleOneShotNotification(
          id: id + 0x40000000,
          title: habit.summary,
          body: body,
          dateTime: habit.snoozedUntil!,
          payload: '${NotificationService.habitsPayloadPrefix}${habit.id}',
          actions: actions,
        );
      }
      // Keep the normal recurrence alive independently of this snooze.
      do {
        firstOccurrence = habit.computeNextOccurrenceAfter(firstOccurrence);
      } while (!firstOccurrence.isAfter(habit.snoozedUntil!));
    }
    while (!firstOccurrence.isAfter(DateTime.now())) {
      firstOccurrence = habit.computeNextOccurrenceAfter(firstOccurrence);
    }
    // Android's repeating time matching ignores the supplied start date.
    // Explicit occurrences prevent reminders for an already-completed day.
    final count = switch (habit.recurrence) {
      HabitRecurrence.daily => 30,
      HabitRecurrence.weekly => 8,
      HabitRecurrence.monthly => 6,
    };
    for (var slot = 0; slot < count; slot++) {
      await _notificationService.scheduleOneShotNotification(
        id: id + slot,
        title: habit.summary,
        body: body,
        dateTime: firstOccurrence,
        payload: '${NotificationService.habitsPayloadPrefix}${habit.id}',
        actions: const [
          AndroidNotificationAction(
            kSnoozeActionId,
            'דחה ⏰',
            showsUserInterface: false,
          ),
        ],
      );
      firstOccurrence = habit.computeNextOccurrenceAfter(firstOccurrence);
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

/// Handles the "Snooze" button on a habit's notification. Registered as the
/// background notification-response callback and called by the foreground
/// app-level handler in main.dart. Must stay a top-level
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
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final habitId = payload.startsWith(NotificationService.habitsPayloadPrefix)
      ? payload.substring(NotificationService.habitsPayloadPrefix.length)
      : payload;
  if (habitId.isEmpty) return;

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
