import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    // תיקון: initialize מקבל רק פרמטר אחד חובה בגרסאות החדשות
    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> scheduleNotification(TodoItem item) async {
    if (item.reminderTime == null || item.recurrence == RecurrenceType.none) return;

    await _notificationsPlugin.zonedSchedule(
      item.id.hashCode,
      item.title,
      item.description ?? "זמן לביצוע הטקס!",
      _nextInstanceOfTime(item),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rituals_channel',
          'Rituals',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // חובה בגרסאות חדשות
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _getDateTimeComponents(item.recurrence),
    );
  }

  static DateTimeComponents? _getDateTimeComponents(RecurrenceType type) {
    if (type == RecurrenceType.daily) return DateTimeComponents.time;
    if (type == RecurrenceType.weekly) return DateTimeComponents.dayOfWeekAndTime;
    if (type == RecurrenceType.monthly) return DateTimeComponents.dayOfMonthAndTime;
    return null;
  }

  static tz.TZDateTime _nextInstanceOfTime(TodoItem item) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final TimeOfDay time = item.reminderTime!;
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> cancelNotification(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
  }
}