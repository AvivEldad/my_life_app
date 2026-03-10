import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../widgets/todo_card.dart';
//import '../services/notification_service.dart'; // ייבוא של שירות ההתראות

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoItem> _tasks = [];
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

  // פונקציית מחיקה שגם מבטלת התראה
  void _deleteTask(TodoItem todo) {
    setState(() {
      if (todo.recurrence != RecurrenceType.none) {
        //NotificationService.cancelNotification(todo.id);
        Text('hello');
      }
      _tasks.removeWhere((t) => t.id == todo.id);
    });
  }

  // --- דיאלוג משימה רגילה ---
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
          title: Text(isEditing ? 'עריכת משימה' : 'משימה רגילה חדשה'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'כותרת')),
                TextField(controller: descController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'תיאור')),
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
            if (isEditing) IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteTask(todo)),
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
    );
  }

  // --- דיאלוג משימה מחזורית עם תמיכה בהתראות ---
  void _showRecurringTaskDialog({TodoItem? todo}) {
    final isEditing = todo != null;
    final titleController = TextEditingController(text: todo?.title ?? '');
    RecurrenceType type = todo?.recurrence ?? RecurrenceType.daily;
    TimeOfDay? time = todo?.reminderTime;
    int? repeatValue = todo?.repeatValue ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'עריכת טקס' : 'טקס מחזורי חדש'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'כותרת')),
              const SizedBox(height: 15),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    int dayNum = index + 1;
                    bool isSelected = repeatValue == dayNum;
                    return GestureDetector(
                      onTap: () => setDialogState(() => repeatValue = dayNum),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected ? Colors.amber : Colors.grey[700],
                        child: Text(['א','ב','ג','ד','ה','ו','ש'][index], style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12)),
                      ),
                    );
                  }),
                ),
              ListTile(
                title: Text(time == null ? 'חובה לבחור שעה' : 'תזכורת ב: ${time!.format(context)}'),
                trailing: const Icon(Icons.access_time, color: Colors.amber),
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
                  if (picked != null) setDialogState(() => time = picked);
                },
              ),
            ],
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
                    //NotificationService.scheduleNotification(todo); // עדכון התראה קיימת
                  } else {
                    final newTask = TodoItem(
                      id: DateTime.now().toString(),
                      title: titleController.text,
                      recurrence: type,
                      reminderTime: time,
                      repeatValue: repeatValue,
                    );
                    _tasks.insert(0, newTask);
                    //NotificationService.scheduleNotification(newTask); // תזמון התראה חדשה
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
    final currentTasks = _tasks.where((t) => _selectedIndex == 0 ? t.recurrence == RecurrenceType.none : t.recurrence != RecurrenceType.none).toList();
    final goldenTask = currentTasks.where((t) => t.isGolden).toList();
    final otherTasks = currentTasks.where((t) => !t.isGolden).toList();

    return Scaffold(
      appBar: AppBar(title: Text(_selectedIndex == 0 ? 'המשימות שלי' : 'הטקסים שלי')),
      body: Column(
        children: [
          if (_selectedIndex == 0 && goldenTask.isNotEmpty) ...[
            TodoCard(
              todo: goldenTask.first,
              onToggle: () => setState(() => goldenTask.first.isCompleted = !goldenTask.first.isCompleted),
              onEdit: () => _showRegularTaskDialog(todo: goldenTask.first),
              onDelete: () => _deleteTask(goldenTask.first),
              onToggleGolden: () => _toggleGolden(goldenTask.first),
            ),
            const Divider(),
          ],
          Expanded(
            child: ReorderableListView.builder(
              itemCount: otherTasks.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = otherTasks.removeAt(oldIdx);
                  _tasks.remove(item);
                  _tasks.insert(newIdx, item);
                });
              },
              itemBuilder: (context, index) => ReorderableDragStartListener(
                key: ValueKey(otherTasks[index].id),
                index: index,
                child: TodoCard(
                  todo: otherTasks[index],
                  onToggle: () => setState(() => otherTasks[index].isCompleted = !otherTasks[index].isCompleted),
                  onEdit: () => _selectedIndex == 0 ? _showRegularTaskDialog(todo: otherTasks[index]) : _showRecurringTaskDialog(todo: otherTasks[index]),
                  onDelete: () => _deleteTask(otherTasks[index]),
                  onToggleGolden: () => _toggleGolden(otherTasks[index]),
                ),
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