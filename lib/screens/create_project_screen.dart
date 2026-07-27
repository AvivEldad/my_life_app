import 'package:flutter/material.dart';
import '../models/project_item.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  // בקרים (Controllers) ששומרים את מה שהמשתמש מקליד בשדות הטקסט
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // משתנה ששומר האם הפרויקט הוא טורי (ברירת המחדל היא שקר - לא טורי)
  bool _isSequential = false;

  // פונקציה שתופעל כשנלחץ על כפתור השמירה
  void _saveProject() {
    // בודקים שהמשתמש הקליד שם לפרויקט
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('חובה להזין שם פרויקט')));
      return;
    }

    // יוצרים את אובייקט הפרויקט החדש עם הנתונים מהטופס
    final newProject = ProjectItem(
      id: '', // ה-ID ייווצר בהמשך על ידי Firebase כשנשמור אותו באמת
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      isSequential: _isSequential,
    );

    // סוגרים את המסך ומחזירים את הפרויקט החדש למסך הקודם
    Navigator.pop(context, newProject);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פרויקט חדש'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // שדה הזנת טקסט עבור שם הפרויקט
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'שם הפרויקט',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
            ),
            const SizedBox(height: 16),

            // שדה הזנת טקסט עבור תיאור הפרויקט
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'תיאור (אופציונלי)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3, // מאפשר טקסט ארוך יותר
            ),
            const SizedBox(height: 16),

            // מתג (Switch) להגדרת פרויקט טורי
            SwitchListTile(
              title: const Text('פרויקט טורי (Sequential)'),
              subtitle: const Text('ניתן לבצע רק את המשימה הבאה בתור'),
              value: _isSequential,
              activeColor: Colors.amber,
              onChanged: (bool value) {
                setState(() {
                  _isSequential = value;
                });
              },
            ),
            const Spacer(),

            // כפתור השמירה הגדול בתחתית המסך
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveProject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text(
                  'שמור פרויקט',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
