import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../models/project_item.dart';
import '../services/project_service.dart';
import 'create_project_screen.dart';
import 'project_details_screen.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

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

          final projects = snapshot.data ?? [];

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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder, color: Colors.amber),
                  title: Text(project.title),
                  subtitle: Text(
                    project.description.isNotEmpty
                        ? project.description
                        : 'ללא תיאור',
                  ),
                  // Show a lock icon if the project is sequential
                  trailing: project.isSequential
                      ? const Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Colors.grey,
                        )
                      : null,
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
