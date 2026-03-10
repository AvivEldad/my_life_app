import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/projects_page.dart';
//import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await NotificationService.init(); // אתחול שירות ההתראות
  runApp(const QuestLogApp());
}

class QuestLogApp extends StatelessWidget {
  const QuestLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuestLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData( // תיקון ל-CardThemeData
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // יצירת הדפים בתוך ה-build כדי להבטיח רענון תקין
    final List<Widget> pages = [
      const TodoHomePage(showRecurring: false), // Quests
      const TodoHomePage(showRecurring: true),  // Rituals
      const ProjectsPage(),                     // Projects
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Quests'),
          BottomNavigationBarItem(icon: Icon(Icons.cached), label: 'Rituals'),
          BottomNavigationBarItem(icon: Icon(Icons.account_tree), label: 'Projects'),
        ],
      ),
    );
  }
}