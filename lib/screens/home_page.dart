import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/gamification_service.dart';
import '../widgets/task_card.dart';
import 'task_details_screen.dart';
import '../widgets/app_drawer.dart';
import '../widgets/xp_bar.dart';

enum TaskSort { level, date }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  StreamSubscription<List<TaskItem>>? _tasksSub;

  List<TaskItem> _allTasks = [];
  bool _isLoading = true;
  bool _hasError = false;

  // While true, incoming stream snapshots are ignored so a background
  // write (from reordering/sorting/toggling) can't rebuild the list
  // out from under an in-progress user interaction.
  bool _suppressStreamUpdates = false;

  @override
  void initState() {
    super.initState();

    // 1. רישום המסך כמאזין למחזור החיים של האפליקציה
    WidgetsBinding.instance.addObserver(this);

    _subscribeToTasks();

    // 2. הפעלה ראשונית של בדיקות הבוקר (למקרה של פתיחה מחדש - Cold Start)
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

  @override
  void dispose() {
    _tasksSub?.cancel();
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
    // מנקה משימות שהושלמו אתמול
    context.read<TaskService>().clearCompletedTasks();
    // בודק ומחיל קנסות על משימות שפג תוקפן
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

    for (var task in _allTasks) {
      if (task.isCompleted) {
        completedTasks.add(task);
      } else if (task.isGolden) {
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

    return Column(
      children: [
        const Padding(padding: EdgeInsets.all(16.0), child: XpBar()),
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
                    // קריאה לווידג'ט המופרד שלנו!
                    child: TaskCard(
                      key: Key(goldenTask.id),
                      task: goldenTask,
                      onTap: () => _showTaskDetails(context, goldenTask),
                      onToggleGolden: () =>
                          _toggleGolden(goldenTask!, _allTasks),
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
                          // קריאה נוספת לווידג'ט
                          key: Key(task.id),
                          task: task,
                          onTap: () => _showTaskDetails(context, task),
                          onToggleGolden: () => _toggleGolden(task, _allTasks),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),

            children: activeTasks
                .map(
                  (task) => TaskCard(
                    // וקריאה אחרונה לווידג'ט
                    key: Key(task.id),
                    task: task,
                    onTap: () => _showTaskDetails(context, task),
                    onToggleGolden: () => _toggleGolden(task, _allTasks),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
