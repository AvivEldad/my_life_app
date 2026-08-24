import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  // יצירת מופע יחיד (Singleton) כדי שנוכל לגשת אליו מכל מקום באפליקציה
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// אתחול המערכת (נקרא לזה כשהאפליקציה עולה)
  Future<void> init() async {
    // אתחול מסד הנתונים של אזורי הזמן
    tz.initializeTimeZones();

    // קריאת אזור הזמן המקומי של המכשיר והגדרתו כברירת המחדל (מעודכן לגרסה החדשה)
    final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = tzInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // הגדרות לאנדרואיד
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// בקשת הרשאה מהמשתמש באנדרואיד 13 ומעלה
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  /// פונקציה גמישה לתזמון התראה יומית קבועה
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute), // חישוב הזמן המדויק הבא
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders', // מזהה ערוץ (Channel ID)
          'Daily Reminders', // שם ערוץ שיופיע בהגדרות המכשיר
          channelDescription: 'Reminders for daily tasks and coins',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // אומר למערכת לחזור על זה כל יום באותה שעה
    );
  }

  /// פונקציית עזר שמחשבת מתי הפעם הבאה שהשעה הזו מתרחשת
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // אם השעה הזו כבר עברה היום, נתזמן למחר
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// פונקציה חכמה לרענון התראת המטבעות
  /// פונקציה זו תיקרא בכל פעם שמספר המטבעות שלך משתנה
  Future<void> refreshCoinReminder(int currentCoins) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('isCoinReminderEnabled') ?? false;

    // אם ההתראה כבויה, נוודא שהיא מבוטלת ולא נמשיך
    if (!isEnabled) {
      await cancelNotification(2);
      return;
    }

    // שליפת השעה שהמשתמש שמר (או ברירת מחדל 11:00)
    final hour = prefs.getInt('coinReminderHour') ?? 11;
    final minute = prefs.getInt('coinReminderMinute') ?? 0;

    // תזמון מחדש עם הטקסט המעודכן
    await scheduleDailyNotification(
      id: 2, // מזהה התראת מטבעות
      title: 'סטטוס מטבעות 🪙',
      body: 'יש לך כרגע $currentCoins מטבעות! כנס לראות איזה פרס אפשר לרכוש.',
      hour: hour,
      minute: minute,
    );
  }

  /// פונקציה לשליחת התראה מיידית (מעולה לבדיקות)
  Future<void> showImmediateTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel', // מזהה ערוץ נפרד לבדיקות
          'Test Notifications',
          channelDescription: 'Channel for testing notifications immediately',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      99, // מזהה ייחודי להתראת הבדיקה
      'בדיקת מערכת 🚀',
      'מעולה! מערכת ההתראות שלך עובדת בצורה מושלמת.',
      platformDetails,
    );
  }

  /// פונקציה חכמה לרענון התראת תאריכי יעד
  Future<void> refreshDueDateReminder(int dueTasksCount) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('isDueReminderEnabled') ?? false;

    // אם ההתראה כבויה, מבטלים אותה (משתמשים במזהה 3)
    if (!isEnabled) {
      await cancelNotification(3);
      return;
    }

    // שליפת השעה שהמשתמש שמר (או ברירת מחדל 17:00)
    final hour = prefs.getInt('dueReminderHour') ?? 17;
    final minute = prefs.getInt('dueReminderMinute') ?? 0;

    final bodyText = dueTasksCount > 0
        ? 'יש לך $dueTasksCount משימות עם תאריך יעד קרוב! כדאי להעיף מבט.'
        : 'אין לך משימות עם תאריכי יעד דחופים, אפשר להיות רגועים! ☕';

    // תזמון מחדש עם הטקסט המעודכן
    await scheduleDailyNotification(
      id: 3, // מזהה ייחודי להתראת תאריכי יעד
      title: 'תאריכי יעד מתקרבים ⏰',
      body: bodyText,
      hour: hour,
      minute: minute,
    );
  }
}
