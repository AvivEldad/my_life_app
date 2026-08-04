import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/category_item.dart'; // יבוא מודל הקטגוריה
import '../services/task_service.dart';
import '../services/category_service.dart'; // יבוא שירות הקטגוריות

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
  DateTime? _dueDate;
  List<SubTask> _subTasks = [];

  // משתנה חדש לשמירת מזהה הקטגוריה שנבחרה
  String? _selectedCategoryId;

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

    // טעינת הקטגוריה הקיימת במשימה אם יש כזו
    _selectedCategoryId = widget.task?.categoryId;

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
        dueDate: _dueDate,
        subTasks: _subTasks,
        categoryId: _selectedCategoryId, // שמירת הקטגוריה שנבחרה!
        isGolden: widget.task?.isGolden ?? false,
        isCompleted: widget.task?.isCompleted ?? false,
        lastPenaltyDate: widget.task?.lastPenaltyDate,
        orderIndex:
            widget.task?.orderIndex ??
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
    // משיכת שירות הקטגוריות כדי לקרוא את רשימת הקטגוריות הקיימות
    final categoryService = context.watch<CategoryService>();

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
                labelText: 'תיאור',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // --- תפריט לבחירת קטגוריה כולל תצוגת צבע ---
            StreamBuilder<List<CategoryItem>>(
              stream: categoryService.streamCategories(),
              builder: (context, snapshot) {
                // 1. מצב המתנה: אם הנתונים עדיין לא הגיעו, נציג טעינה במקום לקרוס
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final categories = snapshot.data ?? [];

                // 2. בדיקת בטיחות: האם הקטגוריה שנשמרה במשימה עדיין קיימת?
                // אם היא לא קיימת (למשל נמחקה), נאפס ל-null (ללא קטגוריה).
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
                    // אופציה לאיפוס/ללא קטגוריה
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('ללא קטגוריה'),
                    ),
                    // יצירת פריט לכל קטגוריה ברשימה
                    ...categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category.id,
                        child: Row(
                          children: [
                            // עיגול הצבע של הקטגוריה
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
