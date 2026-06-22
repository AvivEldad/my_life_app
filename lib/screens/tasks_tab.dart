import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../widgets/task_card.dart';
import '../widgets/dialogs/task_dialog.dart';
import '../services/task_service.dart';

class TasksTab extends StatefulWidget {
  final List<TaskItem> tasks;
  final List<CategoryItem> categories;
  final bool isRituals;
  final Future<void> Function(TaskItem, bool isNew) onTaskSaved;
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
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  List<TaskItem> get _filtered {
    // 1. קודם כל מסננים את הרשימה לפי טקסים או משימות רגילות
    List<TaskItem> list = widget.tasks
        .where((t) => widget.isRituals
            ? t.recurrence != RecurrenceType.none
            : t.recurrence == RecurrenceType.none)
        .toList();

    // 2. ממיינים את הרשימה כך שמשימות שהושלמו תמיד ירדו לסוף
    list.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      return 0; // משאיר את שאר המשימות בסדר הרגיל שלהן (כדי לא לפגוע בגרירה)
    });

    return list;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // מיקום 0 שזה הכי למעלה
        duration: const Duration(milliseconds: 500), // משך האנימציה (חצי שנייה)
        curve: Curves.easeInOut, // סוג תנועת האנימציה
      );
    }
  }

  void _showTaskDialog({TaskItem? task}) {
    final isNew = task == null;
    showDialog(
      context: context,
      builder: (_) => TaskDialog(
        task: task,
        isRitual: widget.isRituals,
        categories: widget.categories,
        onSave: (saved) {
          if (isNew) widget.tasks.insert(0, saved);
          widget.onTaskSaved(saved, isNew);
          if (isNew) {
            // המערכת מחכה שהפריט החדש יתרנדר על המסך (בפריים הבא), ואז גוללת למעלה
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToTop();
            });
          }
        },
        onDelete: task != null
            ? () {
                widget.tasks.removeWhere((t) => t.id == task.id);
                widget.onTaskDeleted(task.id);
              }
            : null,
      ),
    );
  }

  void _toggleGolden(TaskItem task) {
    if (task.isGolden) {
      task.isGolden = false;
    } else {
      for (var t in widget.tasks) t.isGolden = false;
      task.isGolden = true;
    }
    widget.onTaskSaved(task, false);
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
            TaskCard(
              task: golden.first,
              category: widget.categories.where((c) => c.id == golden.first.categoryId).firstOrNull,
              onToggle: () {
                golden.first.isCompleted = !golden.first.isCompleted;
                widget.onTaskSaved(golden.first, false);
              },
              onEdit: () => _showTaskDialog(task: golden.first),
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
              physics: const AlwaysScrollableScrollPhysics(),
              scrollController: _scrollController,
              itemCount: others.length,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = others.removeAt(oldIdx);
                others.insert(newIdx, item);
                widget.tasks.remove(item);
                int insertAt = -1;
                if (newIdx + 1 < others.length) {
                  final nextItem = others[newIdx + 1];
                  insertAt = widget.tasks.indexWhere((t) => t.id == nextItem.id);
                } 
                else if (newIdx > 0) {
                  final prevItem = others[newIdx - 1];
                  final prevIndex = widget.tasks.indexWhere((t) => t.id == prevItem.id);
                  if (prevIndex != -1) {
                    insertAt = prevIndex + 1; // Insert right after the previous item
                  }
                }
                if (insertAt >= 0 && insertAt <= widget.tasks.length) {
                  widget.tasks.insert(insertAt, item);
                } else {
                  widget.tasks.add(item); 
                }
                widget.onChanged();
              },
              itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
                key: ValueKey(others[index].id),
                index: index,
                child: TaskCard(
                  task: others[index],
                  category: widget.categories
                      .where((c) => c.id == others[index].categoryId)
                      .firstOrNull,
                  onToggle: () {
                    others[index].isCompleted = !others[index].isCompleted;
                    widget.onTaskSaved(others[index], false);
                  },
                  onEdit: () => _showTaskDialog(task: others[index]),
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