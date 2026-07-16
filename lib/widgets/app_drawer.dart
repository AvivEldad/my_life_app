import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // פונקציה חכמה לחישוב התג הנכון (ספירה מעגלית של 36 תגים)
  String _getBadgePath(int level) {
    // שימוש במודולו (שארית חלוקה):
    // רמה 36 -> תג 36. רמה 37 -> תג 1. רמה 38 -> תג 2.
    int badgeNumber = ((level - 1) % 36) + 1;
    return 'assets/images/badge_0$badgeNumber.png';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // משתנים זמניים לרמה ומטבעות
    // (כשתהיה לנו מערכת גיימיפיקציה, נמשוך אותם מ-Provider כאן)
    int currentLevel = 1;
    int currentCoins = 0;

    return SizedBox(
      // התפריט יתפוס בדיוק 50% מרוחב המסך, כמו שביקשת
      width: screenWidth * 0.50,
      child: Drawer(
        child: Column(
          children: [
            // שים לב: הסרנו את ה-const מכאן, כי הנתונים בפנים משתנים!
            DrawerHeader(
              // קצת שליטה על הריווח הפנימי כדי שזה יישב טוב
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              // החלפנו Row ב-Column!
              child: Column(
                crossAxisAlignment: CrossAxisAlignment
                    .start, // מיישר את התוכן לימין (בגלל שהאפליקציה ב-RTL)
                mainAxisAlignment: MainAxisAlignment
                    .end, // דוחף את התוכן לחלק התחתון של הכותרת
                children: [
                  // התמונה הוקטנה ל-40
                  Image.asset(
                    _getBadgePath(currentLevel),
                    width: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.shield,
                        size: 40,
                        color: Colors.amber,
                      );
                    },
                  ),
                  const SizedBox(height: 12), // רווח אנכי בין התמונה לטקסט

                  Text(
                    'רמה $currentLevel  |  $currentCoins 🪙',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // --- פריטי התפריט העליונים ---
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('הפרסים שלי'),
              onTap: () {
                Navigator.pop(context);
                // TODO: ניווט למסך פרסים
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('מנטרות'),
              onTap: () {
                Navigator.pop(context);
                // TODO: ניווט למסך מנטרות
              },
            ),

            const Spacer(),

            // --- פריטים בתחתית התפריט ---
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
            SizedBox(height: bottomPadding > 0 ? bottomPadding : 16.0),
          ],
        ),
      ),
    );
  }
}
