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
    final allConfigs = gamificationService.binderConfigs;

    // הלוגיקה החשובה: חותכים את רשימת האלבומים כך שתציג רק עד לאלבום הנוכחי של המשתמש.
    // אם המשתמש ב-currentBinder מספר 1, הוא יראה רק את דור 1.
    final visibleConfigs = allConfigs
        .take(gamificationService.currentBinder)
        .toList();

    return DefaultTabController(
      length: visibleConfigs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ביינדר'),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            tabs: visibleConfigs
                .map((config) => Tab(text: config.theme))
                .toList(),
          ),
        ),
        drawer: const AppDrawer(),
        body: TabBarView(
          children: visibleConfigs.map((config) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio:
                    0.8, // הארכנו מעט את הקלף כדי שיהיה מקום לטקסט
              ),
              itemCount: config.itemIds.length,
              itemBuilder: (context, index) {
                final itemId = config.itemIds[index];
                final isUnlocked = unlocked.contains(itemId);

                // משיכת השם מהשירות. אם נעול, נציג סימני שאלה.
                final pokemonName = isUnlocked
                    ? gamificationService.getItemName(itemId)
                    : '???';
                final imageUrl =
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$itemId.png';

                return Card(
                  color: Colors.grey.shade900,
                  clipBehavior:
                      Clip.antiAlias, // מוודא שהפס התחתון לא חורג מפינות הקלף
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
                      // התמונה של הפוקימון
                      Positioned(
                        top: 4,
                        bottom: 35, // משאיר מקום לפס הטקסט למטה
                        child: ColorFiltered(
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
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.catching_pokemon,
                              color: isUnlocked
                                  ? Colors.amber
                                  : Colors.grey.shade800,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      // פס המידע בתחתית הקלף (שם ומספר)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pokemonName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '#$itemId',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isUnlocked
                                      ? Colors.amber
                                      : Colors.grey.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
