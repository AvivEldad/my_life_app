import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

class BinderScreen extends StatelessWidget {
  const BinderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gamificationService = context.watch<GamificationService>();
    final unlocked = gamificationService.unlockedPokemons;
    // אנו שולפים את רשימת האלבומים מהשירות
    final configs = gamificationService.binderConfigs;

    // עוטפים את המסך בבקר לשוניות שמתאים אוטומטית למספר האלבומים שלנו
    return DefaultTabController(
      length: configs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('האלבומים שלי'),
          centerTitle: true,
          // יצירת הלשוניות בחלק התחתון של סרגל הכלים העליון
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            // עוברים על כל אלבום ומייצרים לו לשונית עם השם שלו
            tabs: configs.map((config) => Tab(text: config.theme)).toList(),
          ),
        ),
        drawer: const AppDrawer(),

        // כאן נמצא התוכן של כל לשונית
        body: TabBarView(
          children: configs.map((config) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              // כמות הפריטים עכשיו תלויה בדיוק באלבום הספציפי!
              itemCount: config.itemIds.length,
              itemBuilder: (context, index) {
                // שליפת המזהה המדויק מתוך רשימת המזהים של האלבום
                final itemId = config.itemIds[index];
                final isUnlocked = unlocked.contains(itemId);

                // הקישור של פוקימון. עבור אלבום 2 זה יחזיר שגיאה ויופעל הגיבוי
                final imageUrl =
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$itemId.png';

                return Card(
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isUnlocked ? Colors.amber : Colors.transparent,
                      width: isUnlocked ? 2 : 0,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ColorFiltered(
                        colorFilter: isUnlocked
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.multiply,
                              )
                            : const ColorFilter.mode(
                                Colors.black,
                                BlendMode.srcIn,
                              ),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          // במקרה שאין תמונה (כמו באלבום מארוול הזמני), נציג אייקון
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.star_rounded,
                            color: isUnlocked
                                ? Colors.amber
                                : Colors.grey.shade800,
                            size: 50,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 6,
                        child: Text(
                          '#$itemId',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        ),

        bottomNavigationBar: BottomNavigationBar(
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainLayout(initialIndex: index),
              ),
            );
          },
        ),
      ),
    );
  }
}
