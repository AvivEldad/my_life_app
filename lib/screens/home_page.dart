import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // אתחול פשוט של ה-Service בלי צורך במזהה משתמש יותר!
  final TaskService _taskService = TaskService();

  // פונקציה ליצירת משימה חדשה
  void _addTestTask() async {
    final String newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTask = TaskItem(id: newId, title: 'משימה חדשה', level: 1);
    await _taskService.saveTask(newTask);
  }

  // פונקציית העריכה! מקפיצה חלון קופץ לשינוי שם המשימה
  void _editTask(TaskItem task) {
    TextEditingController controller = TextEditingController(text: task.title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ערוך משימה'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "הכנס שם חדש למשימה"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // סגירת החלון בלי לשמור
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                // עדכון המודל עם השם החדש
                task.title = controller.text;
                // קריאה לפונקציית השמירה (שכאמור, מבצעת עריכה כי ה-ID כבר קיים)
                await _taskService.saveTask(task);

                if (mounted) Navigator.pop(context); // סגירת החלון אחרי השמירה
              },
              child: const Text('שמור שינויים'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gamified Tasks'), centerTitle: true),
      body: StreamBuilder<List<TaskItem>>(
        stream: _taskService.streamTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('אופס! שגיאה בטעינת המשימות.'));
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
              child: Text('אין משימות. לחץ על + כדי להוסיף.'),
            );
          }

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(task.title),
                  subtitle: Text('רמה: ${task.level}'),
                  // Row מאפשר לנו לשים גם כפתור מחיקה וגם כפתור עריכה בשורה אחת
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // כפתור עריכה
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _editTask(task),
                      ),
                      // כפתור מחיקה
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _taskService.deleteTask(task.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTestTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}
