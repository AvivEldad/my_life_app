import 'package:shared_preferences/shared_preferences.dart'; // <-- הוספנו את השורה הזו
import '../widgets/xp_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/project_item.dart';
import '../models/category_item.dart';
import '../models/ritual_item.dart';
import '../screens/tasks_tab.dart';
import '../screens/projects_tab.dart';
import '../screens/rituals_tab.dart';
import '../services/database_service.dart';
import '../services/coin_service.dart';
import 'categories_page.dart';
import 'daily_list_page.dart';
import 'strikes_page.dart';
import 'mantras_page.dart';
import 'prizes_page.dart';
import 'binder_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final List<TaskItem> _tasks = [];
  final List<ProjectItem> _projects = [];
  final List<CategoryItem> _categories = [];
  final List<RitualItem> _rituals = [];

  int _selectedIndex = 0; // Controls the BottomNavigationBar
  int _currentDrawerIndex = 0; // Controls the Master IndexedStack
  bool _loading = true;

  static const _titles = ['המשימות שלי', 'ההרגלים שלי', 'הפרויקטים שלי'];
  static const _icons = [Icons.list, Icons.sync, Icons.folder_outlined];
  static const _labels = ['משימות', 'הרגלים', 'פרויקטים'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) {
      _runOptimizedBleedCheck();
      _checkMidnightDeletion(); // <-- קריאה לפונקציית המחיקה כשחוזרים לאפליקציה
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        DatabaseService.loadTasks(),
        DatabaseService.loadProjects(),
        DatabaseService.loadCategories(),
        DatabaseService.loadRituals(),
      ]);
      setState(() {
        _tasks.addAll(results[0] as List<TaskItem>);
        _projects.addAll(results[1] as List<ProjectItem>);
        _categories.addAll(results[2] as List<CategoryItem>);
        _rituals.addAll(results[3] as List<RitualItem>);
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runOptimizedBleedCheck();
        _checkMidnightDeletion();
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _checkMidnightDeletion() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastCleanDate = prefs.getString('last_clean_date');

    final String todayStr = DateTime.now().toIso8601String().split('T')[0];

    if (lastCleanDate != todayStr) {
      final completedRituals = _rituals.where((r) => r.isCompleted).toList();

      for (var ritual in completedRituals) {
        ritual.isCompleted = false;
        await DatabaseService.updateRitual(ritual);
      }

      final completedTasks = _tasks.where((t) => t.isCompleted).toList();

      for (var task in completedTasks) {
        await DatabaseService.deleteTask(task.id);
        _tasks.removeWhere((t) => t.id == task.id);
      }

      await prefs.setString('last_clean_date', todayStr);

      if ((completedTasks.isNotEmpty || completedRituals.isNotEmpty) &&
          mounted) {
        setState(() {});
      }
    }
  }
  // ───────────────────────────────────────────────────────────────────

  void _runOptimizedBleedCheck() {
    final uncompletedTasks = _tasks.where((task) => !task.isCompleted).toList();
    if (mounted) {
      Provider.of<CoinService>(
        context,
        listen: false,
      ).processActiveBleedPenalties(uncompletedTasks);
    }
  }

  // ─── Task actions ─────────────────────────────────────────────────
  Future<void> onTaskSaved(TaskItem task, {bool isNew = false}) async {
    if (isNew) {
      // 1. שמירה ב-Firebase וקבלת מזהה חדש
      final id = await DatabaseService.addTask(task);
      // 2. הוספת המשימה החדשה לראש הרשימה המקומית כדי שתוצג מיד!
      _tasks.insert(0, TaskItem.fromMap(id, task.toMap()));
    } else {
      // 1. עדכון ב-Firebase
      await DatabaseService.updateTask(task);
      // 2. עדכון המשימה ברשימה המקומית
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        _tasks[index] = task;
      }
    }
    setState(() {}); // רענון המסך
  }

  Future<void> onTaskDeleted(String id) async {
    await DatabaseService.deleteTask(id);
    setState(() => _tasks.removeWhere((t) => t.id == id));
  }

  // ─── Rituals actions ─────────────────────────────────────────────────

  Future<void> onRitualSaved(RitualItem ritual, {bool isNew = false}) async {
    if (isNew) {
      final id = await DatabaseService.addRitual(ritual);
      _rituals.insert(0, RitualItem.fromMap(id, ritual.toMap()));
    } else {
      await DatabaseService.updateRitual(ritual);
      final index = _rituals.indexWhere((r) => r.id == ritual.id);
      if (index >= 0) {
        _rituals[index] = ritual;
      }
    }
    setState(() {});
  }

  Future<void> onRitualDeleted(String id) async {
    await DatabaseService.deleteRitual(id);
    setState(() => _rituals.removeWhere((r) => r.id == id));
  }

  // ─── Project actions ──────────────────────────────────────────────
  Future<void> onProjectSaved(ProjectItem project, {bool isNew = false}) async {
    if (isNew) {
      final id = await DatabaseService.addProject(project);
      final index = _projects.indexOf(project);
      if (index >= 0) {
        _projects[index] = ProjectItem.fromMap(id, project.toMap());
      }
    } else {
      await DatabaseService.updateProject(project);
    }
    setState(() {});
  }

  Future<void> onProjectDeleted(String id) async {
    await DatabaseService.deleteProject(id);
    setState(() => _projects.removeWhere((p) => p.id == id));
  }

  // ─── Category actions ─────────────────────────────────────────────
  Future<void> onCategorySaved(
    CategoryItem category, {
    bool isNew = false,
  }) async {
    if (isNew) {
      final id = await DatabaseService.addCategory(category);
      final index = _categories.indexOf(category);
      if (index >= 0) {
        _categories[index] = CategoryItem.fromMap(id, category.toMap());
      }
    } else {
      await DatabaseService.updateCategory(category);
    }
    setState(() {});
  }

  Future<void> onCategoryDeleted(String id) async {
    await DatabaseService.deleteCategory(id);
    setState(() => _categories.removeWhere((c) => c.id == id));
  }

  // Dynamically calculate AppBar Title based on current view
  String get _currentAppBarTitle {
    if (_currentDrawerIndex == 0) return _titles[_selectedIndex];
    switch (_currentDrawerIndex) {
      case 1:
        return 'רשימה יומית';
      case 2:
        return 'סטרייקים';
      case 3:
        return 'מנטרות';
      case 4:
        return 'קטגוריות';
      case 5:
        return 'ביינדר';
      case 6:
        return 'פרסים';
      default:
        return 'Life App';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_currentAppBarTitle)),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: const Text(
                    'תפריט',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Home Items (Map to BottomNavigationBar index)
                ...List.generate(
                  3,
                  (i) => ListTile(
                    leading: Icon(
                      _icons[i],
                      color: (_currentDrawerIndex == 0 && _selectedIndex == i)
                          ? Colors.amber
                          : null,
                    ),
                    title: Text(
                      _labels[i],
                      style: TextStyle(
                        fontWeight:
                            (_currentDrawerIndex == 0 && _selectedIndex == i)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (_currentDrawerIndex == 0 && _selectedIndex == i)
                            ? Colors.amber
                            : null,
                      ),
                    ),
                    selected: (_currentDrawerIndex == 0 && _selectedIndex == i),
                    onTap: () {
                      setState(() {
                        _currentDrawerIndex = 0;
                        _selectedIndex = i;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('רשימה יומית'),
                  selected: _currentDrawerIndex == 1,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 1);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_fire_department),
                  title: const Text('סטרייקים'),
                  selected: _currentDrawerIndex == 2,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 2);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('מנטרות'),
                  selected: _currentDrawerIndex == 3,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 3);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: const Text('קטגוריות'),
                  selected: _currentDrawerIndex == 4,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 4);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.book, color: Colors.blueAccent),
                  title: const Text('ביינדר'),
                  selected: _currentDrawerIndex == 5,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 5);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.stars, color: Colors.amber),
                  title: const Text('פרסים'),
                  selected: _currentDrawerIndex == 6,
                  onTap: () {
                    setState(() => _currentDrawerIndex = 6);
                    Navigator.pop(context);
                  },
                ),
                const Spacer(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('הגדרות'),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // MASTER ROUTER: Swaps out the entire body without pushing to the stack
        body: IndexedStack(
          index: _currentDrawerIndex,
          children: [
            // Index 0: Main Tasks/Rituals/Projects Hub
            Column(
              children: [
                const XpProgressBar(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      TasksTab(
                        tasks: _tasks,
                        categories: _categories,
                        onTaskSaved: (t, isNew) => onTaskSaved(t, isNew: isNew),
                        onTaskDeleted: onTaskDeleted,
                        onChanged: () => setState(() {}),
                      ),
                      RitualsTab(
                        rituals: _rituals,
                        categories: _categories,
                        onRitualSaved: (r, isNew) =>
                            onRitualSaved(r, isNew: isNew),
                        onRitualDeleted: onRitualDeleted,
                        onChanged: () => setState(() {}),
                      ),
                      ProjectsTab(
                        projects: _projects,
                        categories: _categories,
                        onProjectSaved: (p, isNew) =>
                            onProjectSaved(p, isNew: isNew),
                        onProjectDeleted: onProjectDeleted,
                        onChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Index 1: Daily List
            const DailyListPage(),

            // Index 2: Strikes
            const StrikesPage(),

            // Index 3: Mantras
            const MantrasPage(),

            // Index 4: Categories
            CategoriesPage(
              categories: _categories,
              onSaved: (c, isNew) => onCategorySaved(c, isNew: isNew),
              onDeleted: onCategoryDeleted,
            ),

            // Index 5: Binder
            const BinderPage(),

            // Index 6: Prizes
            const PrizesPage(),
          ],
        ),

        // Hide BottomNavigationBar unless we are on the Home Hub (Index 0)
        bottomNavigationBar: _currentDrawerIndex == 0
            ? BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list),
                    label: 'משימות',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.sync),
                    label: 'הרגלים',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.folder_outlined),
                    label: 'פרויקטים',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
