import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project_item.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../services/task_service.dart';
import '../services/project_service.dart';
import '../services/gamification_service.dart';
import '../services/category_service.dart';
import '../widgets/task_card.dart';
import '../widgets/floating_reward.dart';
import '../widgets/confetti_dialog.dart';
import '../widgets/app_drawer.dart';
import 'task_details_screen.dart';
import 'create_project_screen.dart';
import 'main_layout.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final ProjectItem project;

  // המסך הזה חייב לקבל את הפרויקט שעליו לחצנו
  const ProjectDetailsScreen({super.key, required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late ProjectItem _project;

  StreamSubscription<List<TaskItem>>? _tasksSub;
  StreamSubscription<List<CategoryItem>>? _categoriesSub;

  List<TaskItem> _tasks = [];
  List<CategoryItem> _categories = [];
  bool _isLoading = true;
  bool _hasError = false;

  // בדומה לעמוד הבית - כדי שגרירה/מיון ירגישו מיידיים ולא "יקפצו" בגלל
  // עדכון מהסטרים באמצע הפעולה
  bool _suppressStreamUpdates = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _subscribeToTasks();
    _subscribeToCategories();
  }

  void _subscribeToTasks() {
    final taskService = context.read<TaskService>();
    _tasksSub = taskService
        .streamTasksForProject(_project.id)
        .listen(
          (tasks) {
            if (_suppressStreamUpdates) return;
            setState(() {
              _tasks = tasks;
              _isLoading = false;
              _hasError = false;
            });
          },
          onError: (_) {
            if (_suppressStreamUpdates) return;
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        );
  }

  void _subscribeToCategories() {
    final categoryService = context.read<CategoryService>();
    _categoriesSub = categoryService.streamCategories().listen((categories) {
      if (_suppressStreamUpdates) return;
      setState(() => _categories = categories);
    });
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _categoriesSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleSequential() async {
    final projectService = context.read<ProjectService>();
    final updated = ProjectItem(
      id: _project.id,
      title: _project.title,
      description: _project.description,
      isSequential: !_project.isSequential,
      isCompleted: _project.isCompleted,
      completedAt: _project.completedAt,
      createdAt: _project.createdAt,
      awardedXp: _project.awardedXp,
      awardedCoins: _project.awardedCoins,
      causedLevelUp: _project.causedLevelUp,
      xpThresholdBeforeLevelUp: _project.xpThresholdBeforeLevelUp,
      awardedPokemonId: _project.awardedPokemonId,
    );
    await projectService.saveProject(updated);
    if (mounted) {
      setState(() => _project = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isSequential
                ? 'הפרויקט נעול - משימות ייפתחו לפי הסדר'
                : 'הפרויקט פתוח - ניתן לבצע משימות בכל סדר',
          ),
        ),
      );
    }
  }

  void _addOrEditTask(TaskItem? task, int nextOrderIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(
          task: task,
          projectId: _project.id,
          projectName: _project.title,
          initialOrderIndex: nextOrderIndex,
        ),
      ),
    );
  }

  /// גרירה ידנית של משימות בתוך הפרויקט - קובעת גם את הסדר הטורי.
  Future<void> _onReorder(
    int oldIndex,
    int newIndex,
    List<TaskItem> openTasks,
  ) async {
    final taskService = context.read<TaskService>();

    setState(() {
      _suppressStreamUpdates = true;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = openTasks.removeAt(oldIndex);
      openTasks.insert(newIndex, item);
      for (int i = 0; i < openTasks.length; i++) {
        openTasks[i].orderIndex = i;
      }
    });

    try {
      await taskService.saveTasksBatch(openTasks);
    } finally {
      if (mounted) {
        setState(() => _suppressStreamUpdates = false);
      }
    }
  }

  /// מטפל בסימון/ביטול סימון של משימה בתוך הפרויקט - כולל תגמול/ניכוי
  /// XP ומטבעות, ובדיקה האם הושלם הפרויקט כולו.
  Future<void> _handleTaskStatusChanged(
    TaskItem task,
    bool isNowCompleted,
  ) async {
    final taskService = context.read<TaskService>();
    final gamificationService = context.read<GamificationService>();
    final projectService = context.read<ProjectService>();

    if (isNowCompleted && !task.isCompleted) {
      task.completedAt = DateTime.now();

      final earnedCoins = task.level * 5 * (task.isGolden ? 2 : 1);
      showFloatingReward(context, earnedCoins);

      int? pulledId = await gamificationService.processTaskCompletion(task);

      task.isCompleted = true;
      await taskService.saveTask(task);

      if (pulledId != null && context.mounted) {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => ConfettiDialog(
              title: 'LEVEL UP!',
              message:
                  'You have reached level ${gamificationService.currentLevel}!',
            ),
          );
        }
        if (context.mounted) {
          final pulledName = gamificationService.getItemName(pulledId);
          final imageUrl =
              'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$pulledId.png';
          await showDialog(
            context: context,
            builder: (context) => ConfettiDialog(
              title: 'New Character Unlocked!',
              message: 'You got $pulledName!',
              image: Image.network(imageUrl, height: 120),
            ),
          );
        }
      }

      // בדיקה האם זו הייתה המשימה האחרונה בפרויקט - ואם כן, מעניקים בונוס
      await _checkProjectCompletionAndCelebrate(
        projectService,
        gamificationService,
      );
    } else if (!isNowCompleted) {
      task.completedAt = null;
      await gamificationService.processTaskUncompletion(task);

      task.isCompleted = false;
      await taskService.saveTask(task);

      // אם הפרויקט כבר סומן כמושלם, וכעת נפתחה מחדש משימה בתוכו -
      // מבטלים את התגמול וההשלמה
      await projectService.revertProjectCompletionIfNeeded(
        _project.id,
        gamificationService,
      );
      final refreshed = await context.read<ProjectService>().getProjectOnce(
        _project.id,
      );
      if (refreshed != null && mounted) {
        setState(() => _project = refreshed);
      }
    }
  }

  /// בודק האם כל המשימות בפרויקט הושלמו (כולל דרך מחיקה של המשימה
  /// הפתוחה האחרונה, לא רק דרך סימון וי) ומעניק את בונוס ההשלמה אם כן.
  Future<void> _checkProjectCompletionAndCelebrate(
    ProjectService projectService,
    GamificationService gamificationService,
  ) async {
    final completedProject = await projectService
        .checkAndAwardProjectCompletion(_project.id, gamificationService);

    if (completedProject != null) {
      if (mounted) setState(() => _project = completedProject);
      if (context.mounted) {
        showFloatingReward(context, completedProject.awardedCoins ?? 100);
        await showDialog(
          context: context,
          builder: (context) => ConfettiDialog(
            title: 'Project Complete!',
            message:
                'You finished "${completedProject.title}" and earned '
                '${completedProject.awardedCoins ?? 100} coins & '
                '${completedProject.awardedXp ?? 200} xp!',
          ),
        );
      }
    }
  }

  /// מחיקת משימה בתוך הפרויקט - ולאחריה בדיקה האם נותרו רק משימות
  /// שהושלמו, שבמקרה כזה יש להשלים את הפרויקט ולהעניק את הבונוס (למקרה
  /// שהמשימה הפתוחה האחרונה נמחקה במקום סומנה כהושלמה).
  Future<void> _handleTaskDelete(TaskItem task) async {
    final taskService = context.read<TaskService>();
    final gamificationService = context.read<GamificationService>();
    final projectService = context.read<ProjectService>();

    await taskService.deleteTask(task.id);

    // אין טעם לבדוק השלמה אם המשימה שנמחקה כבר הייתה מסומנת כהושלמה -
    // מחיקתה לא יכולה לגרום להשלמת הפרויקט (הוא כבר היה מושלם קודם,
    // או שנשארו עוד משימות פתוחות אחרות שלא נגענו בהן)
    if (!task.isCompleted) {
      await _checkProjectCompletionAndCelebrate(
        projectService,
        gamificationService,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _project.isSequential
                ? 'פרויקט טורי (נעול)'
                : 'פרויקט חופשי',
            icon: Icon(
              _project.isSequential ? Icons.lock : Icons.lock_open,
              color: _project.isSequential ? Colors.amber : Colors.grey,
            ),
            onPressed: _toggleSequential,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final nextOrderIndex = _tasks.isEmpty
              ? 0
              : _tasks
                        .map((t) => t.orderIndex)
                        .reduce((a, b) => a > b ? a : b) +
                    1;
          _addOrEditTask(null, nextOrderIndex);
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add_task, color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          // חזרה למסך הראשי עם הטאב המבוקש פתוח
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => MainLayout(initialIndex: index),
            ),
            (route) => false,
          );
        },
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return const Center(child: Text('שגיאה בטעינת משימות.'));
    }

    final tasks = List<TaskItem>.from(_tasks)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final openTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    // במצב טורי - רק המשימה הפתוחה הראשונה בתור פתוחה לביצוע
    final String? unlockedTaskId = _project.isSequential && openTasks.isNotEmpty
        ? openTasks.first.id
        : null;

    final nextOrderIndex = tasks.isEmpty
        ? 0
        : tasks.map((t) => t.orderIndex).reduce((a, b) => a > b ? a : b) + 1;

    final catById = {for (final c in _categories) c.id: c};

    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'אין משימות בפרויקט הזה עדיין.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              'לחץ על ה- + כדי להוסיף משימה.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_project.description.isNotEmpty || _project.isSequential)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_project.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _project.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (_project.isSequential)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'פרויקט טורי: יש לבצע את המשימות לפי הסדר',
                            style: TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            onReorder: (oldIndex, newIndex) {
              _onReorder(oldIndex, newIndex, openTasks);
            },
            footer: completedTasks.isNotEmpty
                ? Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'משימות שהושלמו',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const Divider(),
                      ...completedTasks.map(
                        (task) => TaskCard(
                          key: Key(task.id),
                          task: task,
                          category: catById[task.categoryId],
                          onTap: () => _addOrEditTask(task, nextOrderIndex),
                          onToggleGolden: () {},
                          onToggleWeekly: () => {},
                          onStatusChanged: (isCompleted) =>
                              _handleTaskStatusChanged(task, isCompleted),
                          onDelete: () => _handleTaskDelete(task),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
            children: openTasks.map((task) {
              final locked =
                  unlockedTaskId != null && task.id != unlockedTaskId;
              return TaskCard(
                key: Key(task.id),
                task: task,
                category: catById[task.categoryId],
                locked: locked,
                onTap: () => _addOrEditTask(task, nextOrderIndex),
                onToggleGolden: () {},
                onToggleWeekly: () => {},
                onStatusChanged: (isCompleted) =>
                    _handleTaskStatusChanged(task, isCompleted),
                onDelete: () => _handleTaskDelete(task),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
