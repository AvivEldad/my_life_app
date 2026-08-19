import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prize_item.dart';
import '../services/prize_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confetti_dialog.dart';

class PrizesPage extends StatelessWidget {
  const PrizesPage({super.key});

  void _showPrizeDialog(BuildContext context, {PrizeItem? prize}) {
    final isEditing = prize != null;
    final titleController = TextEditingController(text: prize?.title ?? '');
    final costController = TextEditingController(
      text: prize?.cost.toString() ?? '',
    );
    bool isRepeatable = prize?.isRepeatable ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEditing ? 'עריכת פרס' : 'פרס חדש',
            style: const TextStyle(color: Colors.amber),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'שם הפרס',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'עלות (מטבעות)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.amber,
                title: const Text(
                  'פרס מתחדש? (כל 24 שעות)',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                value: isRepeatable,
                onChanged: (val) {
                  setDialogState(() => isRepeatable = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (titleController.text.isNotEmpty &&
                    costController.text.isNotEmpty) {
                  final newPrize = PrizeItem(
                    id:
                        prize?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    cost: int.tryParse(costController.text) ?? 0,
                    isRepeatable: isRepeatable,
                    isRedeemed: prize?.isRedeemed ?? false,
                    lastRedeemed: prize?.lastRedeemed,
                  );
                  context.read<PrizeService>().savePrize(newPrize);
                  Navigator.pop(context);
                }
              },
              child: Text(
                isEditing ? 'שמור' : 'צור',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PrizeItem prize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('מחיקת פרס', style: TextStyle(color: Colors.white)),
        content: Text(
          'האם אתה בטוח שברצונך למחוק את "${prize.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              context.read<PrizeService>().deletePrize(prize.id);
              Navigator.pop(context);
            },
            child: const Text('מחק', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _redeemPrize(BuildContext context, PrizeItem prize) async {
    final gamificationService = context.read<GamificationService>();
    final prizeService = context.read<PrizeService>();

    bool success = await gamificationService.spendCoins(prize.cost);

    if (success) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => ConfettiDialog(
            title: 'פרס נרכש!',
            message: '-תהנה מ\n${prize.title}',
            image: const Icon(
              Icons.card_giftcard,
              color: Colors.amber,
              size: 80,
            ),
          ),
        );
      }

      // הלוגיקה החדשה: האם למחוק או לעדכן?
      if (!prize.isRepeatable) {
        // פרס חד-פעמי -> מחיקה מוחלטת
        await prizeService.deletePrize(prize.id);
      } else {
        // פרס מתחדש -> עדכון זמן הרכישה
        prize.isRedeemed = true;
        prize.lastRedeemed = DateTime.now();
        await prizeService.savePrize(prize);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamificationService = context.watch<GamificationService>();
    final currentCoins = gamificationService.currentCoins;

    // אנו שומרים את ה-Context הראשי של המסך כולו כדי שהאנימציה לא תלך לאיבוד
    final parentContext = context;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('הפרסים שלי ($currentCoins 🪙)'),
          centerTitle: true,
        ),
        drawer: const AppDrawer(),
        body: StreamBuilder<List<PrizeItem>>(
          stream: context.read<PrizeService>().streamPrizes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final prizes = snapshot.data ?? [];
            if (prizes.isEmpty) {
              return const Center(
                child: Text('אין פרסים עדיין. לחץ על + כדי להוסיף.'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: prizes.length,
              itemBuilder: (context, index) {
                final prize = prizes[index];

                bool canAfford = currentCoins >= prize.cost;
                bool isLocked = prize.isRedeemed && !prize.isRepeatable;
                bool isCooldown = prize.isOnCooldown;
                bool isAvailable = canAfford && !isLocked && !isCooldown;

                String buttonText = 'ממש פרס';
                if (isLocked)
                  buttonText = 'נרכש בעבר';
                else if (isCooldown)
                  buttonText = 'בהמתנה (${prize.remainingCooldownHours} שעות)';
                else if (!canAfford)
                  buttonText = 'חסר ${prize.cost - currentCoins} 🪙';

                return Card(
                  elevation: isAvailable ? 8 : 0,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isAvailable
                          ? Colors.amber.withOpacity(0.5)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: isAvailable
                            ? [Colors.grey.shade800, Colors.grey.shade900]
                            : [Colors.grey.shade900, Colors.grey.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                prize.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable
                                      ? Colors.white
                                      : Colors.grey,
                                  decoration: isLocked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _showPrizeDialog(context, prize: prize),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(context, prize),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${prize.cost} 🪙',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable
                                      ? Colors.amber
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              prize.isRepeatable
                                  ? 'מתחדש (24 שעות)'
                                  : 'חד-פעמי',
                              style: TextStyle(
                                fontSize: 13,
                                color: isAvailable
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAvailable
                                  ? Colors.amber
                                  : Colors.grey.shade800,
                              foregroundColor: isAvailable
                                  ? Colors.black
                                  : Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            // שימוש ב-parentContext כדי להבטיח שהאנימציה תוצג!
                            onPressed: isAvailable
                                ? () => _redeemPrize(parentContext, prize)
                                : null,
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showPrizeDialog(context),
          backgroundColor: Colors.amber,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }
}
