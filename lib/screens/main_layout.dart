import 'package:flutter/material.dart';
import 'home_page.dart';
import 'projects_page.dart';
import '../widgets/app_drawer.dart';

class MainLayout extends StatefulWidget {
  // We added this variable to tell the layout which tab to open first
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // Initialize the tab bar with the requested index
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [const HomePage(), const ProjectsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
      ),
    );
  }
}
