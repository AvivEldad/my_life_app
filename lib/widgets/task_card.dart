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
          Row(
            children: [
              Text(
                'רמה: ${task.level}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (task.projectName != null) ...[
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
                const SizedBox(width: 8),
              ],
              if (category != null) ...[
                Icon(Icons.label, size: 14, color: stripeColor ?? Colors.grey),
                const SizedBox(width: 4),
                Text(category!.name, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
              ],
              if (task.dueDate != null) ...[
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${task.dueDate!.day}/${task.dueDate!.month}',
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              task.isGolden
                  ? Icons.monetization_on
                  : Icons.monetization_on_outlined,
              color: task.isGolden ? Colors.amber : Colors.grey,
            ),
            onPressed: onToggleGolden,
          ),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
            onPressed: onDelete,
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
