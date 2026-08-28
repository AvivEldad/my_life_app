import 'package:flutter/material.dart';
import '../models/project_item.dart';

class CreateProjectScreen extends StatefulWidget {
  // כאשר קיים פרויקט קיים - המסך עובד במצב עריכה במקום יצירה
  final ProjectItem? existingProject;

  const CreateProjectScreen({super.key, this.existingProject});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  // בקרים (Controllers) ששומרים את מה שהמשתמש מקליד בשדות הטקסט
  late final _titleController = TextEditingController(
    text: widget.existingProject?.title ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.existingProject?.description ?? '',
  );

  // משתנה ששומר האם הפרויקט הוא טורי (ברירת המחדל היא שקר - לא טורי)
  late bool _isSequential = widget.existingProject?.isSequential ?? false;

  bool get _isEditing => widget.existingProject != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // פונקציה שתופעל כשנלחץ על כפתור השמירה
  void _saveProject() {
    // בודקים שהמשתמש הקליד שם לפרויקט
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('חובה להזין שם פרויקט')));
      return;
    }

    // יוצרים את אובייקט הפרויקט - שומר על ה-ID והנתונים הקיימים (כולל
    // מצב ההשלמה ותגמולים שכבר ניתנו) אם אנחנו עורכים פרויקט קיים
    final project = ProjectItem(
      id: widget.existingProject?.id ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      isSequential: _isSequential,
      isCompleted: widget.existingProject?.isCompleted ?? false,
      completedAt: widget.existingProject?.completedAt,
      createdAt: widget.existingProject?.createdAt,
      awardedXp: widget.existingProject?.awardedXp,
      awardedCoins: widget.existingProject?.awardedCoins,
      causedLevelUp: widget.existingProject?.causedLevelUp ?? false,
      xpThresholdBeforeLevelUp:
          widget.existingProject?.xpThresholdBeforeLevelUp,
      awardedPokemonId: widget.existingProject?.awardedPokemonId,
    );

    // סוגרים את המסך ומחזירים את הפרויקט למסך הקודם
    Navigator.pop(context, project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'עריכת פרויקט' : 'פרויקט חדש'),
        centerTitle: true,
      ),
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
              subtitle: const Text(
                'ניתן לבצע רק את המשימה הבאה בתור - שאר המשימות ננעלות',
              ),
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
                child: Text(
                  _isEditing ? 'שמור שינויים' : 'שמור פרויקט',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
