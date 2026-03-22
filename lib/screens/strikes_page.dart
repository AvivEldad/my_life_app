import 'package:flutter/material.dart';

class StrikeGoal {
  final String id;
  String title;
  int streak;
  String lastIncrementDate; // 'yyyy-M-d'

  StrikeGoal({
    required this.id,
    required this.title,
    this.streak = 0,
    String? lastIncrementDate,
  }) : lastIncrementDate = lastIncrementDate ?? '';

  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // Whether the streak was already incremented today
  bool get incrementedToday => lastIncrementDate == todayString();
}

class StrikesPage extends StatefulWidget {
  const StrikesPage({super.key});

  @override
  State<StrikesPage> createState() => _StrikesPageState();
}

class _StrikesPageState extends State<StrikesPage> with WidgetsBindingObserver {
  final List<StrikeGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Auto-increment all goals once per day when app is opened
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoIncrementAll();
    }
  }

  void _autoIncrementAll() {
    setState(() {
      for (final goal in _goals) {
        if (!goal.incrementedToday) {
          goal.streak++;
          goal.lastIncrementDate = StrikeGoal.todayString();
        }
      }
    });
  }

  void _resetGoal(StrikeGoal goal) {
    setState(() {
      goal.streak = 0;
      goal.lastIncrementDate = '';
    });
  }

  void _deleteGoal(StrikeGoal goal) {
    setState(() => _goals.removeWhere((g) => g.id == goal.id));
  }

  void _showAddDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('מטרה חדשה'),
          content: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'תאר את המטרה שלך'),
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

  void _submitAdd(String title) {
    final text = title.trim();
    if (text.isEmpty) return;
    setState(() {
      _goals.add(StrikeGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: text,
        streak: 1,
        lastIncrementDate: StrikeGoal.todayString(),
      ));
    });
    Navigator.pop(context);
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
        appBar: AppBar(
          title: const Text('סטריקים'),
        ),
        body: _goals.isEmpty
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
                          // Title row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('מחיקת מטרה'),
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
                              // Title
                              Text(
                                goal.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Streak counter
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Reset link
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
                              // Flame + counter
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
                          // Subtle "today" indicator
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