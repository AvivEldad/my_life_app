import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleGolden;

  const TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleGolden,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: todo.isGolden 
            ? const BorderSide(color: Colors.amber, width: 2) 
            : BorderSide.none,
      ),
      elevation: todo.isGolden ? 8 : 1,
      child: ListTile(
        onTap: onEdit,
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => onToggle(),
          activeColor: Colors.amber,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            fontWeight: todo.isGolden ? FontWeight.bold : FontWeight.normal,
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('רמה: ${todo.level}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                todo.isGolden ? Icons.monetization_on : Icons.monetization_on_outlined,
                color: todo.isGolden ? Colors.amber : Colors.grey,
              ),
              onPressed: onToggleGolden,
            ),
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}