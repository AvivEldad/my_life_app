import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../widgets/todo_card.dart';
import '../services/task_service.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  List<TodoItem> _tasks = [];
  int _selectedIndex = 0;

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

  void _handleSort(String type) {
    setState(() {
      if (type == 'level') {
        _tasks = TaskService.sortByLevel(_tasks);
      } else {
        _tasks = TaskService.sortByDueDate(_tasks);
      }
    });
  }

  void _handleEdit(TodoItem todo) {
    if (todo.recurrence == RecurrenceType.none) {
      _showRegularTaskDialog(todo: todo);
    } else {
      _showRecurringTaskDialog(todo: todo);
    }
  }

  // דיאלוג משימה רגילה
  void _showRegularTaskDialog({TodoItem? todo}) {
    final isEditing = todo != null;
    final titleController = TextEditingController(text: todo?.title ?? '');
    final descController = TextEditingController(text: todo?.description ?? '');
    DateTime? selectedDate = todo?.dueDate;
    int level = todo?.level ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEditing ? 'עריכת משימה' : 'משימה רגילה חדשה'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(hintText: 'כותרת')),
                  TextField(controller: descController, decoration: const InputDecoration(hintText: 'תיאור')),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(selectedDate == null ? 'תאריך יעד (אופציונלי)' : '${selectedDate!.day}/${selectedDate!.month}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),
                  Slider(value: level.toDouble(), min: 1, max: 5, divisions: 4, activeColor: Colors.amber, onChanged: (v) => setDialogState(() => level = v.toInt())),
                ],
              ),
            ),
            actions: [
              if (isEditing) IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () { setState(() => _tasks.remove(todo)); Navigator.pop(context); }),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
              ElevatedButton(
                onPressed: titleController.text.isEmpty ? null : () {
                  setState(() {
                    if (isEditing) {
                      todo.title = titleController.text;
                      todo.description = descController.text;
                      todo.dueDate = selectedDate;
                      todo.level = level;
                    } else {
                      _tasks.insert(0, TodoItem(id: DateTime.now().toString(), title: titleController.text, description: descController.text, dueDate: selectedDate, level: level));
                    }
                  });
                  Navigator.pop(context);
                },
                child: Text(isEditing ? 'שמור' : 'צור'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // דיאלוג מחזורית (עם בחירת ימים בעיגולים)
  void _showRecurringTaskDialog({TodoItem? todo}) {
    final isEditing = todo != null;
    final titleController = TextEditingController(text: todo?.title ?? '');
    RecurrenceType type = todo?.recurrence ?? RecurrenceType.daily;
    TimeOfDay? time = todo?.reminderTime;
    int? repeatValue = todo?.repeatValue ?? 1;
    int level = todo?.level ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isEditing ? 'עריכת טקס' : 'טקס מחזורי חדש'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(hintText: 'מה הטקס?')),
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
                  if (type == RecurrenceType.weekly) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        int d = index + 1;
                        bool sel = repeatValue == d;
                        return GestureDetector(
                          onTap: () => setDialogState(() => repeatValue = d),
                          child: CircleAvatar(radius: 16, backgroundColor: sel ? Colors.amber : Colors.grey[700], child: Text(['א','ב','ג','ד','ה','ו','ש'][index], style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 12))),
                        );
                      }),
                    ),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(time == null ? 'חובה לבחור שעה' : 'בכל יום ב: ${time!.format(context)}'),
                    onTap: () async {
                      TimeOfDay? picked = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
                      if (picked != null) setDialogState(() => time = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
              ElevatedButton(
                onPressed: (titleController.text.isEmpty || time == null) ? null : () {
                  setState(() {
                    if (isEditing) {
                      todo.title = titleController.text;
                      todo.recurrence = type;
                      todo.reminderTime = time;
                      todo.repeatValue = repeatValue;
                    } else {
                      _tasks.insert(0, TodoItem(id: DateTime.now().toString(), title: titleController.text, recurrence: type, reminderTime: time, repeatValue: repeatValue, level: level));
                    }
                  });
                  Navigator.pop(context);
                },
                child: const Text('אישור'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTasks = _tasks.where((t) => _selectedIndex == 0 ? t.recurrence == RecurrenceType.none : t.recurrence != RecurrenceType.none).toList();
    final golden = currentTasks.where((t) => t.isGolden).toList();
    final others = currentTasks.where((t) => !t.isGolden).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'המשימות שלי' : 'הטקסים שלי'),
        actions: [
          if (_selectedIndex == 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: _handleSort,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'level', child: Text('לפי רמה')),
                const PopupMenuItem(value: 'date', child: Text('לפי תאריך')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedIndex == 0 && golden.isNotEmpty) ...[
            TodoCard(todo: golden.first, onToggle: () => setState(() => golden.first.isCompleted = !golden.first.isCompleted), onEdit: () => _handleEdit(golden.first), onDelete: () => setState(() => _tasks.remove(golden.first)), onToggleGolden: () => _toggleGolden(golden.first)),
            const Divider(),
          ],
          Expanded(
            child: ReorderableListView.builder(
              itemCount: others.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = others.removeAt(oldIdx);
                  _tasks.remove(item);
                  _tasks.insert(newIdx, item);
                });
              },
              itemBuilder: (context, index) => ReorderableDragStartListener(
                key: ValueKey(others[index].id),
                index: index,
                child: TodoCard(todo: others[index], onToggle: () => setState(() => others[index].isCompleted = !others[index].isCompleted), onEdit: () => _handleEdit(others[index]), onDelete: () => setState(() => _tasks.remove(others[index])), onToggleGolden: () => _toggleGolden(others[index])),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.list), label: 'משימות'), BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'טקסים')],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectedIndex == 0 ? _showRegularTaskDialog() : _showRecurringTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}