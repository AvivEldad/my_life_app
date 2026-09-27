import 'dart:math';
import 'package:timezone/timezone.dart' as tz;

/// A persisted pair of local times per date. Refreshing must never roll a
/// consumed slot forward and grant an extra notification on the same day.
class MantraSchedule {
  static const days = 30;
  static const firstId = 10100;

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static Map<String, List<int>> refresh({
    required tz.TZDateTime now,
    required Map<String, List<int>> previous,
    required Random random,
    bool skipToday = false,
  }) {
    return {
      for (var offset = 0; offset < days; offset++)
        dateKey(
          tz.TZDateTime(now.location, now.year, now.month, now.day + offset),
        ): previous[dateKey(
              tz.TZDateTime(
                now.location,
                now.year,
                now.month,
                now.day + offset,
              ),
            )] ??
            (offset == 0 && skipToday
                ? [-1, -1]
                : [
                    8 * 60 + random.nextInt(7 * 60),
                    15 * 60 + random.nextInt(6 * 60),
                  ]),
    };
  }

  // Reuse a bounded ID range, but keep a date's IDs stable across restarts.
  static int idFor(DateTime date, int slot) {
    final day = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(1970)).inDays;
    return firstId + (day % days) * 2 + slot;
  }
}
