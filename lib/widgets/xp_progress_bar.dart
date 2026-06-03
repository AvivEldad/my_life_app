import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/coin_service.dart';

class XpProgressBar extends StatelessWidget {
  const XpProgressBar({super.key});

  // Helper to determine the Rank based on unique unlocked counts
  String _getCollectorRank(int unlockedCount) {
    if (unlockedCount == 151) return 'Mew Tier (מאסטר)';
    if (unlockedCount >= 111) return 'Master Collector';
    if (unlockedCount >= 71) return 'Gold Collector';
    if (unlockedCount >= 31) return 'Silver Collector';
    return 'Bronze Collector';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CoinService>(
      builder: (context, coinService, child) {
        final totalCoins = coinService.totalCoins;
        final xp = coinService.xp;
        final maxXp = coinService.xpRequiredPerPull;
        final unlockedCount = coinService.unlockedPokemon.length;
        
        // Calculate progress (0.0 to 1.0)
        final progress = (xp / maxXp).clamp(0.0, 1.0);
        final rank = _getCollectorRank(unlockedCount);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row: Rank and Coins
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'דרגת אספן: $rank',
                          style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$unlockedCount / 151 נתפסו',
                          style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          totalCoins.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // The XP Progress Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Bottom Contextual Tracker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'XP למשיכה הבאה',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '$xp / $maxXp XP',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}