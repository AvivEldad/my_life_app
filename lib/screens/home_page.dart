import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import '../widgets/task_card.dart';
import 'task_details_screen.dart';
import '../widgets/app_drawer.dart';

enum TaskSort { level, date }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _showTaskDetails(BuildContext context, TaskItem? task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskDetailsScreen(task: task)),
    );
  }

  void _toggleGolden(
    TaskItem task,
    List<TaskItem> allTasks,
    TaskService taskService,
  ) async {
    if (!task.isGolden) {
      for (var t in allTasks) {
        if (t.isGolden && t.id != task.id) {
          t.isGolden = false;
          await taskService.saveTask(t);
        }
      }
      task.isGolden = true;
    } else {
      task.isGolden = false;
    }
    await taskService.saveTask(task);
  }

  void _applySort(
    TaskSort sortType,
    List<TaskItem> activeTasks,
    TaskService taskService,
  ) async {
    if (sortType == TaskSort.level) {
      activeTasks.sort((a, b) => b.level.compareTo(a.level));
    } else if (sortType == TaskSort.date) {
      activeTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    for (int i = 0; i < activeTasks.length; i++) {
      if (activeTasks[i].orderIndex != i) {
        activeTasks[i].orderIndex = i;
        await taskService.saveTask(activeTasks[i]);
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

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();

    return Scaffold(
      appBar: AppBar(title: const Text('המשימות שלי'), centerTitle: true),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<TaskItem>>(
        stream: taskService.streamTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('שגיאה בטעינת משימות.'));
          }

          final allTasks = snapshot.data ?? [];

          if (allTasks.isEmpty) {
            return const Center(
              child: Text('אין משימות. לחץ על + כדי להוסיף.'),
            );
          }

          TaskItem? goldenTask;
          List<TaskItem> activeTasks = [];
          List<TaskItem> completedTasks = [];

          for (var task in allTasks) {
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.sort, size: 18),
                      label: const Text('מיין לפי רמה'),
                      onPressed: () =>
                          _applySort(TaskSort.level, activeTasks, taskService),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('מיין לפי תאריך'),
                      onPressed: () =>
                          _applySort(TaskSort.date, activeTasks, taskService),
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
                            onToggleGolden: () => _toggleGolden(
                              goldenTask!,
                              allTasks,
                              taskService,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),

                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = activeTasks.removeAt(oldIndex);
                      activeTasks.insert(newIndex, item);

                      for (int i = 0; i < activeTasks.length; i++) {
                        activeTasks[i].orderIndex = i;
                        taskService.saveTask(activeTasks[i]);
                      }
                    });
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
                                onToggleGolden: () =>
                                    _toggleGolden(task, allTasks, taskService),
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
                          onToggleGolden: () =>
                              _toggleGolden(task, allTasks, taskService),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDetails(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
