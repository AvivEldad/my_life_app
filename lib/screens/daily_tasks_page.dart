import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/daily_task_service.dart';
import '../services/gamification_service.dart';
import '../models/daily_task_item.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

class DailyTasksPage extends StatefulWidget {
  const DailyTasksPage({super.key});

  @override
  State<DailyTasksPage> createState() => _DailyTasksPageState();
}

class _DailyTasksPageState extends State<DailyTasksPage> {
  @override
  void initState() {
    super.initState();
    // Trigger the midnight reset check as soon as the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gamification = context.read<GamificationService>();
      context.read<DailyTaskService>().processMidnightReset(gamification);
    });
  }

  void _showAddTaskDialog(BuildContext context) {
    final textController = TextEditingController();
    final dailyTaskService = context.read<DailyTaskService>();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text(
              'רשימה יומית',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'כלים\nכביסה\nלעשות ספורט...',
                hintStyle: TextStyle(color: Colors.grey),
                labelText: 'הכנס משימות ',
                labelStyle: TextStyle(color: Colors.amber),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.amber),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ביטול',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  if (textController.text.isNotEmpty) {
                    dailyTaskService.saveMultipleTasks(textController.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'שמור',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('רשימה יומית 📝'), centerTitle: true),
        drawer: const AppDrawer(),

        body: StreamBuilder<List<DailyTaskItem>>(
          stream: context.read<DailyTaskService>().streamTodayTasks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = snapshot.data ?? [];

            if (tasks.isEmpty) {
              return const Center(
                child: Text(
                  'הכל נקי ומסודר להיום!\nלחץ על ה- + כדי להוסיף משימות.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  color: Colors.grey.shade800,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      activeColor: Colors.amber,
                      checkColor: Colors.black,
                      onChanged: (val) {
                        context.read<DailyTaskService>().toggleTaskCompletion(
                          task,
                        );
                      },
                    ),
                    title: Text(
                      task.summary,
                      style: TextStyle(
                        color: task.isCompleted ? Colors.grey : Colors.white,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => context
                          .read<DailyTaskService>()
                          .deleteSingleTask(task.id),
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.amber,
          onPressed: () => _showAddTaskDialog(context),
          child: const Icon(Icons.add, color: Colors.black),
        ),
        bottomNavigationBar: BottomNavigationBar(
          unselectedItemColor: Colors.grey,
          selectedItemColor: Colors.grey,
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
          onTap: (index) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainLayout(initialIndex: index),
              ),
            );
          },
        ),
      ),
    );
  }
}
