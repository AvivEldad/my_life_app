import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // משיכת מידות המסך של המכשיר הספציפי
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      // התפריט יתפוס בדיוק 65% מרוחב המסך, לא משנה איזה מכשיר זה
      width: screenWidth * 0.50,
      child: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              //TODO: add logo or image
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'רמה 1  |  0 🪙',
                  // הקטנו את גודל הטקסט כך שיהיה עדין יותר אבל קריא
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('הפרסים שלי'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('מנטרות'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Spacer(),

            // --- קו ההפרדה מעל ההגדרות והאודות ---
            const Divider(color: Colors.white24, height: 1),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('הגדרות'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('מסך הגדרות ייבנה בקרוב...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('אודות האפליקציה'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            // רווח חכם בתחתית שמתחשב במבנה המכשיר (למשל הפס השחור של האייפון)
            SizedBox(height: bottomPadding > 0 ? bottomPadding : 16.0),
          ],
        ),
      ),
    );
  }
}
