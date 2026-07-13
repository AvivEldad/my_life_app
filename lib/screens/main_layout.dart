import 'package:flutter/material.dart';
import 'home_page.dart';
import 'test_screen.dart'; // Just using this as a placeholder for the second tab

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // These are the screens that the bottom nav bar switches between.
  // Later, we will make this list dynamic based on your Settings!
  final List<Widget> _screens = [
    const HomePage(),
    const TestScreen(), // Placeholder for Projects/Prizes
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The Global Sidebar
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.amber.shade800),
              child: const Text(
                'תפריט ראשי\n(Main Menu)',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('הגדרות (Settings)'),
              onTap: () {
                // TODO: Navigate to settings screen
                Navigator.pop(context); // Closes the drawer
              },
            ),
            // We can add more drawer items here later
          ],
        ),
      ),
      // The body changes based on the selected bottom nav item
      body: _screens[_currentIndex],

      // The Global Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'משימות (Tasks)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            label: 'פרויקטים (Projects)',
          ),
        ],
      ),
    );
  }
}
