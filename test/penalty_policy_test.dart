import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_todo_app/models/habit_item.dart';
import 'package:my_todo_app/services/penalty_policy.dart';

void main() {
  final today = DateTime(2026, 9, 28, 12);

  test('long task backlog costs one day and cannot be charged again today', () {
    final data = <String, dynamic>{
      'dueDate': DateTime(2026, 1, 1).millisecondsSinceEpoch,
    };
    final result = PenaltyPolicy.task(data, today);
    expect(result.coins, 1);
    expect(result.xp, 5);
    data.addAll(result.updates);
    expect(PenaltyPolicy.task(data, today).updates, isEmpty);
    expect(PenaltyPolicy.task(data, DateTime(2026, 9, 29)).coins, 1);
  });

  test('weekly penalty works without a regular due date and is one-time', () {
    final data = <String, dynamic>{
      'isWeekly': true,
      'weeklyDeadline': DateTime(2026, 9, 26, 23, 59).millisecondsSinceEpoch,
      'level': 3,
    };
    final result = PenaltyPolicy.task(data, today);
    expect(result.coins, 15);
    expect(result.xp, 30);
    data.addAll(result.updates);
    expect(PenaltyPolicy.task(data, today).updates, isEmpty);
  });

  test('tasks and habits share persisted daily caps, renewed the next day', () {
    final stats = <String, dynamic>{'currentCoins': 100.0, 'currentXp': 90};
    for (var i = 0; i < 20; i++) {
      stats.addAll(PenaltyPolicy.apply(stats, 1, 5, today));
    }
    stats.addAll(PenaltyPolicy.apply(stats, 5, 10, today));
    expect(stats['currentCoins'], 90);
    expect(stats['currentXp'], 70);
    stats.addAll(PenaltyPolicy.apply(stats, 5, 10, DateTime(2026, 9, 29)));
    expect(stats['currentCoins'], 85);
    expect(stats['currentXp'], 60);
  });

  test('small balances never go negative', () {
    final result = PenaltyPolicy.apply(
      {'currentCoins': 0.5, 'currentXp': 2},
      5,
      10,
      today,
    );
    expect(result['currentCoins'], 0);
    expect(result['currentXp'], 0);
  });

  for (final recurrence in HabitRecurrence.values) {
    test('$recurrence habit has until midnight; a later snooze is honored', () {
      final habit = HabitItem(
        id: 'habit',
        summary: 'Habit',
        recurrence: recurrence,
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        nextDueDate: DateTime(2026, 9, 28, 9),
      );
      expect(habit.missDeadline, DateTime(2026, 9, 29));
      expect(today.isBefore(habit.missDeadline), isTrue);
      habit.snooze(now: DateTime(2026, 9, 28, 23, 50));
      expect(habit.missDeadline, DateTime(2026, 9, 29, 0, 20));
    });
  }
}
