import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../services/task_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskItem? task;

  const TaskDetailsScreen({super.key, this.task});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _subTaskController;

  int _level = 1;
  DateTime? _dueDate; // משתנה חדש לשמירת תאריך היעד
  List<SubTask> _subTasks = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _subTaskController = TextEditingController();

    _level = widget.task?.level ?? 1;
    _dueDate = widget.task?.dueDate; // טעינת התאריך הקיים אם יש

    if (widget.task != null) {
      _subTasks = List.from(widget.task!.subTasks);
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

      final updatedTask = TaskItem(
        id: taskId,
        title: _titleController.text,
        description: _descriptionController.text,
        level: _level,
        dueDate: _dueDate, // שמירת התאריך שבחרנו
        subTasks: _subTasks,
        // שומרים על הערכים הקיימים
        isGolden: widget.task?.isGolden ?? false,
        isCompleted: widget.task?.isCompleted ?? false,
        orderIndex:
            widget.task?.orderIndex ??
            DateTime.now().millisecondsSinceEpoch * -1,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
      );

      await taskService.saveTask(updatedTask);

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _addSubTask() {
    if (_subTaskController.text.isNotEmpty) {
      setState(() {
        _subTasks.add(
          SubTask(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: _subTaskController.text,
          ),
        );
        _subTaskController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                labelText: 'תיאור (אופציונלי)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // --- בחירת תאריך יעד ---
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
                      onPressed: () =>
                          setState(() => _dueDate = null), // איפוס תאריך
                    )
                  : null,
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2000), // מאיזו שנה אפשר לבחור
                  lastDate: DateTime(2100), // עד איזה שנה אפשר לבחור
                );

                // אם המשתמש בחר תאריך, נעדכן את המצב
                if (pickedDate != null) {
                  setState(() {
                    _dueDate = pickedDate;
                  });
                }
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
                secondary: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _subTasks.remove(subTask);
                    });
                  },
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
                backgroundColor: Colors.green,
              ),
              onPressed: _saveTask,
              child: const Text(
                'שמור משימה',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
