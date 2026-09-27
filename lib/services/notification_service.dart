import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';
import 'dart:convert';
import 'mantra_schedule.dart';

class NotificationService {
  static const String homePayload = 'screen:home';
  static const String dailyListPayload = 'screen:daily-list';

  /// Today's list expires at midnight, so never repeat yesterday's reminder.
  Future<void> refreshDailyListReminder(bool hasPendingTasks) async {
    if (!_initialized) await init();
    final prefs = await SharedPreferences.getInstance();
    await cancelNotification(6);
    if (!(prefs.getBool('isDailyListReminderEnabled') ?? false) ||
        !hasPendingTasks) {
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final time = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      prefs.getInt('dailyListReminderHour') ?? 18,
      prefs.getInt('dailyListReminderMinute') ?? 0,
    );
    if (!time.isAfter(now)) return;
    await scheduleOneShotNotification(
      id: 6,
      title: 'הרשימה היומית שלך 📝',
      body: 'נשארו משימות ברשימה היומית. זה הזמן לבדוק ולהשלים אותן!',
      dateTime: time,
      channelId: 'daily_reminders',
      channelName: 'Daily Reminders',
      channelDescription: 'Reminders for daily tasks and coins',
      payload: dailyListPayload,
    );
  }

  static const String prizesPayload = 'screen:prizes';
  static const String strikesPayload = 'screen:strikes';
  static const String mantrasPayload = 'screen:mantras';
  static const String habitsPayloadPrefix = 'screen:habits;habitId:';

  // יצירת מופע יחיד (Singleton) כדי שנוכל לגשת אליו מכל מקום באפליקציה
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void> _mantraRefresh = Future<void>.value();

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

  Future<NotificationAppLaunchDetails?> getAppLaunchDetails() {
    return _notificationsPlugin.getNotificationAppLaunchDetails();
  }

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
      scheduled = tz.TZDateTime(
        tz.local,
        scheduled.year,
        scheduled.month,
        scheduled.day + 1,
        hour,
        minute,
      );
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
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelNotificationsForPayload(String payload) async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload == payload) await cancelNotification(request.id);
    }
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
      payload: prizesPayload,
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
        payload: homePayload,
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
    // Repeating notification bodies are snapshots, not live database reads.
    const bodyText = 'בדוק אילו סטרייקים נשארו לסמן היום ושמור על הרצף 🔥';
    await scheduleDailyNotification(
      id: 4, // מזהה ייחודי להתראת סטרייקים
      title: 'בדוק את הסטרייקים שלך 🔥',
      body: bodyText,
      hour: hour,
      minute: minute,
      payload: strikesPayload,
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

    const bodyText = 'בדוק את המשימות ואת תאריכי היעד הקרובים שלך.';

    await scheduleDailyNotification(
      id: 3, // מזהה ייחודי להתראת תאריכי יעד
      title: 'תאריכי יעד מתקרבים ⏰',
      body: bodyText,
      hour: hour,
      minute: minute,
      payload: homePayload,
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
      payload: homePayload,
    );
  }

  Future<void> scheduleRandomMantras(List<String> mantrasTexts) {
    final refresh = _mantraRefresh.then(
      (_) => _scheduleRandomMantras(mantrasTexts),
    );
    // Serialize cancellation and scheduling even when several edits overlap.
    _mantraRefresh = refresh.catchError((Object error, StackTrace stack) {
      debugPrint('Failed to refresh mantra schedule: $error');
    });
    return refresh;
  }

  Future<void> _scheduleRandomMantras(List<String> mantrasTexts) async {
    if (!_initialized) await init();
    const firstMantraId = 10100;
    const scheduledDays = 30;
    const notificationsPerDay = 2;
    const scheduledNotificationCount = scheduledDays * notificationsPerDay;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('mantraScheduleTimesV1');
    final previous = saved == null
        ? <String, List<int>>{}
        : (jsonDecode(saved) as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, List<int>.from(value as List)),
          );
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    final hasLegacySchedule = pending.any(
      (request) =>
          request.id == 101 ||
          request.id == 102 ||
          (request.id >= firstMantraId &&
              request.id < firstMantraId + scheduledNotificationCount),
    );
    final random = Random();
    final now = tz.TZDateTime.now(tz.local);
    final times = MantraSchedule.refresh(
      now: now,
      previous: previous,
      random: random,
      // Old versions did not track delivered slots. Avoid extra deliveries
      // on the migration day; normal delivery resumes tomorrow.
      skipToday: saved == null && hasLegacySchedule,
    );
    if (!await prefs.setString('mantraScheduleTimesV1', jsonEncode(times))) {
      throw StateError('Could not persist mantra notification times');
    }

    // Remove both the old repeating notifications and the previous rolling
    // schedule before building a fresh randomized schedule.
    await cancelNotification(101);
    await cancelNotification(102);
    for (int index = 0; index < scheduledNotificationCount; index++) {
      await cancelNotification(firstMantraId + index);
    }

    final mantras = mantrasTexts
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (mantras.isEmpty) return;

    var shuffledMantras = List<String>.from(mantras)..shuffle(random);
    var mantraIndex = 0;
    String? previousMantra;

    String nextMantra() {
      if (mantraIndex == shuffledMantras.length) {
        shuffledMantras = List<String>.from(mantras)..shuffle(random);
        mantraIndex = 0;

        if (shuffledMantras.length > 1 &&
            shuffledMantras.first == previousMantra) {
          final replacement = shuffledMantras[1];
          shuffledMantras[1] = shuffledMantras.first;
          shuffledMantras[0] = replacement;
        }
      }

      final mantra = shuffledMantras[mantraIndex++];
      previousMantra = mantra;
      return mantra;
    }

    for (int dayOffset = 0; dayOffset < scheduledDays; dayOffset++) {
      final date = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
      );
      final minutes = times[MantraSchedule.dateKey(date)]!;

      for (int slot = 0; slot < notificationsPerDay; slot++) {
        if (minutes[slot] < 0) continue;
        final scheduledTime = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          minutes[slot] ~/ 60,
          minutes[slot] % 60,
        );
        if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) continue;

        await scheduleOneShotNotification(
          id: MantraSchedule.idFor(date, slot),
          title: slot == 0 ? 'מוטיבציה בשבילך 🌟' : 'רגע של השראה ✨',
          body: nextMantra(),
          dateTime: scheduledTime,
          channelId: 'mantra_reminders',
          channelName: 'Mantra Reminders',
          channelDescription: 'Random motivational mantra reminders',
          payload: mantrasPayload,
        );
      }
    }
  }

  /// תזכורת לבחירת משימה שבועית בכל שבת ב-21:00
  Future<void> scheduleWeeklySelectionReminder() async {
    await scheduleWeeklyNotification(
      id: 200,
      title: 'משימה שבועית 🗓️',
      body: 'הגיע הזמן לבחור את המשימה השבועית שלך לשבוע הקרוב!',
      weekday: DateTime.saturday,
      hour: 21,
      minute: 0,
      payload: homePayload,
    );
  }

  /// תזכורת יומית למשימה השבועית הפעילה
  Future<void> refreshWeeklyTaskReminder(
    bool hasWeeklyTask, {
    DateTime? deadline,
  }) async {
    for (var id = 201; id <= 207; id++) {
      await cancelNotification(id);
    }
    if (!hasWeeklyTask || deadline == null) return;

    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < 7; offset++) {
      final date = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + offset,
        16,
      );
      if (!date.isAfter(now) || date.isAfter(deadline)) continue;
      final daysLeft = DateTime.utc(
        deadline.year,
        deadline.month,
        deadline.day,
      ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
      await scheduleOneShotNotification(
        id: 201 + offset,
        title: 'המשימה השבועית שלך ⏳',
        body: daysLeft > 0
            ? 'נשארו לך עוד $daysLeft ימים להשלים את המשימה השבועית ולהרוויח את הבונוס!'
            : 'זה היום האחרון! סיים את המשימה השבועית היום לפני חצות.',
        dateTime: date,
        channelId: 'daily_reminders',
        channelName: 'Daily Reminders',
        channelDescription: 'Reminders for daily tasks and coins',
        payload: homePayload,
      );
    }
  }
}
