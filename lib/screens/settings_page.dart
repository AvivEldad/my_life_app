import 'package:flutter/material.dart';
import 'statistics_page.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';
import '../screens/notifications_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('הגדרות'), centerTitle: true),
        drawer: const AppDrawer(),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.amber),
              title: const Text('סטטיסטיקות', style: TextStyle(fontSize: 18)),
              subtitle: const Text('צפה בנתוני ההתקדמות שלך'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StatisticsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_alarm, color: Colors.amber),
              title: const Text('התראות', style: TextStyle(fontSize: 18)),
              subtitle: const Text('עדכן או שנה התראות'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsSettingsPage(),
                  ),
                );
              },
            ),
            // בעתיד נוסיף כאן עוד הגדרות (התראות, ערכת נושא וכו')
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
