import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../models/todo_item.dart';
import '../widgets/todo_card.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final List<Project> _projects = [];

  void _showProjectDialog({Project? project}) {
    final isEditing = project != null;
    final titleController = TextEditingController(text: project?.title ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'עריכת פרויקט' : 'פרויקט חדש'),
        content: TextField(controller: titleController, decoration: const InputDecoration(hintText: 'שם הפרויקט')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (isEditing) {
                  project.title = titleController.text;
                } else {
                  _projects.add(Project(id: DateTime.now().toString(), title: titleController.text));
                }
              });
              Navigator.pop(context);
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  void _showSubTaskDialog(Project project) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    int level = 1;
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('שלב חדש בפרויקט'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'כותרת')),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'תיאור')),
                ListTile(
                  title: Text(dueDate == null ? 'תאריך יעד' : '${dueDate!.day}/${dueDate!.month}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (p != null) setDialogState(() => dueDate = p);
                  },
                ),
                const Text('רמת קושי'),
                Slider(value: level.toDouble(), min: 1, max: 5, divisions: 4, activeColor: Colors.amber, 
                  onChanged: (v) => setDialogState(() => level = v.toInt())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  project.subTasks.add(TodoItem(
                    id: DateTime.now().toString(),
                    title: titleController.text,
                    description: descController.text,
                    level: level,
                    dueDate: dueDate,
                  ));
                });
                Navigator.pop(context);
              },
              child: const Text('הוסף'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: ListView.builder(
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          return ExpansionTile(
            title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            subtitle: Text('${project.subTasks.length} שלבים'),
            trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showSubTaskDialog(project)),
            children: [
              ...project.subTasks.asMap().entries.map((entry) {
                int subIndex = entry.key;
                bool isLocked = subIndex > 0 && !project.subTasks[subIndex - 1].isCompleted;

                return TodoCard(
                  todo: entry.value,
                  isLocked: isLocked,
                  onToggle: () => setState(() => entry.value.isCompleted = !entry.value.isCompleted),
                  onEdit: () {}, 
                  onDelete: () => setState(() => project.subTasks.remove(entry.value)),
                );
              }),
              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => setState(() => _projects.remove(project))),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectDialog(),
        child: const Icon(Icons.account_tree),
      ),
    );
  }
}