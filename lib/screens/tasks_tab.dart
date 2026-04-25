import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/category_item.dart';
import '../widgets/todo_card.dart';
import '../widgets/dialogs/task_dialog.dart';
import '../services/task_service.dart';

class TasksTab extends StatefulWidget {
  final List<TodoItem> tasks;
  final List<CategoryItem> categories;
  final bool isRituals;
  final Future<void> Function(TodoItem, bool isNew) onTaskSaved;
  final Future<void> Function(String id) onTaskDeleted;
  final VoidCallback onChanged;

  const TasksTab({
    super.key,
    required this.tasks,
    required this.categories,
    required this.isRituals,
    required this.onTaskSaved,
    required this.onTaskDeleted,
    required this.onChanged,
  });

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  List<TodoItem> get _filtered => widget.tasks
      .where((t) => widget.isRituals
          ? t.recurrence != RecurrenceType.none
          : t.recurrence == RecurrenceType.none)
      .toList();

  void _showTaskDialog({TodoItem? todo}) {
    final isNew = todo == null;
    showDialog(
      context: context,
      builder: (_) => TaskDialog(
        todo: todo,
        isRitual: widget.isRituals,
        categories: widget.categories,
        onSave: (saved) {
          if (isNew) widget.tasks.insert(0, saved);
          widget.onTaskSaved(saved, isNew);
        },
        onDelete: todo != null
            ? () {
                widget.tasks.removeWhere((t) => t.id == todo.id);
                widget.onTaskDeleted(todo.id);
              }
            : null,
      ),
    );
  }

  void _toggleGolden(TodoItem todo) {
    if (todo.isGolden) {
      todo.isGolden = false;
    } else {
      for (var t in widget.tasks) t.isGolden = false;
      todo.isGolden = true;
    }
    widget.onTaskSaved(todo, false);
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final golden = all.where((t) => t.isGolden).toList();
    final others = all.where((t) => !t.isGolden).toList();

    return Scaffold(
      body: Column(
        children: [
          // Sort button (tasks only)
          if (!widget.isRituals)
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: 'מיון חד פעמי',
                onSelected: (value) {
                  final golden = widget.tasks.where((t) => t.isGolden).toList();
                  final regular = widget.tasks
                      .where((t) => !t.isGolden && t.recurrence == RecurrenceType.none)
                      .toList();
                  final rituals = widget.tasks
                      .where((t) => t.recurrence != RecurrenceType.none)
                      .toList();
                  final sorted = value == 'level'
                      ? TaskService.sortByLevel(regular)
                      : TaskService.sortByDueDate(regular);
                  widget.tasks
                    ..clear()
                    ..addAll(golden)
                    ..addAll(sorted)
                    ..addAll(rituals);
                  widget.onChanged();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'level', child: Row(children: [
                    Icon(Icons.bar_chart, size: 18), SizedBox(width: 8), Text('מיין לפי רמה'),
                  ])),
                  PopupMenuItem(value: 'date', child: Row(children: [
                    Icon(Icons.calendar_today, size: 18), SizedBox(width: 8), Text('מיין לפי תאריך'),
                  ])),
                ],
              ),
            ),

          // Golden task
          if (!widget.isRituals && golden.isNotEmpty) ...[
            TodoCard(
              todo: golden.first,
              category: widget.categories.where((c) => c.id == golden.first.categoryId).firstOrNull,
              onToggle: () {
                golden.first.isCompleted = !golden.first.isCompleted;
                widget.onTaskSaved(golden.first, false);
              },
              onEdit: () => _showTaskDialog(todo: golden.first),
              onDelete: () {
                widget.tasks.removeWhere((t) => t.id == golden.first.id);
                widget.onTaskDeleted(golden.first.id);
              },
              onToggleGolden: () => _toggleGolden(golden.first),
            ),
            const Divider(),
          ],

          // Task list
          Expanded(
            child: ReorderableListView.builder(
              itemCount: others.length,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = others.removeAt(oldIdx);
                widget.tasks.remove(item);
                final insertAt = widget.tasks.indexWhere(
                    (t) => t.id == (others.isEmpty ? null : others.first.id));
                widget.tasks.insert(insertAt < 0 ? 0 : insertAt, item);
                widget.onChanged();
              },
              itemBuilder: (context, index) => ReorderableDragStartListener(
                key: ValueKey(others[index].id),
                index: index,
                child: TodoCard(
                  todo: others[index],
                  category: widget.categories
                      .where((c) => c.id == others[index].categoryId)
                      .firstOrNull,
                  onToggle: () {
                    others[index].isCompleted = !others[index].isCompleted;
                    widget.onTaskSaved(others[index], false);
                  },
                  onEdit: () => _showTaskDialog(todo: others[index]),
                  onDelete: () {
                    widget.tasks.removeWhere((t) => t.id == others[index].id);
                    widget.onTaskDeleted(others[index].id);
                  },
                  onToggleGolden: () => _toggleGolden(others[index]),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}