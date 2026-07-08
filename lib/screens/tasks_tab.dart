import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../widgets/task_card.dart';
import '../widgets/dialogs/task_dialog.dart';
import '../services/task_service.dart';

class TasksTab extends StatefulWidget {
  final List<TaskItem> tasks;
  final List<CategoryItem> categories;
  final Future<void> Function(TaskItem, bool isNew) onTaskSaved;
  final Future<void> Function(String id) onTaskDeleted;
  final VoidCallback onChanged;

  const TasksTab({
    super.key,
    required this.tasks,
    required this.categories,
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

  void _sortTasks(bool byLevel) {
    setState(() {
      final sorted = byLevel
          ? TaskService.sortByLevel(widget.tasks)
          : TaskService.sortByDueDate(widget.tasks);

      widget.tasks.clear();
      widget.tasks.addAll(sorted);
    });
    widget.onChanged();
  }

  List<TaskItem> get _filtered {
    List<TaskItem> list = List.from(widget.tasks);
    list.sort((a, b) {
      // 1. קודם כל: משימות שהושלמו יורדות לסוף הרשימה
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;

      // 2. משימת הזהב תמיד תהיה בראש הרשימה! (מופרדת ומעל כולם)
      if (a.isGolden && !b.isGolden) return -1;
      if (!a.isGolden && b.isGolden) return 1;

      // 3. שאר המשימות שומרות על הסדר שלהן כדי לאפשר גרירה
      return 0;
    });
    return list;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showTaskDialog({TaskItem? task}) {
    final isNew = task == null;
    showDialog(
      context: context,
      builder: (context) => TaskDialog(
        task: task,
        categories: widget.categories,
        onSave: (savedTask) async {
          await widget.onTaskSaved(savedTask, isNew);
          if (isNew) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToTop();
            });
          }
        },
        onDelete: () {
          if (task != null) {
            widget.onTaskDeleted(task.id);
          }
        },
      ),
    );
  }

  void _toggleGolden(TaskItem task) {
    bool isTurningGolden = !task.isGolden;

    if (isTurningGolden) {
      // אם אנחנו מסמנים משימה כ"מוזהבת", נוודא שהיא ייחודית
      // נרוץ על כל המשימות ונבטל את הזהב מהשאר
      for (var t in widget.tasks) {
        if (t.isGolden && t.id != task.id) {
          t.isGolden = false;
          widget.onTaskSaved(t, false);
        }
      }
    }

    task.isGolden = isTurningGolden;
    widget.onTaskSaved(task, false);

    // רענון המסך כדי שהמשימה תקפוץ מיד למעלה
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final others = _filtered;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'המשימות שלי',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'מיין משימות',
                  onSelected: (value) {
                    if (value == 'level') _sortTasks(true);
                    if (value == 'date') _sortTasks(false);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'level',
                      child: Text('מיין לפי רמה'),
                    ),
                    const PopupMenuItem(
                      value: 'date',
                      child: Text('מיין לפי תאריך'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: _scrollController,
              itemCount: others.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  // 1. שומרים את המשימה שאנחנו גוררים כרגע
                  final item = others[oldIndex];

                  // 2. בודקים איזו משימה יושבת במיקום שבו אנחנו רוצים לנחות
                  TaskItem? referenceItem;
                  if (newIndex < others.length) {
                    referenceItem = others[newIndex];
                  }

                  // 3. מסירים את המשימה שנגררת מהרשימה המקורית
                  widget.tasks.remove(item);

                  // 4. מכניסים אותה בחזרה בדיוק במקום הנכון (לפני ה-referenceItem)
                  if (referenceItem != null) {
                    int insertIndex = widget.tasks.indexOf(referenceItem);
                    if (insertIndex != -1) {
                      widget.tasks.insert(insertIndex, item);
                    } else {
                      widget.tasks.add(item);
                    }
                  } else {
                    // מקרה קצה: נגרר עד לסוף הרשימה (מתחת לכולם)
                    widget.tasks.add(item);
                  }

                  widget.onChanged();
                });
              },
              itemBuilder: (context, index) {
                final currentTask = others[index];

                // --- הפתרון לקריסה ---
                // מייצרים מפתח חכם: מחברים את ה-ID הרגיל עם ה-ID של הפרויקט.
                // אם ה-ID ריק לגמרי (בגלל נתונים ישנים), נשתמש במיקום שלו ברשימה כמפתח זמני.
                final safeKey = currentTask.id.isNotEmpty
                    ? '${currentTask.id}_${currentTask.projectId ?? "regular"}'
                    : 'fallback_id_$index';

                return ReorderableDelayedDragStartListener(
                  key: ValueKey(safeKey), // שימוש במפתח החסין שיצרנו
                  index: index,
                  child: TaskCard(
                    task: currentTask,
                    category: widget.categories
                        .where((c) => c.id == currentTask.categoryId)
                        .firstOrNull,
                    onToggle: () {
                      bool isNowCompleted = !currentTask.isCompleted;
                      currentTask.isCompleted = isNowCompleted;

                      if (isNowCompleted && currentTask.isGolden) {
                        currentTask.isGolden = false;
                      }

                      widget.onTaskSaved(currentTask, false);
                      setState(() {});
                    },
                    onEdit: () => _showTaskDialog(task: currentTask),
                    onDelete: () {
                      widget.tasks.removeWhere((t) => t.id == currentTask.id);
                      widget.onTaskDeleted(currentTask.id);
                    },
                    onToggleGolden: () => _toggleGolden(currentTask),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
