import 'package:flutter/material.dart';

class GlowingXpBar extends StatelessWidget {
  final int currentXp;
  final int threshold;

  const GlowingXpBar({
    Key? key,
    required this.currentXp,
    required this.threshold,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the percentage safely
    final double percentage = threshold > 0 ? (currentXp / threshold) : 0.0;

    return Container(
      height: 20,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            // Calculate the width based on the screen space available
            width: MediaQuery.of(context).size.width * percentage,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              '$currentXp / $threshold XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
