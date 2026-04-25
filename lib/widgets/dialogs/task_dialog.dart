import 'package:flutter/material.dart';
import '../../models/todo_item.dart';
import '../../models/category_item.dart';

class TaskDialog extends StatefulWidget {
  final TodoItem? todo;
  final bool isRitual;
  final List<CategoryItem> categories;
  final void Function(TodoItem) onSave;
  final void Function()? onDelete;

  const TaskDialog({
    super.key,
    this.todo,
    this.isRitual = false,
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

  // Ritual-specific
  late RecurrenceType _type;
  late TimeOfDay? _time;
  late int? _repeatValue;

  bool get _isEditing => widget.todo != null;
  bool get _isRitual => widget.isRitual;

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    _titleController = TextEditingController(text: todo?.title ?? '');
    _descController = TextEditingController(text: todo?.description ?? '');
    _selectedDate = todo?.dueDate;
    _level = todo?.level ?? 1;
    _categoryId = todo?.categoryId;
    _type = todo?.recurrence ?? RecurrenceType.daily;
    _time = todo?.reminderTime;
    _repeatValue = todo?.repeatValue ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Widget _buildCategoryDropdown() {
    if (widget.categories.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      value: _categoryId,
      decoration: const InputDecoration(hintText: 'קטגוריה (אופציונלי)'),
      items: [
        const DropdownMenuItem(value: null, child: Text('ללא קטגוריה')),
        ...widget.categories.map((c) => DropdownMenuItem(
          value: c.id,
          child: Row(children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(c.name),
          ]),
        )),
      ],
      onChanged: (v) => setState(() => _categoryId = v),
    );
  }

  void _submit() {
    final todo = widget.todo ?? TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
    );
    todo.title = _titleController.text;
    todo.description = _descController.text;
    todo.level = _level;
    todo.categoryId = _categoryId;

    if (_isRitual) {
      todo.recurrence = _type;
      todo.reminderTime = _time;
      todo.repeatValue = _repeatValue;
    } else {
      todo.dueDate = _selectedDate;
    }

    widget.onSave(todo);
    Navigator.pop(context);
  }

  bool get _canSubmit {
    if (_titleController.text.isEmpty) return false;
    if (_isRitual && _time == null) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? (_isRitual ? 'עריכת טקס' : 'עריכת משימה')
        : (_isRitual ? 'טקס מחזורי חדש' : 'משימה רגילה חדשה');

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: 'כותרת'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _descController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: 'תיאור'),
            ),

            // ── Regular: date picker ──
            if (!_isRitual) ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_selectedDate == null
                  ? 'תאריך יעד (אופציונלי)'
                  : '${_selectedDate!.day}/${_selectedDate!.month}'),
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

            // ── Ritual: recurrence type ──
            if (_isRitual) ...[
              const SizedBox(height: 12),
              DropdownButton<RecurrenceType>(
                value: _type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: RecurrenceType.daily, child: Text('כל יום')),
                  DropdownMenuItem(value: RecurrenceType.weekly, child: Text('כל שבוע')),
                  DropdownMenuItem(value: RecurrenceType.monthly, child: Text('כל חודש')),
                ],
                onChanged: (v) => setState(() { _type = v!; _repeatValue = 1; }),
              ),

              // Weekly: day picker
              if (_type == RecurrenceType.weekly) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final dayNum = i + 1;
                    final isSelected = _repeatValue == dayNum;
                    return GestureDetector(
                      onTap: () => setState(() => _repeatValue = dayNum),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected ? Colors.amber : Colors.grey[700],
                        child: Text(
                          ['א','ב','ג','ד','ה','ו','ש'][i],
                          style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],

              // Monthly: day slider
              if (_type == RecurrenceType.monthly) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('יום בחודש: ${_repeatValue ?? 1}', style: const TextStyle(fontSize: 14)),
                ),
                Slider(
                  value: (_repeatValue ?? 1).toDouble(),
                  min: 1, max: 31, divisions: 30,
                  activeColor: Colors.amber,
                  label: '${_repeatValue ?? 1}',
                  onChanged: (v) => setState(() => _repeatValue = v.toInt()),
                ),
                const SizedBox(height: 4),
              ],

              // Time picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_time == null ? 'חובה לבחור שעה' : 'תזכורת ב: ${_time!.format(context)}'),
                trailing: const Icon(Icons.access_time, color: Colors.amber),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time ?? TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => _time = picked);
                },
              ),

              // Level
              Align(
                alignment: Alignment.centerRight,
                child: Text('רמה: $_level', style: const TextStyle(fontSize: 14)),
              ),
            ],

            Slider(
              value: _level.toDouble(),
              min: 1, max: 5, divisions: 4,
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
            onPressed: () { widget.onDelete!(); Navigator.pop(context); },
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_isEditing ? 'שמור' : (_isRitual ? 'אישור' : 'צור')),
        ),
      ],
    );
  }
}