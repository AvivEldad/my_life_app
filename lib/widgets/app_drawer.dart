import 'package:flutter/material.dart';
import '../screens/main_layout.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import '../screens/binder_screen.dart';
import '../screens/categories_page.dart';
import '../screens/prizes_page.dart';
import '../screens/settings_page.dart';
import '../screens/ideas_page.dart';
import '../screens/mantras_page.dart';

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

    // משיכת נתונים אמיתיים מתוך השירות שיצרנו
    final gamificationService = context.watch<GamificationService>();
    int currentLevel = gamificationService.currentLevel;
    double currentCoins = gamificationService.currentCoins;

    return SizedBox(
      // התפריט יתפוס בדיוק 50% מרוחב המסך
      width: screenWidth * 0.50,
      child: Drawer(
        child: Column(
          children: [
            // הכותרת נשארת קבועה למעלה
            DrawerHeader(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                  const SizedBox(height: 12),
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
            const SizedBox(height: 4),

            // --- אזור התפריט הנגלל ---
            // ה-Expanded דואג שהרשימה תתפוס את כל המקום הפנוי ותאפשר גלילה
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero, // מסיר ריווח מיותר למעלה
                children: [
                  ListTile(
                    leading: const Icon(Icons.task),
                    title: const Text('המשימות שלי'),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MainLayout(initialIndex: 0),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('הפרויקטים שלי'),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MainLayout(initialIndex: 1),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    // TODO: לשנות אימוג'י
                    leading: const Icon(Icons.category),
                    title: const Text('ההרגלים שלי'),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: ניווט למסך
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: const Text('קטגוריות'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoriesPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    // TODO: לשנות אימוג'י
                    leading: const Icon(Icons.emoji_events),
                    title: const Text('סטרייקים'),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: ניווט למסך
                    },
                  ),
                  ListTile(
                    // TODO: לשנות אימוג'י
                    leading: const Icon(Icons.emoji_events),
                    title: const Text('רשימה יומית'),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: ניווט למסך
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bolt),
                    title: const Text('מנטרות'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MantrasPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_events),
                    title: const Text('הפרסים שלי'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrizesPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.book),
                    title: const Text('ביינדר'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BinderScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lightbulb),
                    title: const Text('רעיונות'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IdeasPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // --- פריטים בתחתית התפריט (קבועים למטה תמיד) ---
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('הגדרות'),
              onTap: () {
                Navigator.pop(context); // סגירת התפריט הצדדי
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),

            SizedBox(height: bottomPadding > 0 ? bottomPadding : 16.0),
          ],
        ),
      ),
    );
  }
}
