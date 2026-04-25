import 'package:flutter/material.dart';
import '../models/project_item.dart';
import '../models/todo_item.dart';
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

  void _showSubtaskDialog(BuildContext context, {TodoItem? todo}) {
    showDialog(
      context: context,
      builder: (_) => TaskDialog(
        todo: todo,
        categories: const [],
        onSave: (saved) {
          if (todo == null) {
            project.subtasks.add(saved);
          }
          onChanged();
        },
        onDelete: todo != null
            ? () {
                project.subtasks.removeWhere((t) => t.id == todo.id);
                onChanged();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIdx = project.activeSubtaskIndex;
    final stripeColor = _stripeColor;

    final cardContent = Column(
      children: [
        // ── Header ──
        InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[400]),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showEditDialog(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.add_task, size: 18, color: Colors.amber),
                          onPressed: () => _showSubtaskDialog(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '${project.completedCount}/${project.subtasks.length}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(project.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                if (project.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(project.description,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        project.progress == 1.0 ? Colors.green : Colors.amber),
                  ),
                ),
                if (project.dueDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'יעד: ${project.dueDate!.day}/${project.dueDate!.month}/${project.dueDate!.year}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Subtasks ──
        if (isExpanded) ...[
          if (project.subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('אין משימות עדיין', style: TextStyle(color: Colors.grey[500])),
            )
          else ...[
            const Divider(height: 1),
            ...List.generate(project.subtasks.length, (i) {
              final subtask = project.subtasks[i];
              final isActive = i == activeIdx;
              final isLocked = !subtask.isCompleted && !isActive;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: isLocked
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.lock, size: 18, color: Colors.grey),
                      )
                    : Checkbox(
                        value: subtask.isCompleted,
                        activeColor: Colors.amber,
                        onChanged: (_) {
                          subtask.isCompleted = !subtask.isCompleted;
                          onChanged();
                        },
                      ),
                title: Text(
                  subtask.title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                    color: isLocked ? Colors.grey[600] : subtask.isCompleted ? Colors.grey : null,
                  ),
                ),
                subtitle: (subtask.description?.isNotEmpty ?? false) || subtask.dueDate != null
                    ? Text(
                        [
                          if (subtask.description?.isNotEmpty ?? false) subtask.description!,
                          if (subtask.dueDate != null)
                            '${subtask.dueDate!.day}/${subtask.dueDate!.month}',
                        ].join(' · '),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: isLocked ? Colors.grey[700] : null),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive) const Icon(Icons.play_arrow, size: 16, color: Colors.amber),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      onPressed: () => _showSubtaskDialog(context, todo: subtask),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                      onPressed: () {
                        project.subtasks.removeWhere((t) => t.id == subtask.id);
                        onChanged();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
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