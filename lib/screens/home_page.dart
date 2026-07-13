import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import 'task_details_screen.dart';

enum TaskSort { level, date } // הורדנו את המצב הידני, זה תמיד ידני!

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

  // פונקציה שמסדרת את המשימות לפי בקשת המשתמש ושומרת מיד ל-Firebase
  void _applySort(
    TaskSort sortType,
    List<TaskItem> activeTasks,
    TaskService taskService,
  ) async {
    // ממיינים לוקאלית
    if (sortType == TaskSort.level) {
      activeTasks.sort((a, b) => b.level.compareTo(a.level));
    } else if (sortType == TaskSort.date) {
      activeTasks.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ); // תאריך יצירה יורד
    }

    // רצים על הרשימה ומעדכנים את המספר (orderIndex) של כולם במסד הנתונים
    for (int i = 0; i < activeTasks.length; i++) {
      if (activeTasks[i].orderIndex != i) {
        // שומרים רק אם באמת צריך לשנות
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

          // תמיד ממיינים לפי אינדקס الجרירה! המשתמש שולט בסדר.
          activeTasks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

          return Column(
            children: [
              // שורת כפתורי סינון (במקום בתפריט הראשי)
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
                  // משימת הזהב נשארת צמודה למעלה, אבל עכשיו עם מסגרת בלבד
                  header: goldenTask != null
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildTaskCard(
                            context,
                            goldenTask,
                            allTasks,
                            taskService,
                            key: Key(goldenTask.id),
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
                              (task) => _buildTaskCard(
                                context,
                                task,
                                allTasks,
                                taskService,
                                key: Key(task.id),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),

                  children: activeTasks
                      .map(
                        (task) => _buildTaskCard(
                          context,
                          task,
                          allTasks,
                          taskService,
                          key: Key(task.id),
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

  Widget _buildTaskCard(
    BuildContext context,
    TaskItem task,
    List<TaskItem> allTasks,
    TaskService taskService, {
    Key? key,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8.0),
      color: task.isCompleted ? Colors.grey.shade800.withOpacity(0.5) : null,
      // הנה הקסם! אם זו משימת זהב, היא מקבלת מסגרת בצבע ענבר בעובי 2
      shape: task.isGolden
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.amber, width: 2.0),
              borderRadius: BorderRadius.circular(12.0),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () => _showTaskDetails(context, task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (bool? value) {
                  task.isCompleted = value ?? false;
                  taskService.saveTask(task);
                },
                activeColor: Colors.amber,
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.isCompleted ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              // כפתור הזהב
              IconButton(
                icon: Icon(
                  task.isGolden ? Icons.star : Icons.star_border,
                  color: task.isGolden ? Colors.amber : Colors.grey,
                ),
                onPressed: () => _toggleGolden(task, allTasks, taskService),
              ),
              // כפתור עריכה (עיפרון)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () => _showTaskDetails(context, task),
              ),
              // כפתור מחיקה (פח אשפה)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => taskService.deleteTask(task.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
