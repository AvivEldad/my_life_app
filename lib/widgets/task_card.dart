import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap; // פונקציה שתופעל כשלוחצים על המשימה (לפתיחת עריכה)
  final VoidCallback onToggleGolden; // פונקציה שתופעל כשלוחצים על כפתור הזהב

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleGolden,
  });

  @override
  Widget build(BuildContext context) {
    // השתמשנו ב-Provider כדי למשוך את שירות המשימות ישירות לתוך הווידג'ט
    final taskService = context.read<TaskService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: task.isCompleted ? Colors.grey.shade800.withOpacity(0.5) : null,
      shape: task.isGolden
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.amber, width: 2.0),
              borderRadius: BorderRadius.circular(12.0),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (bool? value) {
                  task.isCompleted = value ?? false;
                  taskService.saveTask(task); // שומר ישירות ל-Firebase!
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
              IconButton(
                icon: Icon(
                  task.isGolden ? Icons.star : Icons.star_border,
                  color: task.isGolden ? Colors.amber : Colors.grey,
                ),
                onPressed: onToggleGolden,
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: onTap,
              ),
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
