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

import '../widgets/glowing_xp_bar.dart';
import '../widgets/floating_reward.dart';
import '../widgets/confetti_dialog.dart';

enum TaskSort { level, date, category }

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

  Future<void> _toggleWeekly(TaskItem task, List<TaskItem> allTasks) async {
    final taskService = context.read<TaskService>();
    final changedTasks = <TaskItem>[];

    setState(() {
      _suppressStreamUpdates = true;
      if (!task.isWeekly) {
        // מבטל משימות שבועיות אחרות (כי מותר רק אחת)
        for (var t in allTasks) {
          if (t.isWeekly && t.id != task.id) {
            t.isWeekly = false;
            t.weeklyDeadline = null;
            changedTasks.add(t);
          }
        }
        task.isWeekly = true;

        // חישוב שבת הקרובה ב-23:59:59
        final now = DateTime.now();
        int daysUntilSat = DateTime.saturday - now.weekday;
        if (daysUntilSat < 0) daysUntilSat += 7;
        final saturday = now.add(Duration(days: daysUntilSat));
        task.weeklyDeadline = DateTime(
          saturday.year,
          saturday.month,
          saturday.day,
          23,
          59,
          59,
        );
      } else {
        task.isWeekly = false;
        task.weeklyDeadline = null;
      }
      changedTasks.add(task);
    });

    try {
      await taskService.saveTasksBatch(changedTasks);
      await NotificationService().refreshWeeklyTaskReminder(task.isWeekly);
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
      } else if (sortType == TaskSort.category) {
        activeTasks.sort((a, b) {
          String getCategoryName(String? id) {
            if (id == null) return 'תתתת';
            try {
              return _categories.firstWhere((c) => c.id == id).name;
            } catch (_) {
              return 'תתתת';
            }
          }

          return getCategoryName(
            a.categoryId,
          ).compareTo(getCategoryName(b.categoryId));
        });
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
      task.completedAt = null;
      await gamificationService.processTaskUncompletion(task);

      if (task.projectId != null) {
        await projectService.revertProjectCompletionIfNeeded(
          task.projectId!,
          gamificationService,
        );
      }
    }

    // ביטול התראות קשורות אם המשימה הושלמה
    if (task.isGolden) {
      await NotificationService().refreshGoldenTaskReminder(false);
    }
    if (task.isWeekly) {
      await NotificationService().refreshWeeklyTaskReminder(false);
    }

    task.isCompleted = isNowCompleted;
    taskService.saveTask(task);
  }

  Future<void> _handleProjectTaskDelete(TaskItem task) async {
    final taskService = context.read<TaskService>();
    final gamificationService = context.read<GamificationService>();
    final projectService = context.read<ProjectService>();

    await taskService.deleteTask(task.id);

    // ניקוי התראות
    if (task.isGolden) {
      await NotificationService().refreshGoldenTaskReminder(false);
    }
    if (task.isWeekly) {
      await NotificationService().refreshWeeklyTaskReminder(false);
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
    TaskItem? weeklyTask; // משתנה למשימה השבועית
    List<TaskItem> activeTasks = [];
    List<TaskItem> completedTasks = [];

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
        continue;
      }

      // מיון המשימות המיוחדות לראש הרשימה
      if (task.isGolden) {
        if (goldenTask == null) {
          goldenTask = task;
        } else {
          activeTasks.add(task);
        }
      } else if (task.isWeekly) {
        if (weeklyTask == null) {
          weeklyTask = task;
        } else {
          activeTasks.add(task);
        }
      } else {
        activeTasks.add(task);
      }
    }

    activeTasks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final categoryById = {for (final c in _categories) c.id: c};
    final gamificationService = context.watch<GamificationService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlowingXpBar(
            currentXp: gamificationService.currentXp,
            threshold: gamificationService.currentXpThreshold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8.0,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.category, size: 18),
                label: const Text('קטגוריה'),
                onPressed: () => _applySort(TaskSort.category, activeTasks),
              ),
              TextButton.icon(
                icon: const Icon(Icons.sort, size: 18),
                label: const Text('רמה'),
                onPressed: () => _applySort(TaskSort.level, activeTasks),
              ),
              TextButton.icon(
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('תאריך'),
                onPressed: () => _applySort(TaskSort.date, activeTasks),
              ),
            ],
          ),
        ),

        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            header: Column(
              children: [
                if (goldenTask != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TaskCard(
                      key: Key(goldenTask.id),
                      task: goldenTask,
                      category: categoryById[goldenTask.categoryId],
                      onTap: () => _showTaskDetails(context, goldenTask),
                      onToggleGolden: () =>
                          _toggleGolden(goldenTask!, _allTasks),
                      onToggleWeekly: () =>
                          _toggleWeekly(goldenTask!, _allTasks),
                      onStatusChanged: (isCompleted) =>
                          _handleTaskStatusChanged(goldenTask!, isCompleted),
                      onDelete: goldenTask!.projectId != null
                          ? () => _handleProjectTaskDelete(goldenTask!)
                          : null,
                    ),
                  ),
                // הצגת המשימה השבועית בראש הרשימה
                if (weeklyTask != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: TaskCard(
                      key: Key(weeklyTask.id),
                      task: weeklyTask,
                      category: categoryById[weeklyTask.categoryId],
                      onTap: () => _showTaskDetails(context, weeklyTask),
                      onToggleGolden: () =>
                          _toggleGolden(weeklyTask!, _allTasks),
                      onToggleWeekly: () =>
                          _toggleWeekly(weeklyTask!, _allTasks),
                      onStatusChanged: (isCompleted) =>
                          _handleTaskStatusChanged(weeklyTask!, isCompleted),
                      onDelete: weeklyTask!.projectId != null
                          ? () => _handleProjectTaskDelete(weeklyTask!)
                          : null,
                    ),
                  ),
              ],
            ),

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
                          onToggleWeekly: () => _toggleWeekly(task, _allTasks),
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
                    onToggleWeekly: () => _toggleWeekly(task, _allTasks),
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
