import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../models/project_item.dart';
import '../services/project_service.dart';
import '../services/task_service.dart';
import 'create_project_screen.dart';
import 'project_details_screen.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  Future<bool> _confirmDelete(BuildContext context, ProjectItem project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text(
            'מחיקת פרויקט',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'האם אתה בטוח שברצונך למחוק את "${project.title}"?\n'
            'כל המשימות ששייכות לפרויקט זה יימחקו גם הן.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('מחק', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _deleteProject(BuildContext context, ProjectItem project) async {
    final confirmed = await _confirmDelete(context, project);
    if (confirmed) {
      await context.read<ProjectService>().deleteProjectWithTasks(project.id);
    }
  }

  Future<void> _editProject(BuildContext context, ProjectItem project) async {
    final projectService = context.read<ProjectService>();
    final taskService = context.read<TaskService>();

    final edited = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProjectScreen(existingProject: project),
      ),
    );

    if (edited != null && edited is ProjectItem) {
      await projectService.saveProject(edited);

      // אם שם הפרויקט השתנה - נעדכן גם את השם המסונכרן על כל המשימות
      // שכבר שייכות אליו, כדי שהחיווי בעמוד הבית יישאר עדכני
      if (edited.title != project.title) {
        final tasks = await taskService.streamTasksForProject(project.id).first;
        for (final task in tasks) {
          task.projectName = edited.title;
          await taskService.saveTask(task);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Instantiate the service to talk to your database
    final projectService = ProjectService();

    return Scaffold(
      appBar: AppBar(title: const Text('הפרויקטים שלי'), centerTitle: true),
      // FIX 1: The App Drawer is now attached to this screen!
      drawer: const AppDrawer(),

      // FIX 2: StreamBuilder actively listens for new projects in the database
      body: StreamBuilder<List<ProjectItem>>(
        stream: projectService.streamProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('שגיאה בטעינת פרויקטים.'));
          }

          // פרויקטים שכבר הושלמו יימחקו אוטומטית בסוף היום, אז אין צורך
          // להציג אותם ברשימה הראשית
          final projects = (snapshot.data ?? [])
              .where((p) => !p.isCompleted)
              .toList();

          // Show the empty state if there are no projects
          if (projects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'אין פרויקטים עדיין.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'לחץ על ה- + כדי להתחיל פרויקט חדש.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Build the list of project cards
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Dismissible(
                key: Key(project.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: Colors.redAccent,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmDelete(context, project),
                onDismissed: (_) {
                  projectService.deleteProjectWithTasks(project.id);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(project.title),
                    // כאשר אין תיאור - לא מציגים כלום (במקום "ללא תיאור")
                    subtitle: project.description.isNotEmpty
                        ? Text(project.description)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show a lock icon if the project is sequential
                        if (project.isSequential)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.lock_outline,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () => _editProject(context, project),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteProject(context, project),
                        ),
                      ],
                    ),
                    onTap: () {
                      // ניווט למסך פרטי הפרויקט כאשר לוחצים על הפרויקט
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProjectDetailsScreen(project: project),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newProject = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateProjectScreen(),
            ),
          );

          // FIX 3: Actually save the data to the database!
          if (newProject != null) {
            await projectService.saveProject(newProject);

            // Check if the widget is still mounted before showing the snackbar
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('נוצר פרויקט: ${newProject.title}')),
              );
            }
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
