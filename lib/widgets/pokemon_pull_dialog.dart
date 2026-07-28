import 'package:flutter/material.dart';

class PokemonPullDialog extends StatelessWidget {
  final int pokemonId;

  const PokemonPullDialog({super.key, required this.pokemonId});

  @override
  Widget build(BuildContext context) {
    // We use the official artwork from PokeAPI for high-quality images
    final imageUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$pokemonId.png';

    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '🎉 New Pokémon Unlocked! 🎉',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A simple zoom-in animation using TweenAnimationBuilder
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, double scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Image.network(
              imageUrl,
              height: 200,
              width: 200,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, size: 50, color: Colors.red),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pokémon #$pokemonId has been added to your binder!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
      actions: [
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text(
              'Awesome!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
