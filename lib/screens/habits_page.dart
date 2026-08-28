import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_item.dart';
import '../services/gamification_service.dart';
import '../services/habit_service.dart';
import '../widgets/app_drawer.dart';
import 'habit_form_screen.dart';
import 'main_layout.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  StreamSubscription<List<HabitItem>>? _habitsSub;
  List<HabitItem> _habits = [];
  bool _isLoading = true;
  bool _hasProcessedMissed = false;

  @override
  void initState() {
    super.initState();
    final habitService = context.read<HabitService>();
    final gamificationService = context.read<GamificationService>();
    _habitsSub = habitService.streamHabits().listen((habits) {
      setState(() {
        _habits = habits;
        _isLoading = false;
      });

      // Habits use one-shot notifications while snoozed (and monthly
      // habits always do), so if the app wasn't open when a deadline
      // passed, this is where the miss penalty gets applied and the habit
      // is pushed on to its next occurrence.
      if (!_hasProcessedMissed) {
        _hasProcessedMissed = true;
        habitService.processDueAndMissedHabits(habits, gamificationService);
      }
    });
  }

  @override
  void dispose() {
    _habitsSub?.cancel();
    super.dispose();
  }

  String _recurrenceLabel(HabitItem habit) {
    final time = habit.reminderTime.format(context);
    switch (habit.recurrence) {
      case HabitRecurrence.daily:
        return 'כל יום ב-$time';
      case HabitRecurrence.weekly:
        final day = kHebrewWeekdays[habit.weekday ?? DateTime.monday];
        return 'כל שבוע ב$day ב-$time';
      case HabitRecurrence.monthly:
        final interval = habit.monthInterval ?? 1;
        final freq = interval == 1 ? 'כל חודש' : 'כל $interval חודשים';
        return '$freq, ב-${habit.monthDay} לחודש, ב-$time';
    }
  }

  Future<void> _markDone(HabitItem habit) async {
    final habitService = context.read<HabitService>();
    final gamificationService = context.read<GamificationService>();
    await habitService.markHabitDone(habit);
    await gamificationService.processHabitCompletion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'כל הכבוד! +${GamificationService.habitXpValue} XP, '
          '+${GamificationService.habitCoinsValue} מטבעות 🪙',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _snooze(HabitItem habit) async {
    final habitService = context.read<HabitService>();
    final didSnooze = await habitService.snoozeHabit(habit);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didSnooze
              ? 'התזכורת נדחתה ב-30 שעות'
              : 'אפשר לדחות הרגל עד פעמיים בלבד',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ההרגלים שלי'), centerTitle: true),
        drawer: const AppDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _habits.isEmpty
            ? Center(
                child: Text(
                  'אין הרגלים עדיין\nלחץ + כדי להוסיף',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : ListView.builder(
                itemCount: _habits.length,
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  return _HabitCard(
                    habit: habit,
                    recurrenceLabel: _recurrenceLabel(habit),
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HabitFormScreen(habit: habit),
                      ),
                    ),
                    onDelete: () =>
                        context.read<HabitService>().deleteHabit(habit.id),
                    onMarkDone: () => _markDone(habit),
                    onSnooze: () => _snooze(habit),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HabitFormScreen()),
          ),
          child: const Icon(Icons.add),
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

class _HabitCard extends StatelessWidget {
  final HabitItem habit;
  final String recurrenceLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkDone;
  final VoidCallback onSnooze;

  const _HabitCard({
    required this.habit,
    required this.recurrenceLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkDone,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  color: Colors.greenAccent,
                  onPressed: onMarkDone,
                  tooltip: 'סמן כבוצע',
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        habit.summary,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (habit.description != null &&
                          habit.description!.isNotEmpty)
                        Text(
                          habit.description!,
                          style: TextStyle(color: Colors.grey[400]),
                          textAlign: TextAlign.right,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.snooze),
                  color: habit.canSnooze ? Colors.amber : Colors.grey[700],
                  onPressed: onSnooze,
                  tooltip: habit.canSnooze
                      ? 'דחה תזכורת ב-30 שעות (${habit.snoozeCount}/${HabitItem.maxSnoozes})'
                      : 'נוצלו כל הדחיות (${HabitItem.maxSnoozes})',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                Text(
                  recurrenceLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                if (habit.currentStreak > 0) Text('🔥 ${habit.currentStreak}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
