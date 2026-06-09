import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/coin_service.dart';
import '../models/prize_item.dart';

class PrizesPage extends StatefulWidget {
  const PrizesPage({super.key});

  @override
  State<PrizesPage> createState() => _PrizesPageState();
}

class _PrizesPageState extends State<PrizesPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  void _showPrizeDialog({PrizeItem? existingPrize}) {
    if (existingPrize != null) {
      _titleController.text = existingPrize.title;
      _costController.text = existingPrize.cost.toString();
    } else {
      _titleController.clear();
      _costController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(existingPrize == null ? 'הוסף פרס חדש' : 'ערוך פרס'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(hintText: 'שם הפרס (לדוגמה: 30 דקות פלייסטיישן)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(hintText: 'עלות במטבעות'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = _titleController.text.trim();
                final cost = double.tryParse(_costController.text) ?? 0.0;
                
                if (title.isNotEmpty && cost > 0) {
                  final coinService = Provider.of<CoinService>(context, listen: false);
                  
                  if (existingPrize == null) {
                    // CREATE
                    coinService.addNewPrize(PrizeItem(
                      id: '', // Firebase will generate the ID
                      title: title,
                      cost: cost,
                    ));
                  } else {
                    // UPDATE
                    existingPrize.title = title;
                    existingPrize.cost = cost;
                    coinService.updatePrize(existingPrize);
                  }
                  
                  Navigator.pop(context);
                }
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showPrizeDialog(),
          backgroundColor: Colors.amber,
          child: const Icon(Icons.add, color: Colors.black),
        ),
        body: Consumer<CoinService>(
          builder: (context, coinService, child) {
            if (!coinService.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            final prizes = coinService.prizes;
            final walletBalance = coinService.totalCoins;

            if (prizes.isEmpty) {
              return const Center(
                child: Text('אין פרסים זמינים בחנות. לחץ על ה-+ להוספת מטרה!'),
              );
            }

            final sortedPrizes = List<PrizeItem>.from(prizes)
              ..sort((a, b) => a.cost.compareTo(b.cost));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedPrizes.length,
              itemBuilder: (context, index) {
                final prize = sortedPrizes[index];
                final canAfford = walletBalance >= prize.cost;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: prize.isRedeemed 
                      ? Colors.grey[950] 
                      : (canAfford ? Colors.grey[900] : Colors.grey[900]!.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: prize.isRedeemed 
                          ? Colors.transparent 
                          : (canAfford ? Colors.green.withOpacity(0.4) : Colors.grey[800]!),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: prize.isRedeemed 
                          ? Colors.grey[800] 
                          : (canAfford ? Colors.green : Colors.amber.withOpacity(0.2)),
                      child: Icon(
                        prize.isRedeemed ? Icons.check_circle_outline : Icons.card_giftcard,
                        color: prize.isRedeemed ? Colors.grey : (canAfford ? Colors.white : Colors.amber),
                      ),
                    ),
                    title: Text(
                      prize.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: prize.isRedeemed ? TextDecoration.lineThrough : null,
                        color: prize.isRedeemed ? Colors.grey : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      'עלות: ${prize.cost.toStringAsFixed(0)} מטבעות',
                      style: TextStyle(
                        color: prize.isRedeemed ? Colors.grey[700] : Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // CRUD Trailing Actions
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (prize.isRedeemed)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Text('מומש', style: TextStyle(color: Colors.grey)),
                          ),
                        if (!prize.isRedeemed)
                          ElevatedButton(
                            onPressed: canAfford
                                ? () {
                                    prize.isRedeemed = true;
                                    coinService.updatePrize(prize); // Update Cloud
                                    coinService.deductCoins(prize.cost); // Deduct Cloud
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('תהנה! מימשת בהצלחה: ${prize.title}'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              disabledBackgroundColor: Colors.grey[800],
                            ),
                            child: Text(
                              'ממש פרס',
                              style: TextStyle(
                                color: canAfford ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        // THE CRUD MENU
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showPrizeDialog(existingPrize: prize);
                            } else if (value == 'delete') {
                              coinService.deletePrize(prize.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('ערוך')]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('מחק', style: TextStyle(color: Colors.red))]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}