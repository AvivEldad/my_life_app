import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Added Provider import
import '../models/todo_item.dart';
import '../models/category_item.dart';
import '../services/coin_service.dart';

class TodoCard extends StatelessWidget {
  final TodoItem todo; // Your variable is 'todo'
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleGolden;

  final CategoryItem? category;

  const TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleGolden,
    this.category,
  });

  String _getRecurrenceDetails(TodoItem item, BuildContext context) {
    String time = item.reminderTime?.format(context) ?? "";
    switch (item.recurrence) {
      case RecurrenceType.daily: return 'כל יום ב-$time';
      case RecurrenceType.weekly:
        List<String> days = ['', 'א\'', 'ב\'', 'ג\'', 'ד\'', 'ה\'', 'ו\'', 'ש\''];
        return 'כל יום ${days[item.repeatValue ?? 1]} ב-$time';
      case RecurrenceType.monthly:
        return 'ב-${item.repeatValue} לכל חודש ב-$time';
      default: return '';
    }
  }

  // Updated function: Uses 'todo' instead of 'task' and only requires context
  void _onTaskCheckboxToggled(BuildContext context) {
    final coinService = Provider.of<CoinService>(context, listen: false);

    // 1. Check if we are checking it off as COMPLETED
    final enteringCompletion = !todo.isCompleted;

    // 2. Use the task details to run the calculation logic
    final rewardAmount = coinService.calculateStandardTaskReward(
      level: todo.level,       
      isGolden: todo.isGolden, 
      dueDate: todo.dueDate,   
    );
    
    // 3. Calculate XP
    final xpAmount = coinService.calculateTaskXP(
      level: todo.level,
      isGolden: todo.isGolden,
    );

    // 4. Process the wallet balance adjusters
    if (enteringCompletion) {
      coinService.addCoins(rewardAmount);
      coinService.addXP(xpAmount);
    } else {
      // Refund/deduct what was granted if toggled back down
      coinService.deductCoins(rewardAmount);
    }

    // 5. Trigger the parent save sequence (flips the visual checkmark and saves to DB)
    onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final stripeColor = category?.color;

    final tile = ListTile(
        onTap: onEdit,
        // Linked the Checkbox to our new function!
        leading: Checkbox(
          value: todo.isCompleted, 
          onChanged: (_) => _onTaskCheckboxToggled(context), 
          activeColor: Colors.amber
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
              Text(todo.description!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Row(
              children: [
                Text('רמה: ${todo.level}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                if (todo.recurrence != RecurrenceType.none)
                  Text(_getRecurrenceDetails(todo, context), style: const TextStyle(fontSize: 12, color: Colors.blueAccent))
                else if (todo.dueDate != null)
                  Text('עד: ${todo.dueDate!.day}/${todo.dueDate!.month}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (todo.recurrence == RecurrenceType.none)
              IconButton(
                icon: Icon(todo.isGolden ? Icons.monetization_on : Icons.monetization_on_outlined, color: todo.isGolden ? Colors.amber : Colors.grey),
                onPressed: onToggleGolden,
              ),
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent), onPressed: onDelete),
          ],
        ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: todo.isGolden ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
      ),
      elevation: todo.isGolden ? 8 : 1,
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