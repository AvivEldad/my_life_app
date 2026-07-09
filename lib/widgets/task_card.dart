import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleGolden;
  final CategoryItem? category;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleGolden,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    Color? stripeColor = category?.color;

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (v) => onToggle(),
        activeColor: Colors.amber,
        shape: const CircleBorder(),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.description != null && task.description!.isNotEmpty) ...[
            Text(task.description!, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
          ],
          // --- כאן החלפנו את ה-Row ב-Wrap כדי לפתור את בעיית הגלישה! ---
          Wrap(
            spacing: 12.0, // הרווח האופקי בין הפריטים
            runSpacing: 4.0, // הרווח האנכי כשהפריטים יורדים לשורה חדשה
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'רמה: ${task.level}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (task.projectName != null)
                Row(
                  mainAxisSize: MainAxisSize.min, // מחזיק את האייקון והטקסט יחד
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.projectName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (category != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.label,
                      size: 14,
                      color: stripeColor ?? Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(category!.name, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              if (task.dueDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task.dueDate!.day}/${task.dueDate!.month}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // צמצמנו את הכפתורים בצד כדי שיתפסו פחות מקום במסך
          IconButton(
            icon: Icon(
              task.isGolden
                  ? Icons.monetization_on
                  : Icons.monetization_on_outlined,
              color: task.isGolden ? Colors.amber : Colors.grey,
              size: 20,
            ),
            onPressed: onToggleGolden,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: task.isGolden
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      elevation: task.isGolden ? 8 : 1,
      clipBehavior: Clip.antiAlias,
      child: stripeColor == null
          ? tile
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: stripeColor),
                  Expanded(child: tile),
                ],
              ),
            ),
    );
  }
}
