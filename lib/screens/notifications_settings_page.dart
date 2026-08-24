import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // טעינת ההגדרות השמורות מהמכשיר
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
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
    });
  }

  // שמירת שעות הפעילות ותזמון ההתראות
  Future<void> _selectTime(BuildContext context, bool isMorning) async {
    final TimeOfDay initialTime = isMorning
        ? _morningReminderTime
        : _coinReminderTime;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );

    if (pickedTime != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (isMorning) {
          _morningReminderTime = pickedTime;
          prefs.setInt('morningReminderHour', pickedTime.hour);
          prefs.setInt('morningReminderMinute', pickedTime.minute);
          if (_isMorningReminderEnabled) _scheduleMorningReminder();
        } else {
          _coinReminderTime = pickedTime;
          prefs.setInt('coinReminderHour', pickedTime.hour);
          prefs.setInt('coinReminderMinute', pickedTime.minute);
          if (_isCoinReminderEnabled) _refreshCoinReminderViaService();
        }
      });
    }
  }

  // הדלקה/כיבוי של התראת הבוקר
  Future<void> _toggleMorningReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isMorningReminderEnabled = value);
    await prefs.setBool('isMorningReminderEnabled', value);

    if (value) {
      _scheduleMorningReminder();
    } else {
      await NotificationService().cancelNotification(1);
    }
  }

  // הדלקה/כיבוי של התראת המטבעות
  Future<void> _toggleCoinReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isCoinReminderEnabled = value);
    await prefs.setBool('isCoinReminderEnabled', value);

    if (value) {
      _refreshCoinReminderViaService();
    } else {
      await NotificationService().cancelNotification(2);
    }
  }

  Future<void> _toggleDueReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDueReminderEnabled = value);
    await prefs.setBool('isDueReminderEnabled', value);

    if (value) {
      _refreshDueReminderViaService();
    } else {
      await NotificationService().cancelNotification(3);
    }
  }

  void _refreshDueReminderViaService() {
    // כאן בעתיד נוכל למשוך מ-TaskService את המספר המדויק. בינתיים נעביר 1 לצורך ההדגמה.
    NotificationService().refreshDueDateReminder(1);
  }

  void _scheduleMorningReminder() {
    NotificationService().scheduleDailyNotification(
      id: 1,
      title: 'בוקר טוב! ☀️',
      body: 'אל תשכח לבדוק את המשימות הפתוחות שלך להיום.',
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
            const SizedBox(height: 16), // ריווח קטן לפני הכרטיסיות
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
                      onTap: () => _selectTime(context, true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey.shade900,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.amber,
                    title: const Text('תזכורת תאריכי יעד (Due Dates)'),
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
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _dueReminderTime,
                        );
                        if (picked != null) {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() {
                            _dueReminderTime = picked;
                            prefs.setInt('dueReminderHour', picked.hour);
                            prefs.setInt('dueReminderMinute', picked.minute);
                            if (_isDueReminderEnabled)
                              _refreshDueReminderViaService();
                          });
                        }
                      },
                    ),
                ],
              ),
            ),
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
                      onTap: () => _selectTime(context, false),
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
