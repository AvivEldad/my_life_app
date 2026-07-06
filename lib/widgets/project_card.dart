import 'package:flutter/material.dart';
import '../models/project_item.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import 'dialogs/task_dialog.dart';
import 'dialogs/project_dialog.dart';

class ProjectCard extends StatelessWidget {
  final ProjectItem project;
  final bool isExpanded;
  final List<CategoryItem> categories;
  final VoidCallback onToggleExpand;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const ProjectCard({
    super.key,
    required this.project,
    required this.isExpanded,
    required this.categories,
    required this.onToggleExpand,
    required this.onDelete,
    required this.onChanged,
  });

  Color? get _stripeColor =>
      categories.where((c) => c.id == project.categoryId).firstOrNull?.color;

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ProjectDialog(
        project: project,
        categories: categories,
        onSave: (updated) => onChanged(),
        onDelete: onDelete,
      ),
    );
  }

  void _showSubtaskDialog(BuildContext context, {TaskItem? task}) {
    showDialog(
      context: context,
      builder: (_) => TaskDialog(
        task: task,
        categories: categories,
        onSave: (saved) {
          if (task == null) {
            project.subtasks.add(saved);
          } else {
            final idx = project.subtasks.indexWhere((t) => t.id == task.id);
            if (idx >= 0) project.subtasks[idx] = saved;
          }
          onChanged();
        },
      ),
    );
  }

  void _showAddNestedTaskDialog(BuildContext context, TaskItem parentTask) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'תת-משימה חדשה',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'הכנס שם לתת-המשימה'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                parentTask.subTasks.add(
                  SubTask(
                    id:
                        DateTime.now().millisecondsSinceEpoch.toString() +
                        UniqueKey().toString(),
                    title: ctrl.text.trim(),
                  ),
                );
                onChanged();
                Navigator.pop(ctx);
              }
            },
            child: const Text('הוסף'),
          ),
        ],
      ),
    );
  }

  void _showEditNestedTaskDialog(BuildContext context, SubTask nestedTask) {
    final TextEditingController ctrl = TextEditingController(
      text: nestedTask.title,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'עריכת תת-משימה',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                nestedTask.title = ctrl.text.trim();
                onChanged();
                Navigator.pop(ctx);
              }
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stripeColor = _stripeColor;

    int firstUncompletedIndex = -1;
    if (project.isSequential) {
      firstUncompletedIndex = project.subtasks.indexWhere(
        (t) => !t.isCompleted,
      );
    }

    final cardContent = Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Row(
            children: [
              // כפתור המנעול להחלפת הסטטוס
              IconButton(
                icon: Icon(
                  project.isSequential ? Icons.lock : Icons.lock_open,
                  color: project.isSequential ? Colors.amber : Colors.grey[400],
                  size: 20,
                ),
                tooltip: project.isSequential
                    ? 'פרויקט טורי (נעול)'
                    : 'פרויקט מקבילי (פתוח)',
                onPressed: () {
                  project.isSequential = !project.isSequential;
                  onChanged();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
              Expanded(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          subtitle:
              project.description != null && project.description!.isNotEmpty
              ? Text(project.description!)
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_task, color: Colors.blueAccent),
                onPressed: () => _showSubtaskDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditDialog(context),
              ),
              IconButton(
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                onPressed: onToggleExpand,
              ),
            ],
          ),
          onTap: onToggleExpand,
        ),
        if (isExpanded) ...[
          const Divider(height: 1),
          for (int i = 0; i < project.subtasks.length; i++) ...[
            Builder(
              builder: (context) {
                final subtask = project.subtasks[i];

                bool isTaskLocked =
                    project.isSequential &&
                    firstUncompletedIndex != -1 &&
                    i > firstUncompletedIndex;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── המשימה הראשית (Level 1) ───
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: subtask.isCompleted,
                            onChanged: isTaskLocked
                                ? null
                                : (v) {
                                    subtask.isCompleted = v ?? false;
                                    onChanged();
                                  },
                            shape: const CircleBorder(),
                            activeColor: Colors.amber,
                          ),
                          if (isTaskLocked)
                            const Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.grey,
                            ),
                          if (isTaskLocked) const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subtask.title,
                              style: TextStyle(
                                decoration: subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.bold,
                                color: isTaskLocked ? Colors.grey : null,
                              ),
                            ),
                          ),
                          if (i > 0)
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_up,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                final temp = project.subtasks[i];
                                project.subtasks[i] = project.subtasks[i - 1];
                                project.subtasks[i - 1] = temp;
                                onChanged();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28),
                            ),
                          if (i < project.subtasks.length - 1)
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                final temp = project.subtasks[i];
                                project.subtasks[i] = project.subtasks[i + 1];
                                project.subtasks[i + 1] = temp;
                                onChanged();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () =>
                                _showSubtaskDialog(context, task: subtask),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              project.subtasks.removeWhere(
                                (t) => t.id == subtask.id,
                              );
                              onChanged();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                          ),
                        ],
                      ),
                    ),

                    // ─── תתי-המשימות הפנימיות (Level 2) ───
                    if (subtask.subTasks.isNotEmpty)
                      for (int j = 0; j < subtask.subTasks.length; j++) ...[
                        Builder(
                          builder: (context) {
                            final nestedTask = subtask.subTasks[j];
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: 56.0,
                                left: 16.0,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: nestedTask.isCompleted,
                                      onChanged: isTaskLocked
                                          ? null
                                          : (v) {
                                              nestedTask.isCompleted =
                                                  v ?? false;
                                              onChanged();
                                            },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nestedTask.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        decoration: nestedTask.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isTaskLocked
                                            ? Colors.grey
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (j > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_up,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        final temp = subtask.subTasks[j];
                                        subtask.subTasks[j] =
                                            subtask.subTasks[j - 1];
                                        subtask.subTasks[j - 1] = temp;
                                        onChanged();
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                      ),
                                    ),
                                  if (j < subtask.subTasks.length - 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        final temp = subtask.subTasks[j];
                                        subtask.subTasks[j] =
                                            subtask.subTasks[j + 1];
                                        subtask.subTasks[j + 1] = temp;
                                        onChanged();
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _showEditNestedTaskDialog(
                                      context,
                                      nestedTask,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      subtask.subTasks.removeWhere(
                                        (t) => t.id == nestedTask.id,
                                      );
                                      onChanged();
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                    // ─── כפתור הוספת תת-משימה ───
                    Padding(
                      padding: const EdgeInsets.only(
                        right: 56.0,
                        bottom: 8.0,
                        top: 4.0,
                      ),
                      child: InkWell(
                        onTap: () => _showAddNestedTaskDialog(context, subtask),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'הוסף תת-משימה',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: stripeColor == null
          ? cardContent
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: stripeColor),
                  Expanded(child: cardContent),
                ],
              ),
            ),
    );
  }
}
