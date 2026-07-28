import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';
import '../services/gamification_service.dart';
import 'pokemon_pull_dialog.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggleGolden;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleGolden,
  });

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();
    // קריאה לשירות הגיימיפיקציה שלנו כדי להשתמש בו בלחיצה
    final gamificationService = context.read<GamificationService>();

    bool isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: task.isCompleted ? Colors.grey.shade800.withOpacity(0.5) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2.0)
            : task.isGolden
            ? const BorderSide(color: Colors.amber, width: 2.0)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (bool? value) async {
                  bool isNowCompleted = value ?? false;

                  if (isNowCompleted && !task.isCompleted) {
                    // Wait for the service to calculate rewards and return a potential pulled ID
                    int? pulledId = await gamificationService
                        .processTaskCompletion(task);

                    // If we got a new ID and the screen is still active, show the dialog!
                    if (pulledId != null && context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            PokemonPullDialog(pokemonId: pulledId),
                      );
                    }
                  }

                  task.isCompleted = isNowCompleted;
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
