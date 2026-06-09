import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/coin_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BinderPage extends StatelessWidget {
  const BinderPage({super.key});

  // Generates the public PokeAPI sprite URL based on the Pokedex ID
  String _getSpriteUrl(int id) {
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Consumer<CoinService>(
          builder: (context, coinService, child) {
            final unlocked = coinService.unlockedPokemon;
            final totalUnlocked = unlocked.length;

            return Column(
              children: [
                // Stats Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[900]?.withOpacity(0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'האוסף שלי',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$totalUnlocked / 151',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
                
                // Binder Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: 151,
                    itemBuilder: (context, index) {
                      final pokemonId = index + 1;
                      final isUnlocked = unlocked.contains(pokemonId);

                      return Container(
                        decoration: BoxDecoration(
                          color: isUnlocked ? Colors.grey[850] : Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUnlocked ? Colors.amber.withOpacity(0.6) : Colors.grey[800]!,
                            width: isUnlocked ? 2 : 1,
                          ),
                          boxShadow: [
                            if (isUnlocked)
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.1),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ID Number
                            Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                                child: Text(
                                  '#${pokemonId.toString().padLeft(3, '0')}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isUnlocked ? Colors.amber : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Sprite Image (Silhouette if locked)
                            Expanded(
                              child: isUnlocked
                                  ? CachedNetworkImage(
                                      imageUrl: _getSpriteUrl(pokemonId),
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => const SizedBox(
                                        width: 20, 
                                        height: 20, 
                                        child: CircularProgressIndicator(strokeWidth: 2)
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                    )
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Colors.black,
                                        BlendMode.srcATop,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: _getSpriteUrl(pokemonId),
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const SizedBox.shrink(),
                                        errorWidget: (context, url, error) => const Icon(Icons.help_outline),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}