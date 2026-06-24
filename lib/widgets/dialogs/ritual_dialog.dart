import 'package:flutter/material.dart';
import '../../models/ritual_item.dart';
import '../../models/category_item.dart';

class RitualDialog extends StatefulWidget {
  final RitualItem? ritual;
  final List<CategoryItem> categories;
  final void Function(RitualItem) onSave;
  final void Function()? onDelete;

  const RitualDialog({
    super.key,
    this.ritual,
    required this.categories,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<RitualDialog> createState() => _RitualDialogState();
}

class _RitualDialogState extends State<RitualDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late int _level;
  late String? _categoryId;
  late RitualRecurrence _recurrence;
  late TimeOfDay? _time;
  late int? _repeatValue;

  bool get _isEditing => widget.ritual != null;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    final ritual = widget.ritual;
    _titleController = TextEditingController(text: ritual?.title ?? '')
      ..addListener(_validate);
    _descController = TextEditingController(text: ritual?.description ?? '');
    _level = ritual?.level ?? 1;
    _categoryId = ritual?.categoryId;
    _recurrence = ritual?.recurrence ?? RitualRecurrence.daily;
    _time = ritual?.reminderTime;
    _repeatValue = ritual?.repeatValue;
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
    final ritual = RitualItem(
      id: widget.ritual?.id ?? '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      level: _level,
      isCompleted: widget.ritual?.isCompleted ?? false,
      recurrence: _recurrence,
      reminderTime: _time,
      repeatValue: _repeatValue,
      categoryId: _categoryId,
    );
    widget.onSave(ritual);
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
      title: Text(_isEditing ? 'עריכת הרגל' : 'הרגל חדש'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'שם ההרגל',
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

            // בחירת תדירות
            DropdownButtonFormField<RitualRecurrence>(
              decoration: const InputDecoration(
                labelText: 'תדירות',
                border: OutlineInputBorder(),
              ),
              value: _recurrence,
              items: const [
                DropdownMenuItem(
                  value: RitualRecurrence.daily,
                  child: Text('יומי'),
                ),
                DropdownMenuItem(
                  value: RitualRecurrence.weekly,
                  child: Text('שבועי'),
                ),
                DropdownMenuItem(
                  value: RitualRecurrence.monthly,
                  child: Text('חודשי'),
                ),
              ],
              onChanged: (v) => setState(() {
                _recurrence = v!;
                _repeatValue =
                    (v == RitualRecurrence.weekly ||
                        v == RitualRecurrence.monthly)
                    ? 1
                    : null;
              }),
            ),
            const SizedBox(height: 12),

            // חשיפת בחירת היום בשבוע אם נבחר "שבועי"
            if (_recurrence == RitualRecurrence.weekly) ...[
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'באיזה יום?',
                  border: OutlineInputBorder(),
                ),
                value: _repeatValue ?? 1,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("ראשון")),
                  DropdownMenuItem(value: 2, child: Text("שני")),
                  DropdownMenuItem(value: 3, child: Text("שלישי")),
                  DropdownMenuItem(value: 4, child: Text("רביעי")),
                  DropdownMenuItem(value: 5, child: Text("חמישי")),
                  DropdownMenuItem(value: 6, child: Text("שישי")),
                  DropdownMenuItem(value: 7, child: Text("שבת")),
                ],
                onChanged: (v) => setState(() => _repeatValue = v),
              ),
              const SizedBox(height: 12),
            ],

            // חשיפת בחירת היום בחודש אם נבחר "חודשי"
            if (_recurrence == RitualRecurrence.monthly) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'יום בחודש (1-31)',
                  border: OutlineInputBorder(),
                ),
                initialValue: _repeatValue?.toString() ?? '1',
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => _repeatValue = int.tryParse(v) ?? 1),
              ),
              const SizedBox(height: 12),
            ],

            // תזכורת
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _time == null
                    ? 'הוסף שעת תזכורת'
                    : 'תזכורת ב: ${_time!.format(context)}',
              ),
              trailing: const Icon(Icons.access_time, color: Colors.blueAccent),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _time = picked);
              },
            ),

            // רמה
            Align(
              alignment: Alignment.centerRight,
              child: Text('רמה: $_level', style: const TextStyle(fontSize: 14)),
            ),
            Slider(
              value: _level.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: Colors.blueAccent,
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
          child: Text(_isEditing ? 'שמור' : 'צור הרגל'),
        ),
      ],
    );
  }
}
