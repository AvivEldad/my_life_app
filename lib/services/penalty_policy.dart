import 'dart:math';

class TaskPenalty {
  final int coins;
  final int xp;
  final Map<String, dynamic> updates;
  const TaskPenalty(this.coins, this.xp, this.updates);
}

/// Shared budget across all automatic penalties, persisted with the balance.
class PenaltyPolicy {
  static const dailyCoinCap = 10;
  static const dailyXpCap = 20;

  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static TaskPenalty task(Map<String, dynamic> data, DateTime now) {
    final today = day(now);
    final updates = <String, dynamic>{};
    var coins = 0;
    var xp = 0;
    final weeklyMs = data['weeklyDeadline'] as int?;
    if (data['isWeekly'] == true &&
        weeklyMs != null &&
        today.isAfter(DateTime.fromMillisecondsSinceEpoch(weeklyMs))) {
      final level = (data['level'] as num?)?.toInt() ?? 1;
      coins += max(0, level) * 5;
      xp += max(0, level) * 10;
      updates.addAll({'isWeekly': false, 'weeklyDeadline': null});
    }
    final dueMs = data['dueDate'] as int?;
    final lastMs = data['lastPenaltyDate'] as int?;
    if (dueMs != null &&
        day(DateTime.fromMillisecondsSinceEpoch(dueMs)).isBefore(today) &&
        (lastMs == null ||
            day(DateTime.fromMillisecondsSinceEpoch(lastMs)).isBefore(today))) {
      // Forgive older days instead of charging the backlog on every reopen.
      coins += 1;
      xp += 5;
      updates['lastPenaltyDate'] = today.millisecondsSinceEpoch;
    }
    return TaskPenalty(coins, xp, updates);
  }

  static Map<String, dynamic> apply(
    Map<String, dynamic> stats,
    num coins,
    int xp,
    DateTime now,
  ) {
    final key = '${now.year}-${now.month}-${now.day}';
    final sameDay = stats['penaltyDay'] == key;
    final usedCoins = sameDay ? (stats['penaltyCoins'] as num? ?? 0) : 0;
    final usedXp = sameDay ? (stats['penaltyXp'] as num? ?? 0).toInt() : 0;
    final balance = (stats['currentCoins'] as num? ?? 0).toDouble();
    final experience = (stats['currentXp'] as num? ?? 0).toInt();
    final chargedCoins = min(
      max(0, balance),
      min(max(0, coins), max(0, dailyCoinCap - usedCoins)),
    );
    final chargedXp = min(
      max(0, experience),
      min(max(0, xp), max(0, dailyXpCap - usedXp)),
    );
    return {
      'currentCoins': balance - chargedCoins,
      'currentXp': experience - chargedXp,
      'penaltyDay': key,
      'penaltyCoins': usedCoins + chargedCoins,
      'penaltyXp': usedXp + chargedXp,
    };
  }
}
