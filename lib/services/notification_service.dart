import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';

class NotificationService {
  // יצירת מופע יחיד (Singleton) כדי שנוכל לגשת אליו מכל מקום באפליקציה
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// אתחול המערכת (נקרא לזה כשהאפליקציה עולה)
  ///
  /// [onNotificationResponse] fires when the user taps the notification or
  /// one of its action buttons while the app is running or backgrounded.
  /// [onBackgroundNotificationResponse] fires for the same taps when the
  /// app process isn't running — it must be a top-level function annotated
  /// with `@pragma('vm:entry-point')` (Android launches it in a fresh
  /// isolate). Both can point to the same function.
  Future<void> init({
    void Function(NotificationResponse)? onNotificationResponse,
    void Function(NotificationResponse)? onBackgroundNotificationResponse,
  }) async {
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

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );
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
    String channelId = 'daily_reminders',
    String channelName = 'Daily Reminders',
    String channelDescription = 'Reminders for daily tasks and coins',
    String? payload,
    List<AndroidNotificationAction>? actions,
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
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            actions: actions,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e, st) {
      debugPrint(
        'NotificationService: failed to schedule notification id=$id: $e',
      );
      debugPrintStack(stackTrace: st);
    }
  }

  /// Schedules a notification that repeats every week on the same weekday
  /// and time (natively handled by the OS via matchDateTimeComponents, so
  /// this never needs to be rescheduled manually).
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1 = Monday ... 7 = Sunday (DateTime.weekday)
    required int hour,
    required int minute,
    String channelId = 'habit_reminders',
    String channelName = 'Habit Reminders',
    String channelDescription = 'Reminders for weekly and monthly habits',
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (!_initialized) await init();
    final bool exactAllowed = await _canScheduleExact();
    final AndroidScheduleMode scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfWeekday(weekday, hour, minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            actions: actions,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    } catch (e, st) {
      debugPrint(
        'NotificationService: failed to schedule weekly notification id=$id: $e',
      );
      debugPrintStack(stackTrace: st);
    }
  }

  /// Schedules a single, non-repeating notification at [dateTime]. Used for
  /// monthly habits: flutter_local_notifications has no built-in "every N
  /// months" repeat, so each occurrence is scheduled one at a time and the
  /// next one is (re)scheduled after this one fires or when the app is
  /// opened (see HabitService.catchUpOverdueMonthlyHabits).
  Future<void> scheduleOneShotNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String channelId = 'habit_reminders',
    String channelName = 'Habit Reminders',
    String channelDescription = 'Reminders for weekly and monthly habits',
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (!_initialized) await init();
    final bool exactAllowed = await _canScheduleExact();
    final AndroidScheduleMode scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            actions: actions,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        // No matchDateTimeComponents -> fires exactly once.
      );
    } catch (e, st) {
      debugPrint(
        'NotificationService: failed to schedule one-shot notification id=$id: $e',
      );
      debugPrintStack(stackTrace: st);
    }
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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
  Future<void> refreshCoinReminder(double currentCoins) async {
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

  /// פונקציה חכמה לרענון התראת הסטרייקים
  Future<void> refreshStrikeReminder(int pendingStrikesCount) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('isStrikeReminderEnabled') ?? false;
    if (!isEnabled) {
      await cancelNotification(4);
      return;
    }
    final hour = prefs.getInt('strikeReminderHour') ?? 20;
    final minute = prefs.getInt('strikeReminderMinute') ?? 0;
    final bodyText = pendingStrikesCount > 0
        ? 'יש לך $pendingStrikesCount סטרייקים שעדיין לא סימנת היום! אל תשבור את הרצף 🔥'
        : 'כל הכבוד! כל הסטרייקים שלך מסומנים להיום 🔥';
    await scheduleDailyNotification(
      id: 4, // מזהה ייחודי להתראת סטרייקים
      title: 'בדוק את הסטרייקים שלך 🔥',
      body: bodyText,
      hour: hour,
      minute: minute,
    );
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

  /// פונקציה חכמה לרענון התראת משימת הזהב
  Future<void> refreshGoldenTaskReminder(bool hasGoldenTask) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('isGoldenReminderEnabled') ?? false;

    // אם ההתראה כבויה או שאין משימת זהב פתוחה - נבטל את ההתראה
    if (!isEnabled || !hasGoldenTask) {
      await cancelNotification(5); // מזהה ייחודי להתראת משימת זהב
      return;
    }

    final hour = prefs.getInt('goldenReminderHour') ?? 9;
    final minute = prefs.getInt('goldenReminderMinute') ?? 0;

    await scheduleDailyNotification(
      id: 5,
      title: 'משימת זהב! 🌟',
      body: 'יש לך משימת זהב פתוחה, אל תזניח אותה!',
      hour: hour,
      minute: minute,
    );
  }

  Future<void> scheduleRandomMantras(List<String> mantrasTexts) async {
    // אם אין מנטרות, נבטל התראות קיימות
    if (mantrasTexts.isEmpty) {
      await cancelNotification(101);
      await cancelNotification(102);
      return;
    }

    final random = Random();

    // נחלק את היום לפעמיים כדי שלא יקפצו שתיהן באותה שעה:
    // התראה 1: בין 08:00 ל-14:00
    final hour1 = 8 + random.nextInt(7);
    final minute1 = random.nextInt(60);

    // התראה 2: בין 15:00 ל-20:00 (עד 20:59 שזה מתאים לדרישה של 21:00)
    final hour2 = 15 + random.nextInt(6);
    final minute2 = random.nextInt(60);

    // נגריל 2 מנטרות
    final text1 = mantrasTexts[random.nextInt(mantrasTexts.length)];
    final text2 = mantrasTexts[random.nextInt(mantrasTexts.length)];

    // נשתמש בפונקציה הקיימת שלנו כדי לתזמן אותן
    await scheduleDailyNotification(
      id: 101, // מזהה קבוע למנטרה הראשונה
      title: 'מוטיבציה בשבילך 🌟',
      body: text1,
      hour: hour1,
      minute: minute1,
    );

    await scheduleDailyNotification(
      id: 102, // מזהה קבוע למנטרה השנייה
      title: 'רגע של השראה ✨',
      body: text2,
      hour: hour2,
      minute: minute2,
    );
  }
}
