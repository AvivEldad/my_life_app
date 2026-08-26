import 'package:flutter/foundation.dart';
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

  bool _initialized = false;

  /// אתחול המערכת (נקרא לזה כשהאפליקציה עולה)
  Future<void> init() async {
    if (_initialized) return; // מונע אתחול כפול אם init() נקרא יותר מפעם אחת

    // אתחול מסד הנתונים של אזורי הזמן
    tz.initializeTimeZones();

    // קריאת אזור הזמן המקומי של המכשיר והגדרתו כברירת המחדל
    try {
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // אם קריאת אזור הזמן נכשלת, נופלים חזרה ל-UTC במקום לקרוס
      debugPrint(
        'NotificationService: failed to read local timezone, falling back to UTC: $e',
      );
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  /// בקשת הרשאה מהמשתמש באנדרואיד 13 ומעלה.
  /// מחזירה true אם גם הרשאת ההתראות וגם הרשאת ההתראות המדויקות אושרו.
  Future<bool> requestPermissions() async {
    final androidImplementation = _androidPlugin;
    if (androidImplementation == null) return false;

    final bool notificationsGranted =
        await androidImplementation.requestNotificationsPermission() ?? false;
    final bool exactAlarmsGranted =
        await androidImplementation.requestExactAlarmsPermission() ?? false;

    if (!exactAlarmsGranted) {
      debugPrint(
        'NotificationService: exact alarm permission NOT granted — '
        'scheduled reminders will fall back to inexact timing.',
      );
    }

    return notificationsGranted && exactAlarmsGranted;
  }

  /// בודק בזמן אמת האם מותר לתזמן התראות מדויקות (Android 12+).
  Future<bool> _canScheduleExact() async {
    final androidImplementation = _androidPlugin;
    if (androidImplementation == null) return false;
    try {
      return await androidImplementation.canScheduleExactNotifications() ??
          false;
    } catch (_) {
      // ישן מדי כדי לתמוך בבדיקה הזו - נניח שמותר
      return true;
    }
  }

  /// פונקציה גמישה לתזמון התראה יומית קבועה.
  /// אף פעם לא זורקת - אם התזמון נכשל, מתועד ב-log ולא מפיל את האפליקציה.
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) {
      debugPrint(
        'NotificationService: scheduleDailyNotification called before init() — initializing now.',
      );
      await init();
    }

    // אם אין הרשאת התראות מדויקות, נשתמש בתזמון לא-מדויק
    // במקום לתת ל-zonedSchedule לזרוק חריגה שקטה שאף אחד לא תופס.
    final bool exactAllowed = await _canScheduleExact();
    final AndroidScheduleMode scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders', // מזהה ערוץ (Channel ID)
            'Daily Reminders', // שם ערוץ שיופיע בהגדרות המכשיר
            channelDescription: 'Reminders for daily tasks and coins',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, st) {
      debugPrint(
        'NotificationService: failed to schedule notification id=$id: $e',
      );
      debugPrintStack(stackTrace: st);
    }
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

    if (!isEnabled) {
      await cancelNotification(2);
      return;
    }

    final hour = prefs.getInt('coinReminderHour') ?? 11;
    final minute = prefs.getInt('coinReminderMinute') ?? 0;

    await scheduleDailyNotification(
      id: 2, // מזהה התראת מטבעות
      title: 'סטטוס מטבעות 🪙',
      body: 'יש לך כרגע $currentCoins מטבעות! כנס לראות איזה פרס אפשר לממש.',
      hour: hour,
      minute: minute,
    );
  }

  /// פונקציה לשליחת התראה מיידית (מעולה לבדיקות)
  Future<void> showImmediateTestNotification() async {
    if (!_initialized) {
      await init();
    }

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

    try {
      await _notificationsPlugin.show(
        99, // מזהה ייחודי להתראת הבדיקה
        'בדיקת מערכת 🚀',
        'מעולה! מערכת ההתראות שלך עובדת בצורה מושלמת.',
        platformDetails,
      );
    } catch (e) {
      debugPrint('NotificationService: failed to show test notification: $e');
    }
  }

  /// פונקציה חכמה לרענון התראת תאריכי יעד
  Future<void> refreshDueDateReminder(int dueTasksCount) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('isDueReminderEnabled') ?? false;

    if (!isEnabled) {
      await cancelNotification(3);
      return;
    }

    final hour = prefs.getInt('dueReminderHour') ?? 17;
    final minute = prefs.getInt('dueReminderMinute') ?? 0;

    final bodyText = dueTasksCount > 0
        ? 'יש לך $dueTasksCount משימות עם תאריך יעד קרוב! כדאי להעיף מבט.'
        : 'אין לך משימות עם תאריכי יעד דחופים, אפשר להיות רגועים! ☕';

    await scheduleDailyNotification(
      id: 3, // מזהה ייחודי להתראת תאריכי יעד
      title: 'תאריכי יעד מתקרבים ⏰',
      body: bodyText,
      hour: hour,
      minute: minute,
    );
  }
}
