import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../services/task_service.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggleGolden;
  final Function(bool) onStatusChanged; // הוספנו פונקציית דיווח חדשה
  final CategoryItem? category;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleGolden,
    required this.onStatusChanged, // חובה לספק אותה בעת יצירת הכרטיס
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();

    bool isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      color: task.isCompleted ? Colors.grey.shade800.withOpacity(0.5) : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2.0)
            : task.isGolden
            ? const BorderSide(color: Colors.amber, width: 2.0)
            : BorderSide.none,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (category != null) Container(width: 6, color: category!.color),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: task.isCompleted,
                        // כאן הכרטיס רק מדווח החוצה שנלחץ! הוא לא מנהל שום לוגיקה.
                        onChanged: (bool? value) {
                          onStatusChanged(value ?? false);
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
                            color: task.isCompleted
                                ? Colors.grey
                                : Colors.white,
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
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          // הצגת חלון אישור לפני מחיקה
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: Colors.grey.shade900,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                title: const Text(
                                  'מחיקת משימה',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: const Text(
                                  'האם אתה בטוח שברצונך למחוק את המשימה?',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  // כפתור ביטול
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                      ).pop(); // סגירת החלון
                                    },
                                    child: const Text(
                                      'ביטול',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  // כפתור אישור מחיקה
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      // ביצוע המחיקה בפועל דרך השירות
                                      taskService.deleteTask(task.id);
                                      Navigator.of(
                                        context,
                                      ).pop(); // סגירת החלון
                                    },
                                    child: const Text(
                                      'מחק',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
