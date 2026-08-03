import 'package:flutter/material.dart';
import '../models/project_item.dart';
import '../models/task_item.dart';
import 'task_details_screen.dart';
import '../services/task_service.dart';
import 'main_layout.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final ProjectItem project;

  // המסך הזה חייב לקבל את הפרויקט שעליו לחצנו
  const ProjectDetailsScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // final taskService = TaskService();

    return Scaffold(
      appBar: AppBar(title: Text(project.title), centerTitle: true),
      // כאן נציג בעתיד את רשימת המשימות המסוננת לפי ה-projectId
      body: Center(
        child: Text(
          'כאן יופיעו תת-המשימות של:\n${project.title}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // פעולה זמנית: כאן ננווט למסך יצירת משימה ונעביר לו את ה-ID של הפרויקט
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('בקרוב: הוספת משימה לפרויקט זה!')),
          );

          /* קוד עתידי להוספת תת-משימה:
          Navigator.push(
            context,
            MaterialPageRoute(
              // חשוב: אנחנו מעבירים את המזהה של הפרויקט למסך יצירת המשימה
              builder: (context) => CreateTaskScreen(projectId: project.id),
            ),
          );
          */
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add_task, color: Colors.black),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // הגדרנו צבע אפור כדי להראות שאף אחת מהלשוניות האלו לא פעילה כרגע
        unselectedItemColor: Colors.grey,
        selectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'משימות',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            label: 'פרויקטים',
          ),
        ],
        onTap: (index) {
          // ברגע שלוחצים על משימות (0) או פרויקטים (1), מנווטים חזרה ל-MainLayout
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainLayout(initialIndex: index),
            ),
          );
        },
      ),
    );
  }
}
