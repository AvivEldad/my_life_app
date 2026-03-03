import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../widgets/todo_card.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoItem> _tasks = [];

  // לוגיקה לבחירת משימה מוזהבת (רק אחת יכולה להיות כזו)
  void _toggleGolden(TodoItem todo) {
    setState(() {
      if (todo.isGolden) {
        todo.isGolden = false;
      } else {
        // קודם כל מבטלים את כל האחרות
        for (var t in _tasks) {
          t.isGolden = false;
        }
        todo.isGolden = true;
      }
    });
  }

  void _sortByLevel() {
    setState(() {
      _tasks.sort((a, b) => b.level.compareTo(a.level));
    });
  }

  void _sortByDate() {
    setState(() {
      _tasks.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return b.level.compareTo(a.level);
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        int dateCompare = a.dueDate!.compareTo(b.dueDate!);
        return dateCompare == 0 ? b.level.compareTo(a.level) : dateCompare;
      });
    });
  }

  void _showTaskDialog({TodoItem? todo}) {
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
                TextField(controller: titleController, autofocus: true, textAlign: TextAlign.right),
                TextField(controller: descController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: 'תיאור'),),
                const SizedBox(height: 20),
                ListTile(
                  title: Text(selectedDate == null ? 'בחר תאריך סיום' : 'תאריך: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
                Slider(value: level.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v) => setDialogState(() => level = v.toInt())),
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

  @override
  Widget build(BuildContext context) {
    final goldenTask = _tasks.where((t) => t.isGolden).toList();
    final otherTasks = _tasks.where((t) => !t.isGolden).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuestLog'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => value == 'level' ? _sortByLevel() : _sortByDate(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'level', child: Text('לפי רמה')),
              const PopupMenuItem(value: 'date', child: Text('לפי תאריך')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (goldenTask.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 16, right: 16),
              child: Text("משימת פוקוס", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
            TodoCard(
              todo: goldenTask.first,
              onToggle: () => setState(() => goldenTask.first.isCompleted = !goldenTask.first.isCompleted),
              onEdit: () => _showTaskDialog(todo: goldenTask.first),
              onDelete: () => setState(() => _tasks.remove(goldenTask.first)),
              onToggleGolden: () => _toggleGolden(goldenTask.first),
            ),
            const SizedBox(height: 20),
            const Divider(),
          ],
          
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: otherTasks.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;

                  final movedTask = otherTasks.removeAt(oldIdx);
                  _tasks.remove(movedTask);

                  int insertIndex = _tasks.indexOf(otherTasks.isEmpty ? _tasks.last : otherTasks[newIdx < otherTasks.length ? newIdx : otherTasks.length - 1]);
                  _tasks.insert(newIdx, movedTask); 
                });
              },
              itemBuilder: (context, index) {
                final task = otherTasks[index];
                return ReorderableDragStartListener(
                  key: ValueKey(task.id),
                  index: index,
                  child: TodoCard(
                    todo: task,
                    onToggle: () => setState(() => task.isCompleted = !task.isCompleted),
                    onEdit: () => _showTaskDialog(todo: task),
                    onDelete: () => setState(() => _tasks.remove(task)),
                    onToggleGolden: () => _toggleGolden(task),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}