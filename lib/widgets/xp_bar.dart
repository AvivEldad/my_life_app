import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';

class XpBar extends StatelessWidget {
  const XpBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gamificationService = context.watch<GamificationService>();
    final currentXp = gamificationService.currentXp;
    final threshold = gamificationService.currentXpThreshold;

    // Calculate percentage, preventing division by zero
    double progress = threshold > 0 ? (currentXp / threshold) : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Next Pull:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '$currentXp / $threshold XP',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade800,
            color: Colors.amber, // Golden XP color
          ),
        ),
      ],
    );
  }
}
