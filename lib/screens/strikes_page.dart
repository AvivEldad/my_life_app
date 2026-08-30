import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/floating_reward.dart';
import '../widgets/confetti_dialog.dart';
import '../models/strike_item.dart';
import '../services/strike_service.dart';
import '../services/gamification_service.dart';
import 'create_strike_screen.dart';
import 'main_layout.dart';

class StrikesPage extends StatelessWidget {
  const StrikesPage({super.key});

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmLabel,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _deleteStrike(BuildContext context, StrikeItem strike) async {
    final confirmed = await _confirmDialog(
      context,
      title: 'מחיקת סטרייק',
      content:
          'האם אתה בטוח שברצונך למחוק את "${strike.title}"?\n'
          'הרצף הנוכחי (${strike.streak} ימים) יימחק לצמיתות.',
      confirmLabel: 'מחק',
      confirmColor: Colors.redAccent,
    );
    if (confirmed) {
      await context.read<StrikeService>().deleteStrike(strike.id);
    }
  }

  Future<void> _resetStrike(BuildContext context, StrikeItem strike) async {
    final confirmed = await _confirmDialog(
      context,
      title: 'איפוס סטרייק',
      content: 'לאפס את הרצף של "${strike.title}" חזרה ל-0 ימים?',
      confirmLabel: 'אפס',
      confirmColor: Colors.orange,
    );
    if (confirmed) {
      await context.read<StrikeService>().resetStrike(strike.id);
    }
  }

  Future<void> _editStrike(BuildContext context, StrikeItem strike) async {
    final edited = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStrikeScreen(existingStrike: strike),
      ),
    );
    if (edited != null && edited is StrikeItem) {
      await context.read<StrikeService>().saveStrike(edited);
    }
  }

  Future<void> _checkIn(BuildContext context, StrikeItem strike) async {
    if (strike.incrementedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('כבר סימנת את הסטרייק הזה היום! 🔥')),
      );
      return;
    }

    final strikeService = context.read<StrikeService>();
    final gamificationService = context.read<GamificationService>();

    final result = await strikeService.checkInStrike(
      strike.id,
      gamificationService,
    );

    if (result == null || !context.mounted) return;

    if (result.earnedAnyReward) {
      showFloatingReward(context, result.earnedCoins);

      String message;
      if (result.hitMonthMilestone && result.hitWeekMilestone) {
        message =
            'חודש שלם ברצף! קיבלת ${result.earnedCoins} מטבעות ו-${result.earnedXp} XP!';
      } else if (result.hitMonthMilestone) {
        message =
            'חודש שלם ברצף! קיבלת ${result.earnedCoins} מטבעות ו-${result.earnedXp} XP!';
      } else {
        message =
            'שבוע שלם ברצף! קיבלת ${result.earnedCoins} מטבע ו-${result.earnedXp} XP!';
      }

      await showDialog(
        context: context,
        builder: (context) => ConfettiDialog(
          title: '${result.strike.streak} ימים ברצף! 🔥',
          message: message,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('סומן! ${result.strike.streak} ימים ברצף 🔥')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strikeService = context.read<StrikeService>();

    return Scaffold(
      appBar: AppBar(title: const Text('הסטרייקים שלי'), centerTitle: true),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<StrikeItem>>(
        stream: strikeService.streamStrikes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('שגיאה בטעינת סטרייקים.'));
          }

          final strikes = List<StrikeItem>.from(snapshot.data ?? [])
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          if (strikes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'אין סטרייקים עדיין.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'לחץ על ה- + כדי להתחיל לעקוב אחרי הרגל חדש.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: strikes.length,
            itemBuilder: (context, index) {
              final strike = strikes[index];
              final doneToday = strike.incrementedToday;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.local_fire_department,
                    color: doneToday ? Colors.deepOrange : Colors.grey,
                    size: 32,
                  ),
                  title: Text(strike.title),
                  subtitle: Text(
                    '${strike.streak} ${strike.streak == 1 ? "יום" : "ימים"} ברצף'
                    '${doneToday ? " • סומן היום ✓" : ""}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _editStrike(context, strike),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteStrike(context, strike),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.restart_alt,
                          color: Colors.orange,
                        ),
                        tooltip: 'איפוס הרצף',
                        onPressed: () => _resetStrike(context, strike),
                      ),
                    ],
                  ),
                  onTap: () => _checkIn(context, strike),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newStrike = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateStrikeScreen()),
          );

          if (newStrike != null) {
            await strikeService.saveStrike(newStrike);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('נוצר סטרייק: ${newStrike.title}')),
              );
            }
          }
        },
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
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
    );
  }
}
