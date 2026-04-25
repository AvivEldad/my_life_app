import 'package:flutter/material.dart';
import '../../models/project_item.dart';
import '../../models/category_item.dart';

class ProjectDialog extends StatefulWidget {
  final ProjectItem? project;
  final List<CategoryItem> categories;
  final void Function(ProjectItem) onSave;
  final void Function()? onDelete;

  const ProjectDialog({
    super.key,
    this.project,
    required this.categories,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime? _selectedDate;
  late int _level;
  late String? _categoryId;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _selectedDate = p?.dueDate;
    _level = p?.level ?? 1;
    _categoryId = p?.categoryId;
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
    final project = widget.project ?? ProjectItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
    );
    project.title = _titleController.text;
    project.description = _descController.text;
    project.dueDate = _selectedDate;
    project.level = _level;
    project.categoryId = _categoryId;

    widget.onSave(project);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'עריכת פרויקט' : 'פרויקט חדש'),
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
            ListTile(
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
          onPressed: _titleController.text.isEmpty ? null : _submit,
          child: Text(_isEditing ? 'שמור' : 'צור'),
        ),
      ],
    );
  }
}