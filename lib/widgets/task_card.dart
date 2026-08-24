import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../services/task_service.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggleGolden;
  final Function(bool) onStatusChanged;
  final CategoryItem? category;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleGolden,
    required this.onStatusChanged,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final taskService = context.read<TaskService>();

    bool isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.isCompleted;

    // חישוב כמות תתי-המשימות שהושלמו
    int completedSubTasksCount = task.subTasks
        .where((s) => s.isCompleted)
        .length;
    int totalSubTasks = task.subTasks.length;

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- שורה 1: המשימה הראשית ---
                      Row(
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            onChanged: (bool? value) {
                              bool isNowCompleted = value ?? false;
                              if (isNowCompleted) {
                                // וידוא שכל תתי-המשימות הושלמו
                                bool hasOpenSubTasks = task.subTasks.any(
                                  (subTask) => !subTask.isCompleted,
                                );

                                if (hasOpenSubTasks) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'יש להשלים קודם את כל תתי-המשימות!',
                                        textAlign: TextAlign.right,
                                      ),
                                      backgroundColor: Colors.redAccent,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                              }
                              onStatusChanged(isNowCompleted);
                            },
                            activeColor: Colors.amber,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
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
                                // הצגת חיווי ההתקדמות רק אם יש תתי-משימות
                                if (task.subTasks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      '$completedSubTasksCount/$totalSubTasks הושלמו',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                              ],
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
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                            ),
                            onPressed: onTap,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
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
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text(
                                          'ביטול',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                        ),
                                        onPressed: () {
                                          taskService.deleteTask(task.id);
                                          Navigator.of(context).pop();
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

                      // --- שורה 2: רשימת תתי-המשימות ---
                      // --- שורה 2: רשימת תתי-המשימות (עד 2 בלבד במסך הבית) ---
                      if (task.subTasks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: 48.0,
                            left: 8.0,
                            bottom: 4.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // מציג אך ורק את 2 תתי-המשימות הראשונות
                              ...task.subTasks.take(2).map((subTask) {
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: subTask.isCompleted,
                                        onChanged: (bool? val) {
                                          subTask.isCompleted = val ?? false;
                                          taskService.saveTask(task);
                                        },
                                        activeColor: Colors.blueAccent,
                                        checkColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        subTask.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subTask.isCompleted
                                              ? Colors.grey
                                              : Colors.white70,
                                          decoration: subTask.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),

                              // אם יש יותר מ-2 תתי-משימות, נציג חיווי קטן
                              if (task.subTasks.length > 2)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4.0,
                                    right: 32.0,
                                  ),
                                  child: Text(
                                    'ועוד ${task.subTasks.length - 2} תתי-משימות נוספות (צפה בעריכה)...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
