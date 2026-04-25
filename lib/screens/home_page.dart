import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/project_item.dart';
import '../models/category_item.dart';
import '../screens/tasks_tab.dart';
import '../screens/projects_tab.dart';
import '../services/database_service.dart';
import 'categories_page.dart';
import 'daily_list_page.dart';
import 'strikes_page.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoItem> _tasks = [];
  final List<ProjectItem> _projects = [];
  final List<CategoryItem> _categories = [];
  int _selectedIndex = 0;
  bool _loading = true;

  static const _titles = ['המשימות שלי', 'הטקסים שלי', 'הפרויקטים שלי'];
  static const _icons = [Icons.list, Icons.sync, Icons.folder_outlined];
  static const _labels = ['משימות', 'טקסים', 'פרויקטים'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        DatabaseService.loadTasks(),
        DatabaseService.loadProjects(),
        DatabaseService.loadCategories(),
      ]);
      setState(() {
        _tasks.addAll(results[0] as List<TodoItem>);
        _projects.addAll(results[1] as List<ProjectItem>);
        _categories.addAll(results[2] as List<CategoryItem>);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Error loading data: $e');
    }
  }

  // ─── Task actions ─────────────────────────────────────────────────
  Future<void> onTaskSaved(TodoItem task, {bool isNew = false}) async {
    if (isNew) {
      final id = await DatabaseService.addTask(task);
      // Update the in-memory id with the Firestore-generated one
      final index = _tasks.indexOf(task);
      if (index >= 0) {
        _tasks[index] = TodoItem.fromMap(id, task.toMap());
      }
    } else {
      await DatabaseService.updateTask(task);
    }
    setState(() {});
  }

  Future<void> onTaskDeleted(String id) async {
    await DatabaseService.deleteTask(id);
    setState(() => _tasks.removeWhere((t) => t.id == id));
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
  Future<void> onCategorySaved(CategoryItem category, {bool isNew = false}) async {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_titles[_selectedIndex])),

        // ── Drawer ──────────────────────────────────────────────────
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: const Text('תפריט',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ...List.generate(3, (i) => ListTile(
                  leading: Icon(_icons[i], color: _selectedIndex == i ? Colors.amber : null),
                  title: Text(_labels[i],
                      style: TextStyle(
                        fontWeight: _selectedIndex == i ? FontWeight.bold : FontWeight.normal,
                        color: _selectedIndex == i ? Colors.amber : null,
                      )),
                  selected: _selectedIndex == i,
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    Navigator.pop(context);
                  },
                )),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.today),
                  title: const Text('רשימה יומית'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const DailyListPage()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_fire_department),
                  title: const Text('סטריקים'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const StrikesPage()));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: const Text('קטגוריות'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoriesPage(
                          categories: _categories,
                          onSaved: (c, isNew) => onCategorySaved(c, isNew: isNew),
                          onDeleted: onCategoryDeleted,
                        ),
                      ),
                    );
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

        // ── Body ─────────────────────────────────────────────────────
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            TasksTab(
              tasks: _tasks,
              categories: _categories,
              isRituals: false,
              onTaskSaved: (t, isNew) => onTaskSaved(t, isNew: isNew),
              onTaskDeleted: onTaskDeleted,
              onChanged: () => setState(() {}),
            ),
            TasksTab(
              tasks: _tasks,
              categories: _categories,
              isRituals: true,
              onTaskSaved: (t, isNew) => onTaskSaved(t, isNew: isNew),
              onTaskDeleted: onTaskDeleted,
              onChanged: () => setState(() {}),
            ),
            ProjectsTab(
              projects: _projects,
              categories: _categories,
              onProjectSaved: (p, isNew) => onProjectSaved(p, isNew: isNew),
              onProjectDeleted: onProjectDeleted,
              onChanged: () => setState(() {}),
            ),
          ],
        ),

        // ── Bottom nav ───────────────────────────────────────────────
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'משימות'),
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'טקסים'),
            BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), label: 'פרויקטים'),
          ],
        ),
      ),
    );
  }
}