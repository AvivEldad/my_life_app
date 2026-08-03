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

    return Scaffold(
      appBar: AppBar(centerTitle: true),
      drawer: const AppDrawer(),
      // A GridView that creates exactly 151 slots
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 characters per row
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 151,
        itemBuilder: (context, index) {
          final pokemonId = index + 1;
          final isUnlocked = unlocked.contains(pokemonId);
          final imageUrl =
              'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$pokemonId.png';

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
                // If unlocked, show normal image. If locked, apply a solid black silhouette filter!
                ColorFiltered(
                  colorFilter: isUnlocked
                      ? const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        )
                      : const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.pest_control, color: Colors.grey),
                  ),
                ),
                // Show the ID number at the bottom right
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: Text(
                    '#$pokemonId',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        // הגדרנו צבע אפור כדי להראות שאף אחת מהלשוניות האלו לא פעילה כרגע
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
          // ברגע שלוחצים על משימות (0) או פרויקטים (1), מנווטים חזרה ל-MainLayout
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainLayout(initialIndex: index),
            ),
          );
        },
      ),
    );
  }
}
