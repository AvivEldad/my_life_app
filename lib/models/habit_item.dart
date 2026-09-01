import 'package:flutter/material.dart';

enum HabitRecurrence { daily, weekly, monthly }

/// A recurring habit with a reminder.
///
/// - daily: fires every day at [reminderTime].
/// - weekly: fires every week on [weekday] (1=Monday..7=Sunday, matching
///   `DateTime.weekday`) at [reminderTime].
/// - monthly: fires on [monthDay] (1-31) every [monthInterval] months at
///   [reminderTime]. If [monthDay] doesn't exist in the target month (e.g.
///   31 in a 30-day month), it fires on the last day of that month instead.
class HabitItem {
  final String id;
  String summary;
  String? description;
  String? categoryId;
  HabitRecurrence recurrence;
  TimeOfDay reminderTime;

  // Weekly only. 1 = Monday ... 7 = Sunday (DateTime.weekday convention).
  int? weekday;

  // Monthly only.
  int? monthDay; // 1-31, clamped to the last day of shorter months
  int? monthInterval; // every N months (1, 2, 3, ...)

  // The next time this habit is due to fire/be completed. Advances only
  // when the habit is marked done (see markDone()), so it can sit in the
  // past for an overdue habit until the user checks it off.
  DateTime nextDueDate;

  DateTime? lastCompletedDate;
  int currentStreak;
  int longestStreak;

  // Snooze: pushes the reminder 30 hours later, up to 2 times per
  // occurrence. Snoozing never cancels the eventual miss penalty if the
  // habit still isn't marked done once the (possibly snoozed) deadline
  // passes — see effectiveDeadline / markMissed().
  int snoozeCount;
  DateTime? snoozedUntil;

  DateTime createdAt;

  HabitItem({
    required this.id,
    required this.summary,
    this.description,
    this.categoryId,
    required this.recurrence,
    required this.reminderTime,
    this.weekday,
    this.monthDay,
    this.monthInterval,
    required this.nextDueDate,
    this.lastCompletedDate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.snoozeCount = 0,
    this.snoozedUntil,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Computes the first upcoming due date for this habit's recurrence
  /// settings. Call this when creating a habit, or after the user changes
  /// its recurrence fields while editing.
  DateTime computeInitialNextDueDate({DateTime? from}) {
    final now = from ?? DateTime.now();
    switch (recurrence) {
      case HabitRecurrence.daily:
        var candidate = DateTime(
          now.year,
          now.month,
          now.day,
          reminderTime.hour,
          reminderTime.minute,
        );
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;

      case HabitRecurrence.weekly:
        final targetWeekday = weekday ?? DateTime.monday;
        var candidate = DateTime(
          now.year,
          now.month,
          now.day,
          reminderTime.hour,
          reminderTime.minute,
        );
        final diff = (targetWeekday - candidate.weekday) % 7;
        candidate = candidate.add(Duration(days: diff));
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 7));
        }
        return candidate;

      case HabitRecurrence.monthly:
        final day = monthDay ?? now.day;
        var candidate = _dateForMonth(now.year, now.month, day, reminderTime);
        if (!candidate.isAfter(now)) {
          candidate = _addMonthsClamped(candidate, _clampedInterval);
        }
        return candidate;
    }
  }

  /// Given the current [date] (usually [nextDueDate]), returns the next
  /// occurrence strictly after it.
  DateTime computeNextOccurrenceAfter(DateTime date) {
    switch (recurrence) {
      case HabitRecurrence.daily:
        return date.add(const Duration(days: 1));
      case HabitRecurrence.weekly:
        return date.add(const Duration(days: 7));
      case HabitRecurrence.monthly:
        return _addMonthsClamped(date, _clampedInterval);
    }
  }

  DateTime _previousOccurrenceBefore(DateTime date) {
    switch (recurrence) {
      case HabitRecurrence.daily:
        return date.subtract(const Duration(days: 1));
      case HabitRecurrence.weekly:
        return date.subtract(const Duration(days: 7));
      case HabitRecurrence.monthly:
        return _addMonthsClamped(date, -_clampedInterval);
    }
  }

  int get _clampedInterval => (monthInterval ?? 1).clamp(1, 24);

  static const int maxSnoozes = 2;
  static const Duration snoozeDuration = Duration(minutes: 30);

  bool get canSnooze => snoozeCount < maxSnoozes;

  /// The moment this occurrence is actually due: the original schedule,
  /// pushed back by any snoozes still in effect.
  DateTime get effectiveDeadline => snoozedUntil ?? nextDueDate;

  /// Pushes the reminder 30 hours later. No-ops past [maxSnoozes] — check
  /// [canSnooze] first if you want to disable the button instead.
  void snooze({DateTime? now}) {
    if (!canSnooze) return;
    snoozeCount += 1;
    snoozedUntil = (now ?? DateTime.now()).add(snoozeDuration);
  }

  /// Called when [effectiveDeadline] has passed without the habit being
  /// marked done: breaks the streak and advances to the next occurrence.
  /// The coin/XP penalty itself is applied by the caller (it needs
  /// GamificationService, which this model doesn't depend on).
  void markMissed() {
    currentStreak = 0;
    snoozeCount = 0;
    snoozedUntil = null;
    nextDueDate = computeNextOccurrenceAfter(nextDueDate);
  }

  /// Marks the current occurrence complete: bumps the streak (or resets it
  /// to 1 if the previous scheduled occurrence was missed), records
  /// [lastCompletedDate], clears any snooze, and advances [nextDueDate] to
  /// the next occurrence.
  void markDone({DateTime? now}) {
    final today = now ?? DateTime.now();
    final previousDue = _previousOccurrenceBefore(nextDueDate);
    final previousDueDay = DateTime(
      previousDue.year,
      previousDue.month,
      previousDue.day,
    );
    final wasOnStreak =
        lastCompletedDate != null &&
        !lastCompletedDate!.isBefore(previousDueDay);

    currentStreak = wasOnStreak ? currentStreak + 1 : 1;
    if (currentStreak > longestStreak) longestStreak = currentStreak;

    lastCompletedDate = today;
    snoozeCount = 0;
    snoozedUntil = null;
    nextDueDate = computeNextOccurrenceAfter(nextDueDate);
  }

  static DateTime _dateForMonth(int year, int month, int day, TimeOfDay time) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final clampedDay = day > lastDayOfMonth ? lastDayOfMonth : day;
    return DateTime(year, month, clampedDay, time.hour, time.minute);
  }

  /// Adds (or subtracts, for negative [months]) whole months to [date],
  /// clamping the day-of-month to the last valid day of the target month.
  static DateTime _addMonthsClamped(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final remainder = totalMonths % 12; // Dart's % on int is always >= 0
    final year = date.year + (totalMonths - remainder) ~/ 12;
    final month = remainder + 1;
    return _dateForMonth(
      year,
      month,
      date.day,
      TimeOfDay(hour: date.hour, minute: date.minute),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'description': description,
      'categoryId': categoryId,
      'recurrence': recurrence.index,
      'reminderHour': reminderTime.hour,
      'reminderMinute': reminderTime.minute,
      'weekday': weekday,
      'monthDay': monthDay,
      'monthInterval': monthInterval,
      'nextDueDate': nextDueDate.millisecondsSinceEpoch,
      'lastCompletedDate': lastCompletedDate?.millisecondsSinceEpoch,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'snoozeCount': snoozeCount,
      'snoozedUntil': snoozedUntil?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory HabitItem.fromMap(String id, Map<String, dynamic> map) {
    final recurrenceIndex = (map['recurrence'] as int?) ?? 0;
    final reminderHour = (map['reminderHour'] as int?) ?? 9;
    final reminderMinute = (map['reminderMinute'] as int?) ?? 0;
    final nextDueMs = map['nextDueDate'] as int?;
    final lastCompletedMs = map['lastCompletedDate'] as int?;

    return HabitItem(
      id: id,
      summary: map['summary'] as String? ?? '',
      description: map['description'] as String?,
      categoryId: map['categoryId'] as String?,
      recurrence: HabitRecurrence
          .values[recurrenceIndex.clamp(0, HabitRecurrence.values.length - 1)],
      reminderTime: TimeOfDay(hour: reminderHour, minute: reminderMinute),
      weekday: map['weekday'] as int?,
      monthDay: map['monthDay'] as int?,
      monthInterval: map['monthInterval'] as int?,
      nextDueDate: nextDueMs != null
          ? DateTime.fromMillisecondsSinceEpoch(nextDueMs)
          : DateTime.now(),
      lastCompletedDate: lastCompletedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastCompletedMs)
          : null,
      currentStreak: (map['currentStreak'] as int?) ?? 0,
      longestStreak: (map['longestStreak'] as int?) ?? 0,
      snoozeCount: (map['snoozeCount'] as int?) ?? 0,
      snoozedUntil: map['snoozedUntil'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['snoozedUntil'] as int)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}
