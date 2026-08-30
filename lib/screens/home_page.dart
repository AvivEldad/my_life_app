import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../services/task_service.dart';
import '../services/gamification_service.dart';
import '../services/category_service.dart';
import '../services/project_service.dart';
import '../widgets/task_card.dart';
import 'task_details_screen.dart';
import '../widgets/app_drawer.dart';
import '../services/notification_service.dart';

// הייבוא של האנימציות והווידג'טים החדשים שלנו!
import '../widgets/glowing_xp_bar.dart';
import '../widgets/floating_reward.dart';
import '../widgets/confetti_dialog.dart';

enum TaskSort { level, date }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  StreamSubscription<List<TaskItem>>? _tasksSub;
  StreamSubscription<List<CategoryItem>>? _categoriesSub;

  List<TaskItem> _allTasks = [];
  List<CategoryItem> _categories = [];
  bool _isLoading = true;
  bool _hasError = false;

  bool _suppressStreamUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _subscribeToTasks();
    _subscribeToCategories();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDailyChecks();
    });
  }

  void _subscribeToTasks() {
    final taskService = context.read<TaskService>();
    _tasksSub = taskService.streamTasks().listen(
      (tasks) {
        if (_suppressStreamUpdates) return;
        setState(() {
          _allTasks = tasks;
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runDailyChecks();
    }
  }

  void _runDailyChecks() {
    context.read<TaskService>().clearCompletedTasks();
    context.read<ProjectService>().clearCompletedProjects();
    context.read<GamificationService>().processOverduePenalties();
  }

  void _showTaskDetails(BuildContext context, TaskItem? task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskDetailsScreen(task: task)),
    );
  }

  Future<void> _toggleGolden(TaskItem task, List<TaskItem> allTasks) async {
    final taskService = context.read<TaskService>();
    final changedTasks = <TaskItem>[];

    setState(() {
      _suppressStreamUpdates = true;
      if (!task.isGolden) {
        for (var t in allTasks) {
          if (t.isGolden && t.id != task.id) {
            t.isGolden = false;
            changedTasks.add(t);
          }
        }
        task.isGolden = true;
      } else {
        task.isGolden = false;
      }
      changedTasks.add(task);
    });

    try {
      await taskService.saveTasksBatch(changedTasks);
      await NotificationService().refreshGoldenTaskReminder(task.isGolden);
    } finally {
      if (mounted) {
        setState(() => _suppressStreamUpdates = false);
      }
    }
  }

  Future<void> _applySort(TaskSort sortType, List<TaskItem> activeTasks) async {
    final taskService = context.read<TaskService>();

    setState(() {
      _suppressStreamUpdates = true;
      if (sortType == TaskSort.level) {
        activeTasks.sort((a, b) => b.level.compareTo(a.level));
      } else if (sortType == TaskSort.date) {
        activeTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      for (int i = 0; i < activeTasks.length; i++) {
        activeTasks[i].orderIndex = i;
      }
    });

    try {
      await taskService.saveTasksBatch(activeTasks);
    } finally {
      if (mounted) {
        setState(() => _suppressStreamUpdates = false);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הרשימה מויינה בהצלחה! (ניתן לגרור מחדש)'),
        ),
      );
    }
  }

  Future<void> _onReorder(
    int oldIndex,
    int newIndex,
    List<TaskItem> activeTasks,
  ) async {
    final taskService = context.read<TaskService>();

    setState(() {
      _suppressStreamUpdates = true;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = activeTasks.removeAt(oldIndex);
      activeTasks.insert(newIndex, item);
      for (int i = 0; i < activeTasks.length; i++) {
        activeTasks[i].orderIndex = i;
      }
    });

    try {
      await taskService.saveTasksBatch(activeTasks);
    } finally {
      if (mounted) {
        setState(() => _suppressStreamUpdates = false);
      }
    }
  }

  // הפונקציה המרכזית החדשה שמנהלת את כל האנימציות לאחר סימון משימה
  Future<void> _handleTaskStatusChanged(
    TaskItem task,
    bool isNowCompleted,
  ) async {
    final taskService = context.read<TaskService>();
    final gamificationService = context.read<GamificationService>();
    final projectService = context.read<ProjectService>();

    if (isNowCompleted && !task.isCompleted) {
      task.completedAt = DateTime.now();

      // 1. אנימציית המטבעות צפה מיד
      final earnedCoins = task.level * 5 * (task.isGolden ? 2 : 1);
      showFloatingReward(context, earnedCoins);

      // 2. חישוב XP מול השירות
      int? pulledId = await gamificationService.processTaskCompletion(task);

      // 3. בדיקה אם עלינו רמה ויש דמות חדשה להציג
      if (pulledId != null && context.mounted) {
        // המתנה של שנייה כדי ליהנות מהאנימציה של מד ה-XP
        await Future.delayed(const Duration(milliseconds: 1000));

        if (context.mounted) {
          // חלון קונפטי ראשון: עליית רמה
          await showDialog(
            context: context,
            builder: (context) => ConfettiDialog(
              // שמנו לב שהסרנו את ה-'const' כדי שנוכל להעביר משתנה
              title: 'LEVEL UP!',
              // כאן אנחנו מושכים את מספר הרמה הנוכחי מתוך השירות!
              message:
                  'You have reached level ${gamificationService.currentLevel}!',
            ),
          );
        }

        if (context.mounted) {
          // חלון קונפטי שני: הדמות שקיבלנו
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

      // 4. אם המשימה שייכת לפרויקט - בדיקה האם זו הייתה המשימה
      // האחרונה שנותרה, ואם כן - הענקת בונוס ההשלמה
      if (task.projectId != null) {
        final completedProject = await projectService
            .checkAndAwardProjectCompletion(
              task.projectId!,
              gamificationService,
            );

        if (completedProject != null && context.mounted) {
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
    } else if (!isNowCompleted) {
      // אם המשתמש ביטל את סימון המשימה
      task.completedAt = null;
      await gamificationService.processTaskUncompletion(task);

      // אם המשימה שייכת לפרויקט שכבר סומן כמושלם - נבטל את ההשלמה
      // ואת התגמול שניתן עבורה
      if (task.projectId != null) {
        await projectService.revertProjectCompletionIfNeeded(
          task.projectId!,
          gamificationService,
        );
      }
    }
    if (task.isGolden) {
      await NotificationService().refreshGoldenTaskReminder(false);
    }
    // עדכון המצב ושמירה למסד הנתונים
    task.isCompleted = isNowCompleted;
    taskService.saveTask(task);
  }

  /// מחיקת משימה ששייכת לפרויקט, ישירות מעמוד הבית - ולאחריה בדיקה האם
  /// נותרו רק משימות שהושלמו בפרויקט הזה, שבמקרה כזה משלימים אותו
  /// ומעניקים את הבונוס (למקרה שהמשימה הפתוחה האחרונה נמחקה במקום
  /// סומנה כהושלמה).
  Future<void> _handleProjectTaskDelete(TaskItem task) async {
    final taskService = context.read<TaskService>();
    final gamificationService = context.read<GamificationService>();
    final projectService = context.read<ProjectService>();

    await taskService.deleteTask(task.id);
    if (task.isGolden) {
      await NotificationService().refreshGoldenTaskReminder(false);
    }
    if (!task.isCompleted && task.projectId != null) {
      final completedProject = await projectService
          .checkAndAwardProjectCompletion(task.projectId!, gamificationService);

      if (completedProject != null && context.mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('המשימות שלי'), centerTitle: true),
      drawer: const AppDrawer(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDetails(context, null),
        child: const Icon(Icons.add),
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
    if (_allTasks.isEmpty) {
      return const Center(child: Text('אין משימות. לחץ על + כדי להוסיף.'));
    }

    TaskItem? goldenTask;
    List<TaskItem> activeTasks = [];
    List<TaskItem> completedTasks = [];

    // עבור כל פרויקט מוצגת רק המשימה הפתוחה הראשונה שלו (לפי orderIndex) -
    // אבל היא משתתפת ברשימה הרגילה בדיוק כמו כל משימה אחרת (ניתן לגרור
    // ולמיין אותה יחד עם השאר). שאר המשימות של אותו פרויקט (נעולות/לא
    // בתור) לא מוצגות בעמוד הבית בכלל.
    final Map<String, List<TaskItem>> openTasksByProject = {};
    for (final task in _allTasks) {
      if (task.projectId == null) continue;
      if (task.isCompleted) continue;
      openTasksByProject.putIfAbsent(task.projectId!, () => []).add(task);
    }
    final Set<String> projectCurrentTaskIds = {};
    for (final tasks in openTasksByProject.values) {
      tasks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      projectCurrentTaskIds.add(tasks.first.id);
    }

    for (var task in _allTasks) {
      if (task.isCompleted) {
        completedTasks.add(task);
        continue;
      }
      if (task.projectId != null && !projectCurrentTaskIds.contains(task.id)) {
        // משימה נעולה / לא בתור של הפרויקט שלה - לא מוצגת בעמוד הבית
        continue;
      }
      if (task.isGolden) {
        if (goldenTask == null) {
          goldenTask = task;
        } else {
          activeTasks.add(task);
        }
      } else {
        activeTasks.add(task);
      }
    }

    activeTasks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final categoryById = {for (final c in _categories) c.id: c};
    // משיכת השירות כדי להעביר את הנתונים העדכניים ל-GlowingXpBar
    final gamificationService = context.watch<GamificationService>();

    return Column(
      children: [
        // הבר החדש והזוהר שלנו!
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlowingXpBar(
            currentXp: gamificationService.currentXp,
            threshold: gamificationService.currentXpThreshold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.sort, size: 18),
                label: const Text('מיין לפי רמה'),
                onPressed: () => _applySort(TaskSort.level, activeTasks),
              ),
              TextButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('מיין לפי תאריך'),
                onPressed: () => _applySort(TaskSort.date, activeTasks),
              ),
            ],
          ),
        ),

        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            header: goldenTask != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TaskCard(
                      key: Key(goldenTask.id),
                      task: goldenTask,
                      category: categoryById[goldenTask.categoryId],
                      onTap: () => _showTaskDetails(context, goldenTask),
                      onToggleGolden: () =>
                          _toggleGolden(goldenTask!, _allTasks),
                      // חיבור הפונקציה החדשה שלנו
                      onStatusChanged: (isCompleted) =>
                          _handleTaskStatusChanged(goldenTask!, isCompleted),
                      onDelete: goldenTask.projectId != null
                          ? () => _handleProjectTaskDelete(goldenTask!)
                          : null,
                    ),
                  )
                : const SizedBox.shrink(),

            onReorder: (int oldIndex, int newIndex) {
              _onReorder(oldIndex, newIndex, activeTasks);
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
                          category: categoryById[task.categoryId],
                          onTap: () => _showTaskDetails(context, task),
                          onToggleGolden: () => _toggleGolden(task, _allTasks),
                          // חיבור הפונקציה החדשה שלנו
                          onStatusChanged: (isCompleted) =>
                              _handleTaskStatusChanged(task, isCompleted),
                          onDelete: task.projectId != null
                              ? () => _handleProjectTaskDelete(task)
                              : null,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),

            children: activeTasks
                .map(
                  (task) => TaskCard(
                    key: Key(task.id),
                    task: task,
                    category: categoryById[task.categoryId],
                    onTap: () => _showTaskDetails(context, task),
                    onToggleGolden: () => _toggleGolden(task, _allTasks),
                    // חיבור הפונקציה החדשה שלנו
                    onStatusChanged: (isCompleted) =>
                        _handleTaskStatusChanged(task, isCompleted),
                    onDelete: task.projectId != null
                        ? () => _handleProjectTaskDelete(task)
                        : null,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
