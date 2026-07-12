import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // חובה כדי להשתמש ב-context.read

// ייבוא המודלים שלנו
import '../models/task_item.dart';
import '../models/project_item.dart';
import '../models/daily_task_item.dart';

// ייבוא השירותים שאנחנו רוצים לבדוק
import '../services/task_service.dart';
import '../services/project_service.dart';
import '../services/daily_task_service.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  // פונקציית עזר קטנה להצגת הודעות קופצות (SnackBar)
  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('מעבדת בדיקות 🧪'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'לחץ על הכפתורים ובידוק במסוף Firebase\nשהנתונים נוצרים בהצלחה!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            // כפתור 1: בדיקת משימה
            ElevatedButton(
              onPressed: () async {
                // משיכת השירות מתוך ה-Provider
                final taskService = context.read<TaskService>();

                final newTask = TaskItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'משימת בדיקה מהמעבדה',
                  level: 3,
                  isGolden: true,
                );

                await taskService.saveTask(newTask);
                if (context.mounted) _showMessage(context, '✅ משימה נשמרה!');
              },
              child: const Text('צור משימה (Task)'),
            ),
            const SizedBox(height: 16),

            // כפתור 2: בדיקת פרויקט
            ElevatedButton(
              onPressed: () async {
                final projectService = context.read<ProjectService>();

                final newProject = ProjectItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'פרויקט השתלטות על העולם',
                  description: 'שלב א: לכתוב קוד בפלאטר',
                );

                await projectService.saveProject(newProject);
                if (context.mounted) _showMessage(context, '✅ פרויקט נשמר!');
              },
              child: const Text('צור פרויקט (Project)'),
            ),
            const SizedBox(height: 16),

            // כפתור 3: בדיקת רשימה יומית
            ElevatedButton(
              onPressed: () async {
                final dailyService = context.read<DailyTaskService>();

                final newDaily = DailyTaskItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: 'לשתות מים 💧',
                );

                await dailyService.saveDailyTask(newDaily);
                if (context.mounted)
                  _showMessage(context, '✅ משימה יומית נשמרה!');
              },
              child: const Text('צור משימה יומית (Daily)'),
            ),
            const SizedBox(height: 16),

            // כפתור 4: בדיקת המחיקה הגורפת שביקשת!
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
              ),
              onPressed: () async {
                final dailyService = context.read<DailyTaskService>();

                await dailyService.clearAllDailyTasks();
                if (context.mounted)
                  _showMessage(context, '🗑️ הרשימה היומית אופסה!');
              },
              child: const Text('נקה רשימה יומית (Clear Daily)'),
            ),
          ],
        ),
      ),
    );
  }
}
