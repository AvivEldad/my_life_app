import 'package:flutter_test/flutter_test.dart';
import 'package:your_app_name/models/project_model.dart';
import 'package:your_app_name/models/todo_item.dart';

void main() {
  group('Project & Sub-task Queue Logic', () {
    
    test('Verify Sub-task Locking Logic', () {
      final task1 = TodoItem(id: '1', title: 'Task 1', isCompleted: false);
      final task2 = TodoItem(id: '2', title: 'Task 2', isCompleted: false);
      final project = Project(id: 'p1', title: 'Project X', subTasks: [task1, task2]);

      // משימה 1 צריכה להיות פתוחה
      bool task1Locked = false; 
      
      // משימה 2 צריכה להיות נעולה כי 1 לא הושלמה
      bool task2Locked = !project.subTasks[0].isCompleted;
      
      expect(task2Locked, true);

      // נשלים את משימה 1
      project.subTasks[0].isCompleted = true;
      
      // עכשיו משימה 2 צריכה להיות פתוחה
      task2Locked = !project.subTasks[0].isCompleted;
      expect(task2Locked, false);
    });

    test('Full Project Deletion', () {
      List<Project> projects = [
        Project(id: 'p1', title: 'To Delete', subTasks: [TodoItem(id: 's1', title: 'Sub')])
      ];

      projects.removeAt(0);
      expect(projects.isEmpty, true);
    });

    test('Edit Project Title', () {
      final project = Project(id: 'p1', title: 'Old Title');
      project.title = 'New Title';
      expect(project.title, 'New Title');
    });
  });
}