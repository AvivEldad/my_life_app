import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/coin_service.dart';

class CoinsProgressBar extends StatelessWidget {
  const CoinsProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CoinService>(
      builder: (context, coinService, child) {
        final totalCoins = coinService.totalCoins;
        final nextMilestone = coinService.getNextMilestone();
        final progress = coinService.getBarProgress();
        
        // Find the active milestone title for clear UX context
        final activePrizes = coinService.prizes.where((p) => !p.isRedeemed).toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
        final nextPrizeTitle = activePrizes.isNotEmpty ? activePrizes.first.title : 'כל הפרסים נפתחו!';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: progress >= 1.0 ? Colors.amber.withOpacity(0.5) : Colors.grey[800]!,
                width: 1.5,
              ),
              boxShadow: [
                if (progress >= 1.0)
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Counter Info Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          totalCoins.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const Text(
                          ' מטבעות',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    Text(
                      'יעד הבא: ${nextMilestone.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: progress >= 1.0 ? Colors.amber : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // The Filling Interactive Progress Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.greenAccent : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Bottom Contextual Tracker Footnote Label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        progress >= 1.0 
                            ? '🎉 המטרה הושגה! מוכן למימוש'
                            : 'מכוון אל: $nextPrizeTitle',
                        style: TextStyle(
                          fontSize: 12,
                          color: progress >= 1.0 ? Colors.greenAccent : Colors.grey[500],
                          fontWeight: progress >= 1.0 ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: progress >= 1.0 ? Colors.greenAccent : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
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