import 'package:flutter/material.dart';
import '../../models/task_item.dart';
import '../../models/category_item.dart';

class TaskDialog extends StatefulWidget {
  final TaskItem? task;
  final List<CategoryItem> categories;
  final void Function(TaskItem) onSave;
  final void Function()? onDelete;

  const TaskDialog({
    super.key,
    this.task,
    required this.categories,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime? _selectedDate;
  late int _level;
  late String? _categoryId;

  bool get _isEditing => widget.task != null;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '')
      ..addListener(_validate);
    _descController = TextEditingController(text: task?.description ?? '');
    _selectedDate = task?.dueDate;
    _level = task?.level ?? 1;
    _categoryId = task?.categoryId;
    _validate();
  }

  void _validate() {
    setState(() {
      _canSubmit = _titleController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    // יצירת ID ייחודי למשימה חדשה כדי למנוע מחיקה כפולה!
    final String taskId =
        (widget.task?.id != null && widget.task!.id.isNotEmpty)
        ? widget.task!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final task = TaskItem(
      id: taskId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      dueDate: _selectedDate,
      level: _level,
      isCompleted: widget.task?.isCompleted ?? false,
      isGolden: widget.task?.isGolden ?? false,
      categoryId: _categoryId,
      subTasks: widget.task?.subTasks ?? [], // שמירה על תתי המשימות הקיימות!
    );
    widget.onSave(task);
    Navigator.pop(context);
  }

  Widget _buildCategoryDropdown() {
    if (widget.categories.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'קטגוריה',
        border: OutlineInputBorder(),
      ),
      value: _categoryId,
      items: [
        const DropdownMenuItem(value: null, child: Text('ללא קטגוריה')),
        ...widget.categories.map(
          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
        ),
      ],
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'עריכת משימה' : 'משימה חדשה'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'כותרת',
                border: OutlineInputBorder(),
              ),
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'תיאור (אופציונלי)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedDate == null
                    ? 'הוסף תאריך יעד'
                    : 'תאריך: ${_selectedDate!.day}/${_selectedDate!.month}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('רמה: $_level', style: const TextStyle(fontSize: 14)),
            ),
            Slider(
              value: _level.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: Colors.amber,
              onChanged: (v) => setState(() => _level = v.toInt()),
            ),
            _buildCategoryDropdown(),
          ],
        ),
      ),
      actions: [
        if (_isEditing && widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () {
              widget.onDelete!();
              Navigator.pop(context);
            },
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_isEditing ? 'שמור' : 'צור משימה'),
        ),
      ],
    );
  }
}
