import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleGolden;
  final bool isLocked;

  const TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onToggleGolden,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: todo.isGolden ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
        ),
        child: ListTile(
          onTap: isLocked ? null : onEdit,
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: isLocked ? null : (_) => onToggle(),
            activeColor: Colors.amber,
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              fontWeight: todo.isGolden ? FontWeight.bold : FontWeight.normal,
              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.description != null && todo.description!.isNotEmpty)
                Text(todo.description!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Row(
                children: [
                  Text('רמה: ${todo.level}', style: const TextStyle(fontSize: 11, color: Colors.amber)),
                  if (todo.dueDate != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${todo.dueDate!.day}/${todo.dueDate!.month}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),
            ],
          ),
          trailing: isLocked ? const Icon(Icons.lock_outline) : IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: onDelete),
        ),
      ),
    );
  }
}