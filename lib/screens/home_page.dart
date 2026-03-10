import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../widgets/todo_card.dart';
import '../models/project_model.dart';
import '../services/task_service.dart';

class TodoHomePage extends StatefulWidget {
  final bool showRecurring;

  const TodoHomePage({super.key, required this.showRecurring});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoItem> _tasks = [];

  void _handleSort(String type) {
    setState(() {
      if (type == 'level') {
        _tasks.replaceRange(0, _tasks.length, TaskService.sortByLevel(_tasks));
      } else {
        _tasks.replaceRange(0, _tasks.length, TaskService.sortByDueDate(_tasks));
      }
    });
  }

  void _toggleGolden(TodoItem todo) {
    setState(() {
      if (todo.isGolden) {
        todo.isGolden = false;
      } else {
        for (var t in _tasks) t.isGolden = false;
        todo.isGolden = true;
      }
    });
  }

  void _deleteTask(TodoItem todo) {
    setState(() {
      _tasks.removeWhere((t) => t.id == todo.id);
    });
  }

  void _showRegularTaskDialog({TodoItem? todo}) {
    final isEditing = todo != null;
    final titleController = TextEditingController(text: todo?.title ?? '');
    final descController = TextEditingController(text: todo?.description ?? '');
    DateTime? selectedDate = todo?.dueDate;
    int level = todo?.level ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'עריכת משימה' : 'משימה חדשה'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'כותרת')),
                TextField(controller: descController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'תיאור')),
                ListTile(
                  title: Text(selectedDate == null ? 'תאריך יעד' : '${selectedDate!.day}/${selectedDate!.month}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                const Text('רמת קושי'),
                Slider(value: level.toDouble(), min: 1, max: 5, divisions: 4, activeColor: Colors.amber, onChanged: (v) => setDialogState(() => level = v.toInt())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (isEditing) {
                    todo.title = titleController.text;
                    todo.description = descController.text;
                    todo.dueDate = selectedDate;
                    todo.level = level;
                  } else {
                    _tasks.add(TodoItem(id: DateTime.now().toString(), title: titleController.text, description: descController.text, dueDate: selectedDate, level: level));
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecurringTaskDialog({TodoItem? todo}) {
    final isEditing = todo != null;
    final titleController = TextEditingController(text: todo?.title ?? '');
    RecurrenceType type = todo?.recurrence ?? RecurrenceType.daily;
    int? repeatValue = todo?.repeatValue ?? 1;
    TimeOfDay? time = todo?.reminderTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'עריכת טקס' : 'טקס חדש'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'מה הטקס?')),
                DropdownButton<RecurrenceType>(
                  value: type,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: RecurrenceType.daily, child: Text('כל יום')),
                    DropdownMenuItem(value: RecurrenceType.weekly, child: Text('כל שבוע')),
                    DropdownMenuItem(value: RecurrenceType.monthly, child: Text('כל חודש')),
                  ],
                  onChanged: (v) => setDialogState(() { type = v!; repeatValue = 1; }),
                ),
                if (type == RecurrenceType.weekly)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) => GestureDetector(
                      onTap: () => setDialogState(() => repeatValue = index + 1),
                      child: CircleAvatar(radius: 14, backgroundColor: repeatValue == index + 1 ? Colors.amber : Colors.grey, child: Text(['א','ב','ג','ד','ה','ו','ש'][index])),
                    )),
                  ),
                if (type == RecurrenceType.monthly)
                  DropdownButton<int>(
                    value: repeatValue,
                    isExpanded: true,
                    items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('יום ${i + 1} בחודש'))),
                    onChanged: (v) => setDialogState(() => repeatValue = v),
                  ),
                ListTile(
                  title: Text(time == null ? 'בחר שעה' : time!.format(context)),
                  onTap: () async {
                    TimeOfDay? p = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (p != null) setDialogState(() => time = p);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  if (isEditing) {
                    todo.title = titleController.text;
                    todo.recurrence = type;
                    todo.repeatValue = repeatValue;
                    todo.reminderTime = time;
                  } else {
                    _tasks.add(TodoItem(id: DateTime.now().toString(), title: titleController.text, recurrence: type, repeatValue: repeatValue, reminderTime: time));
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('אישור'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTasks = _tasks.where((t) => widget.showRecurring ? t.recurrence != RecurrenceType.none : t.recurrence == RecurrenceType.none).toList();
    final golden = currentTasks.where((t) => t.isGolden).toList();
    final others = currentTasks.where((t) => !t.isGolden).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showRecurring ? 'Rituals' : 'Quests'),
        actions: [
          if (!widget.showRecurring)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: _handleSort,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'level', child: Text('מיין לפי רמה')),
                const PopupMenuItem(value: 'date', child: Text('מיין לפי תאריך')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (golden.isNotEmpty) ...[
            TodoCard(todo: golden.first, onToggle: () => setState(() => golden.first.isCompleted = !golden.first.isCompleted), onEdit: () => _showRegularTaskDialog(todo: golden.first), onDelete: () => _deleteTask(golden.first), onToggleGolden: () => _toggleGolden(golden.first)),
            const Divider(),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: others.length,
              itemBuilder: (context, index) => TodoCard(
                todo: others[index],
                onToggle: () => setState(() => others[index].isCompleted = !others[index].isCompleted),
                onEdit: () => widget.showRecurring ? _showRecurringTaskDialog(todo: others[index]) : _showRegularTaskDialog(todo: others[index]),
                onDelete: () => _deleteTask(others[index]),
                onToggleGolden: widget.showRecurring ? null : () => _toggleGolden(others[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.showRecurring ? _showRecurringTaskDialog : _showRegularTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}