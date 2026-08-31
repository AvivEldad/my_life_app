import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prize_item.dart';
import '../services/prize_service.dart';
import '../services/gamification_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confetti_dialog.dart';
import 'main_layout.dart';

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
            message: 'תהנה מ-\n${prize.title}',
            image: const Icon(
              Icons.card_giftcard,
              color: Colors.amber,
              size: 80,
            ),
          ),
        );
      }

      if (!prize.isRepeatable) {
        await prizeService.deletePrize(prize.id);
      } else {
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
            final prizes = List<PrizeItem>.from(snapshot.data ?? [])
              ..sort((a, b) => a.cost.compareTo(b.cost));
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
                  margin: const EdgeInsets.symmetric(
                    vertical: 6.0,
                  ), // צמצום המרווח בין הכרטיסים
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
                    padding: const EdgeInsets.all(
                      10,
                    ), // הקטנת הריווח הפנימי למראה צר יותר
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
                                  fontSize: 18, // הקטנת גודל הכותרת קלות
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
                            // הקטנת כפתורי העריכה והמחיקה כדי לחסוך מקום
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    _showPrizeDialog(context, prize: prize),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () => _confirmDelete(context, prize),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4), // צמצום הרווח האנכי

                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${prize.cost} 🪙',
                                style: TextStyle(
                                  fontSize: 14,
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
                                fontSize: 12,
                                color: isAvailable
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 8,
                        ), // צמצום הרווח העליון של הכפתור

                        SizedBox(
                          width: double.infinity,
                          height: 40, // הגדרת גובה כפתור נמוך וקומפקטי יותר
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAvailable
                                  ? Colors.amber
                                  : Colors.grey.shade800,
                              foregroundColor: isAvailable
                                  ? Colors.black
                                  : Colors.grey,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: isAvailable
                                ? () => _redeemPrize(parentContext, prize)
                                : null,
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 14,
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