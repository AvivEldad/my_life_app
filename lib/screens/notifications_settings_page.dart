import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/gamification_service.dart';
import '../services/strike_service.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

enum _ReminderType { morning, coin, due, strike, golden }

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _isMorningReminderEnabled = false;
  TimeOfDay _morningReminderTime = const TimeOfDay(hour: 8, minute: 0);

  bool _isCoinReminderEnabled = false;
  TimeOfDay _coinReminderTime = const TimeOfDay(hour: 11, minute: 0);

  bool _isDueReminderEnabled = false;
  TimeOfDay _dueReminderTime = const TimeOfDay(hour: 17, minute: 0);

  bool _isStrikeReminderEnabled = false;
  TimeOfDay _strikeReminderTime = const TimeOfDay(hour: 20, minute: 0);

  bool _isGoldenReminderEnabled = false;
  TimeOfDay _goldenReminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // טעינת ההגדרות השמורות מהמכשיר
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isMorningReminderEnabled =
          prefs.getBool('isMorningReminderEnabled') ?? false;
      _morningReminderTime = TimeOfDay(
        hour: prefs.getInt('morningReminderHour') ?? 8,
        minute: prefs.getInt('morningReminderMinute') ?? 0,
      );

      _isCoinReminderEnabled = prefs.getBool('isCoinReminderEnabled') ?? false;
      _coinReminderTime = TimeOfDay(
        hour: prefs.getInt('coinReminderHour') ?? 11,
        minute: prefs.getInt('coinReminderMinute') ?? 0,
      );

      _isDueReminderEnabled = prefs.getBool('isDueReminderEnabled') ?? false;
      _dueReminderTime = TimeOfDay(
        hour: prefs.getInt('dueReminderHour') ?? 17,
        minute: prefs.getInt('dueReminderMinute') ?? 0,
      );

      _isStrikeReminderEnabled =
          prefs.getBool('isStrikeReminderEnabled') ?? false;
      _strikeReminderTime = TimeOfDay(
        hour: prefs.getInt('strikeReminderHour') ?? 20,
        minute: prefs.getInt('strikeReminderMinute') ?? 0,
      );

      _isGoldenReminderEnabled =
          prefs.getBool('isGoldenReminderEnabled') ?? false;
      _goldenReminderTime = TimeOfDay(
        hour: prefs.getInt('goldenReminderHour') ?? 9,
        minute: prefs.getInt('goldenReminderMinute') ?? 0,
      );
    });
  }

  /// מבקש הרשאות התראות (רגילות + מדויקות) לפני הפעלת כל תזכורת.
  /// חשוב: בלי זה, תזכורות מתוזמנות עלולות להיכשל בשקט על מכשירים
  /// שמעולם לא ביקשו את הרשאת ה-Exact Alarms.
  Future<void> _ensurePermissions() async {
    final granted = await NotificationService().requestPermissions();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'כדי שהתזכורות יעבדו כמו שצריך, יש לאשר הרשאות התראות '
            'ו"התראות מדויקות" בהגדרות המכשיר.',
          ),
        ),
      );
    }
  }

  // בחירת שעה עבור כל אחת משלושת התזכורות, כולל שמירה ותזמון מחדש
  Future<void> _selectTime(BuildContext context, _ReminderType type) async {
    final TimeOfDay initialTime = switch (type) {
      _ReminderType.morning => _morningReminderTime,
      _ReminderType.coin => _coinReminderTime,
      _ReminderType.due => _dueReminderTime,
      _ReminderType.strike => _strikeReminderTime,
      _ReminderType.golden => _goldenReminderTime,
    };

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (pickedTime == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      switch (type) {
        case _ReminderType.morning:
          _morningReminderTime = pickedTime;
          prefs.setInt('morningReminderHour', pickedTime.hour);
          prefs.setInt('morningReminderMinute', pickedTime.minute);
          if (_isMorningReminderEnabled) _scheduleMorningReminder();
          break;
        case _ReminderType.coin:
          _coinReminderTime = pickedTime;
          prefs.setInt('coinReminderHour', pickedTime.hour);
          prefs.setInt('coinReminderMinute', pickedTime.minute);
          if (_isCoinReminderEnabled) _refreshCoinReminderViaService();
          break;
        case _ReminderType.due:
          _dueReminderTime = pickedTime;
          prefs.setInt('dueReminderHour', pickedTime.hour);
          prefs.setInt('dueReminderMinute', pickedTime.minute);
          if (_isDueReminderEnabled) _refreshDueReminderViaService();
          break;
        case _ReminderType.strike:
          _strikeReminderTime = pickedTime;
          prefs.setInt('strikeReminderHour', pickedTime.hour);
          prefs.setInt('strikeReminderMinute', pickedTime.minute);
          if (_isStrikeReminderEnabled) _refreshStrikeReminderViaService();
          break;
        case _ReminderType.golden:
          _goldenReminderTime = pickedTime;
          prefs.setInt('goldenReminderHour', pickedTime.hour);
          prefs.setInt('goldenReminderMinute', pickedTime.minute);
          if (_isGoldenReminderEnabled) _refreshGoldenReminderViaService();
          break;
      }
    });
  }

  // הדלקה/כיבוי של התראת הבוקר
  Future<void> _toggleMorningReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isMorningReminderEnabled = value);
    await prefs.setBool('isMorningReminderEnabled', value);

    if (value) {
      await _ensurePermissions();
      _scheduleMorningReminder();
    } else {
      await NotificationService().cancelNotification(1);
    }
  }

  // הדלקה/כיבוי של התראת המטבעות
  Future<void> _toggleCoinReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isCoinReminderEnabled = value);
    await prefs.setBool('isCoinReminderEnabled', value);

    if (value) {
      await _ensurePermissions();
      _refreshCoinReminderViaService();
    } else {
      await NotificationService().cancelNotification(2);
    }
  }

  Future<void> _toggleDueReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isDueReminderEnabled = value);
    await prefs.setBool('isDueReminderEnabled', value);

    if (value) {
      await _ensurePermissions();
      _refreshDueReminderViaService();
    } else {
      await NotificationService().cancelNotification(3);
    }
  }

  Future<void> _toggleStrikeReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isStrikeReminderEnabled = value);
    await prefs.setBool('isStrikeReminderEnabled', value);

    if (value) {
      await _ensurePermissions();
      _refreshStrikeReminderViaService();
    } else {
      await NotificationService().cancelNotification(4);
    }
  }

  Future<void> _toggleGoldenReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isGoldenReminderEnabled = value);
    await prefs.setBool('isGoldenReminderEnabled', value);

    if (value) {
      await _ensurePermissions();
      _refreshGoldenReminderViaService();
    } else {
      await NotificationService().cancelNotification(5);
    }
  }

  void _refreshGoldenReminderViaService() {
    // מפעיל את ההתראה (מניח כברירת מחדל שיש משימה כשהמשתמש מדליק מההגדרות)
    NotificationService().refreshGoldenTaskReminder(true);
  }

  void _refreshDueReminderViaService() {
    // כאן בעתיד נוכל למשוך מ-TaskService את המספר המדויק. בינתיים נעביר 1 לצורך ההדגמה.
    NotificationService().refreshDueDateReminder(1);
  }

  void _refreshStrikeReminderViaService() {
    context.read<StrikeService>().updateStrikeReminderNotification();
  }

  void _scheduleMorningReminder() {
    NotificationService().scheduleDailyNotification(
      id: 1,
      title: 'בוקר טוב! ☀️',
      body: 'אל תשכח לבדוק את המשימות הפתוחות שלך!.',
      hour: _morningReminderTime.hour,
      minute: _morningReminderTime.minute,
    );
  }

  void _refreshCoinReminderViaService() {
    // אנו שולפים את המטבעות הנוכחיים מה-Provider וקוראים לפונקציית הרענון
    final currentCoins = context.read<GamificationService>().currentCoins;
    NotificationService().refreshCoinReminder(currentCoins);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('הגדרות התראות'), centerTitle: true),
        drawer: const AppDrawer(),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'נהל את ההתראות היומיות שלך:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // --- כפתור בדיקה מיידית ---
            ElevatedButton.icon(
              onPressed: () async {
                // קודם נבקש הרשאות למקרה שהן לא ניתנו, ואז נציג את ההתראה
                await NotificationService().requestPermissions();
                await NotificationService().showImmediateTestNotification();
              },
              icon: const Icon(Icons.notifications_active, color: Colors.white),
              label: const Text(
                'שלח התראת בדיקה עכשיו',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- תזכורת בוקר ---
            Card(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber,
                    title: const Text('תזכורת משימות יומית'),
                    subtitle: const Text('קבל תזכורת לבדוק משימות פתוחות'),
                    value: _isMorningReminderEnabled,
                    onChanged: _toggleMorningReminder,
                  ),
                  if (_isMorningReminderEnabled)
                    ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blueAccent,
                      ),
                      title: const Text('שעת התראה'),
                      trailing: Text(
                        _morningReminderTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _selectTime(context, _ReminderType.morning),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- תזכורת תאריכי יעד ---
            Card(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber,
                    title: const Text('משימות עם תאריך יעד'),
                    subtitle: const Text(
                      'קבל עדכון על משימות שחייבים לסיים בקרוב',
                    ),
                    value: _isDueReminderEnabled,
                    onChanged: _toggleDueReminder,
                  ),
                  if (_isDueReminderEnabled)
                    ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blueAccent,
                      ),
                      title: const Text('שעת התראה'),
                      trailing: Text(
                        _dueReminderTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _selectTime(context, _ReminderType.due),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- תזכורת משימת זהב ---
            Card(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber,
                    title: const Text('תזכורת משימת זהב'),
                    subtitle: const Text(
                      'תזכורת יומית לא להזניח את משימת הזהב שלך',
                    ),
                    value: _isGoldenReminderEnabled,
                    onChanged: _toggleGoldenReminder,
                  ),
                  if (_isGoldenReminderEnabled)
                    ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blueAccent,
                      ),
                      title: const Text('שעת התראה'),
                      trailing: Text(
                        _goldenReminderTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _selectTime(context, _ReminderType.golden),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- תזכורת מטבעות דינמית ---
            Card(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber,
                    title: const Text('תזכורת סטטוס מטבעות'),
                    subtitle: const Text(
                      'קבל עדכון על כמות המטבעות הנוכחית שלך',
                    ),
                    value: _isCoinReminderEnabled,
                    onChanged: _toggleCoinReminder,
                  ),
                  if (_isCoinReminderEnabled)
                    ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blueAccent,
                      ),
                      title: const Text('שעת התראה'),
                      trailing: Text(
                        _coinReminderTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _selectTime(context, _ReminderType.coin),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- תזכורת סטרייקים ---
            Card(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber,
                    title: const Text('תזכורת סטרייקים'),
                    subtitle: const Text(
                      'קבל תזכורת יומית לסמן את הסטרייקים שלך',
                    ),
                    value: _isStrikeReminderEnabled,
                    onChanged: _toggleStrikeReminder,
                  ),
                  if (_isStrikeReminderEnabled)
                    ListTile(
                      leading: const Icon(
                        Icons.access_time,
                        color: Colors.blueAccent,
                      ),
                      title: const Text('שעת התראה'),
                      trailing: Text(
                        _strikeReminderTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _selectTime(context, _ReminderType.strike),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          unselectedItemColor: Colors.grey,
          selectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              label: 'משימות',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              label: 'פרויקטים',
            ),
          ],
          onTap: (index) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainLayout(initialIndex: index),
              ),
            );
          },
        ),
      ),
    );
  }
}
