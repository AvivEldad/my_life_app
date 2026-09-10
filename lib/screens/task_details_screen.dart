import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../services/task_service.dart';
import '../services/category_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskItem? task;
  final String? projectId;
  final String? projectName;
  final int? initialOrderIndex;

  const TaskDetailsScreen({
    super.key,
    this.task,
    this.projectId,
    this.projectName,
    this.initialOrderIndex,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _subTaskController;

  int _level = 1;
  DateTime? _dueDate;
  List<SubTask> _subTasks = [];
  String? _selectedCategoryId;

  // משתנה חדש למשימה שבועית
  bool _isWeekly = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _subTaskController = TextEditingController();

    _level = widget.task?.level ?? 1;
    _dueDate = widget.task?.dueDate;
    _selectedCategoryId = widget.task?.categoryId;
    _isWeekly = widget.task?.isWeekly ?? false;

    if (widget.task != null) {
      _subTasks = widget.task!.subTasks
          .map(
            (subTask) => SubTask(
              id: subTask.id,
              title: subTask.title,
              isCompleted: subTask.isCompleted,
            ),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final taskService = context.read<TaskService>();

      final String taskId =
          widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      // חישוב אוטומטי של תאריך היעד לשבת במידה וזו משימה שבועית
      DateTime? deadline = widget.task?.weeklyDeadline;
      if (_isWeekly && deadline == null) {
        final now = DateTime.now();
        int daysUntilSat = DateTime.saturday - now.weekday;
        if (daysUntilSat < 0) daysUntilSat += 7;
        final saturday = now.add(Duration(days: daysUntilSat));
        deadline = DateTime(
          saturday.year,
          saturday.month,
          saturday.day,
          23,
          59,
          59,
        );
      } else if (!_isWeekly) {
        deadline = null;
      }

      final updatedTask = TaskItem(
        id: taskId,
        title: _titleController.text,
        description: _descriptionController.text,
        level: _level,
        dueDate: _dueDate,
        subTasks: _subTasks,
        categoryId: _selectedCategoryId,
        isGolden: widget.task?.isGolden ?? false,
        isCompleted: widget.task?.isCompleted ?? false,
        lastPenaltyDate: widget.task?.lastPenaltyDate,
        isWeekly: _isWeekly, // שדה שבועי
        weeklyDeadline: deadline, // תאריך יעד שבועי
        projectId: widget.task?.projectId ?? widget.projectId,
        projectName: widget.task?.projectName ?? widget.projectName,
        orderIndex:
            widget.task?.orderIndex ??
            widget.initialOrderIndex ??
            DateTime.now().millisecondsSinceEpoch * -1,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        completedAt: widget.task?.completedAt,
        awardedXp: widget.task?.awardedXp,
        awardedCoins: widget.task?.awardedCoins,
        causedLevelUp: widget.task?.causedLevelUp ?? false,
        xpThresholdBeforeLevelUp: widget.task?.xpThresholdBeforeLevelUp,
        awardedPokemonId: widget.task?.awardedPokemonId,
      );

      await taskService.saveTask(updatedTask);

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _addSubTask() {
    final title = _subTaskController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        _subTasks.add(
          SubTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
          ),
        );
        _subTaskController.clear();
      });
    }
  }

  Future<void> _editSubTask(SubTask subTask) async {
    var draftTitle = subTask.title;

    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('עריכת תת-משימה'),
          content: TextFormField(
            initialValue: subTask.title,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'שם תת-המשימה',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => draftTitle = value,
            onFieldSubmitted: (value) {
              final title = value.trim();
              if (title.isNotEmpty) {
                Navigator.of(dialogContext).pop(title);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = draftTitle.trim();
                if (title.isNotEmpty) {
                  Navigator.of(dialogContext).pop(title);
                }
              },
              child: const Text('שמירה'),
            ),
          ],
        );
      },
    );

    if (updatedTitle != null && mounted) {
      setState(() {
        subTask.title = updatedTitle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryService = context.watch<CategoryService>();
    final effectiveProjectName = widget.task?.projectName ?? widget.projectName;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'משימה חדשה' : 'עריכת משימה'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (effectiveProjectName != null && effectiveProjectName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'משימה בתוך הפרויקט: $effectiveProjectName',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'שם המשימה',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'חובה להזין שם למשימה';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'תיאור',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<List<CategoryItem>>(
              stream: categoryService.streamCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final categories = snapshot.data ?? [];

                if (_selectedCategoryId != null) {
                  bool categoryExists = categories.any(
                    (cat) => cat.id == _selectedCategoryId,
                  );
                  if (!categoryExists) {
                    _selectedCategoryId = null;
                  }
                }

                return DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'קטגוריה',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('ללא קטגוריה'),
                    ),
                    ...categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: category.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(category.name),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_today,
                color: Colors.blueAccent,
              ),
              title: Text(
                _dueDate == null
                    ? 'בחר תאריך יעד (אופציונלי)'
                    : 'תאריך יעד: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
              ),
              trailing: _dueDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () => setState(() => _dueDate = null),
                    )
                  : null,
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );

                if (pickedDate != null) {
                  setState(() {
                    _dueDate = pickedDate;
                  });
                }
              },
            ),

            // --- מתג חדש למשימה שבועית ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'משימה שבועית 🗓️',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('השלם עד מוצ"ש לקבלת בונוס XP ומטבעות!'),
              value: _isWeekly,
              activeColor: Colors.amber,
              onChanged: (bool value) {
                setState(() {
                  _isWeekly = value;
                });
              },
            ),
            const Divider(height: 30, thickness: 2),

            Text(
              'רמת המשימה: $_level',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _level.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: Colors.amber,
              label: _level.toString(),
              onChanged: (double value) {
                setState(() {
                  _level = value.toInt();
                });
              },
            ),
            const Divider(height: 30, thickness: 2),

            const Text(
              'תת-משימות:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ..._subTasks.map((subTask) {
              return CheckboxListTile(
                title: Text(
                  subTask.title,
                  style: TextStyle(
                    decoration: subTask.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                value: subTask.isCompleted,
                onChanged: (bool? value) {
                  setState(() {
                    subTask.isCompleted = value ?? false;
                  });
                },
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'עריכת תת-משימה',
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _editSubTask(subTask),
                    ),
                    IconButton(
                      tooltip: 'מחיקת תת-משימה',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _subTasks.remove(subTask);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskController,
                    decoration: const InputDecoration(
                      hintText: 'הוסף תת-משימה...',
                    ),
                    onSubmitted: (_) => _addSubTask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: _addSubTask,
                ),
              ],
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
              ),
              onPressed: _saveTask,
              child: const Text(
                'שמור משימה',
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
