import 'package:flutter/material.dart';
import '../models/strike_item.dart';

class CreateStrikeScreen extends StatefulWidget {
  // כאשר קיים סטרייק קיים - המסך עובד במצב עריכה במקום יצירה
  final StrikeItem? existingStrike;

  const CreateStrikeScreen({super.key, this.existingStrike});

  @override
  State<CreateStrikeScreen> createState() => _CreateStrikeScreenState();
}

class _CreateStrikeScreenState extends State<CreateStrikeScreen> {
  late final _titleController = TextEditingController(
    text: widget.existingStrike?.title ?? '',
  );

  bool get _isEditing => widget.existingStrike != null;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveStrike() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('חובה להזין שם לסטרייק')));
      return;
    }

    // שומרים על כל הנתונים הקיימים (כולל הרצף הנוכחי והבונוסים שכבר
    // הוענקו) אם אנחנו רק עורכים את השם של סטרייק קיים
    final strike = StrikeItem(
      id: widget.existingStrike?.id ?? '',
      title: _titleController.text.trim(),
      streak: widget.existingStrike?.streak ?? 0,
      lastIncrementDate: widget.existingStrike?.lastIncrementDate,
      isPunishable: widget.existingStrike?.isPunishable ?? false,
      createdAt: widget.existingStrike?.createdAt,
      rewardedWeekMilestones:
          widget.existingStrike?.rewardedWeekMilestones ?? 0,
      rewardedMonthMilestones:
          widget.existingStrike?.rewardedMonthMilestones ?? 0,
    );

    Navigator.pop(context, strike);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'עריכת סטרייק' : 'סטרייק חדש'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'מה תרצה לעקוב אחריו?',
                hintText: 'לדוגמה: אכילה בריאה, ספורט...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_fire_department),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveStrike,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                child: Text(
                  _isEditing ? 'שמור שינויים' : 'שמור סטרייק',
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
