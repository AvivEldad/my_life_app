import 'package:flutter/material.dart';
import '../models/strike_item.dart';
import '../services/database_service.dart';

class StrikesPage extends StatefulWidget {
  const StrikesPage({super.key});

  @override
  State<StrikesPage> createState() => _StrikesPageState();
}

class _StrikesPageState extends State<StrikesPage> with WidgetsBindingObserver {
  List<StrikeItem> _goals = [];
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGoalsFromDb(); 
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadGoalsFromDb() async {
    setState(() => _isLoading = true);
    try {
      final goals = await DatabaseService.loadStrikes();
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
      _autoIncrementAll(); 
    } catch (e) {
      print("Error loading strikes: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoIncrementAll();
    }
  }

  void _autoIncrementAll() {
    bool hasChanges = false;
    
    setState(() {
      for (final goal in _goals) {
        if (!goal.incrementedToday) {
          goal.streak++;
          goal.lastIncrementDate = StrikeItem.todayString();
          DatabaseService.updateStrike(goal); // עדכון ב-Firebase
          hasChanges = true;
        }
      }
    });
  }

  void _resetGoal(StrikeItem goal) {
    setState(() {
      goal.streak = 0;
      goal.lastIncrementDate = '';
    });
    DatabaseService.updateStrike(goal);
  }

  void _deleteGoal(StrikeItem goal) {
    setState(() => _goals.removeWhere((g) => g.id == goal.id));
    DatabaseService.deleteStrike(goal.id);
  }

  void _showAddDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('סטרייק חדש'),
          content: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'תאר את מטרה שלך'),
            onChanged: (_) => setDialogState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitAdd(controller.text),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
            ElevatedButton(
              onPressed: controller.text.trim().isEmpty ? null : () => _submitAdd(controller.text),
              child: const Text('הוסף'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAdd(String title) async {
    final text = title.trim();
    if (text.isEmpty) return;
    
    Navigator.pop(context); 

    final newItem = StrikeItem(
      id: '',
      title: text,
      streak: 1,
      lastIncrementDate: StrikeItem.todayString(),
    );

    final newId = await DatabaseService.addStrike(newItem);
    
    setState(() {
      _goals.add(StrikeItem(
        id: newId, 
        title: newItem.title,
        streak: newItem.streak,
        lastIncrementDate: newItem.lastIncrementDate,
      ));
    });
  }

  String _streakLabel(int streak) {
    if (streak == 0) return 'טרם התחיל';
    if (streak == 1) return 'יום 1';
    return '$streak ימים';
  }

  Color _streakColor(int streak) {
    if (streak == 0) return Colors.grey;
    if (streak < 7) return Colors.orange;
    if (streak < 30) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) // הצגת ספינר בזמן טעינה
          : _goals.isEmpty
            ? Center(
                child: Text(
                  'אין מטרות עדיין\nלחץ + כדי להוסיף',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _goals.length,
                itemBuilder: (context, index) {
                  final goal = _goals[index];
                  final color = _streakColor(goal.streak);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('מחיקת סטרייק'),
                                    content: Text('למחוק את "${goal.title}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
                                      ElevatedButton(
                                        onPressed: () {
                                          _deleteGoal(goal);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('מחק'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                goal.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('איפוס סטריק'),
                                    content: Text('לאפס את הסטריק של "${goal.title}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
                                      ElevatedButton(
                                        onPressed: () {
                                          _resetGoal(goal);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('אפס'),
                                      ),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  'איפוס',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    _streakLabel(goal.streak),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    goal.streak == 0 ? '○' : '🔥',
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (goal.incrementedToday)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '✓ עודכן היום',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}