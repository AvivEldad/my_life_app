import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_item.dart';
import '../models/habit_item.dart';
import '../services/category_service.dart';
import '../services/habit_service.dart';

/// Hebrew weekday labels keyed by DateTime.weekday (1 = Monday ... 7 = Sunday).
const Map<int, String> kHebrewWeekdays = {
  DateTime.monday: 'יום שני',
  DateTime.tuesday: 'יום שלישי',
  DateTime.wednesday: 'יום רביעי',
  DateTime.thursday: 'יום חמישי',
  DateTime.friday: 'יום שישי',
  DateTime.saturday: 'שבת',
  DateTime.sunday: 'יום ראשון',
};

class HabitFormScreen extends StatefulWidget {
  final HabitItem? habit;

  const HabitFormScreen({super.key, this.habit});

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  late final TextEditingController _summaryController;
  late final TextEditingController _descriptionController;

  String? _categoryId;
  HabitRecurrence _recurrence = HabitRecurrence.daily;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  int _weekday = DateTime.monday;
  int _monthDay = 1;
  int _monthInterval = 1;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _summaryController = TextEditingController(text: habit?.summary ?? '');
    _descriptionController = TextEditingController(
      text: habit?.description ?? '',
    );
    _categoryId = habit?.categoryId;
    _recurrence = habit?.recurrence ?? HabitRecurrence.daily;
    _reminderTime = habit?.reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
    _weekday = habit?.weekday ?? DateTime.monday;
    _monthDay = habit?.monthDay ?? 1;
    _monthInterval = habit?.monthInterval ?? 1;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  void _save() {
    if (_summaryController.text.trim().isEmpty) return;

    final habitService = context.read<HabitService>();
    final id =
        widget.habit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final habit = HabitItem(
      id: id,
      summary: _summaryController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      categoryId: _categoryId,
      recurrence: _recurrence,
      reminderTime: _reminderTime,
      weekday: _recurrence == HabitRecurrence.weekly ? _weekday : null,
      monthDay: _recurrence == HabitRecurrence.monthly ? _monthDay : null,
      monthInterval: _recurrence == HabitRecurrence.monthly
          ? _monthInterval
          : null,
      // Editing an existing habit keeps its streak/history, but if the
      // recurrence settings changed we still need a due date consistent
      // with the new settings.
      nextDueDate: widget.habit != null
          ? widget.habit!.nextDueDate
          : DateTime.now(),
      lastCompletedDate: widget.habit?.lastCompletedDate,
      currentStreak: widget.habit?.currentStreak ?? 0,
      longestStreak: widget.habit?.longestStreak ?? 0,
      snoozeCount: widget.habit?.snoozeCount ?? 0,
      snoozedUntil: widget.habit?.snoozedUntil,
      createdAt: widget.habit?.createdAt,
    );

    final recurrenceChanged =
        widget.habit == null ||
        widget.habit!.recurrence != _recurrence ||
        widget.habit!.reminderTime != _reminderTime ||
        widget.habit!.weekday != habit.weekday ||
        widget.habit!.monthDay != habit.monthDay ||
        widget.habit!.monthInterval != habit.monthInterval;

    if (recurrenceChanged) {
      habit.nextDueDate = habit.computeInitialNextDueDate();
    }

    habitService.saveHabit(habit);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'עריכת הרגל' : 'הרגל חדש'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _summaryController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'כותרת',
                hintText: 'לדוגמה: אימון יומי',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              textAlign: TextAlign.right,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'תיאור (לא חובה)'),
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'תדירות',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<HabitRecurrence>(
              segments: const [
                ButtonSegment(
                  value: HabitRecurrence.daily,
                  label: Text('יומי'),
                ),
                ButtonSegment(
                  value: HabitRecurrence.weekly,
                  label: Text('שבועי'),
                ),
                ButtonSegment(
                  value: HabitRecurrence.monthly,
                  label: Text('חודשי'),
                ),
              ],
              selected: {_recurrence},
              onSelectionChanged: (selection) =>
                  setState(() => _recurrence = selection.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('שעה'),
              trailing: Text(_reminderTime.format(context)),
              onTap: _pickTime,
            ),
            if (_recurrence == HabitRecurrence.weekly) _buildWeeklyOptions(),
            if (_recurrence == HabitRecurrence.monthly) _buildMonthlyOptions(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(_isEditing ? 'שמור שינויים' : 'צור הרגל'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return StreamBuilder<List<CategoryItem>>(
      stream: context.read<CategoryService>().streamCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        return DropdownButtonFormField<String?>(
          initialValue: _categoryId,
          decoration: const InputDecoration(labelText: 'קטגוריה'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('ללא קטגוריה'),
            ),
            ...categories.map(
              (c) =>
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
            ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        );
      },
    );
  }

  Widget _buildWeeklyOptions() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('יום בשבוע'),
      trailing: DropdownButton<int>(
        value: _weekday,
        items: kHebrewWeekdays.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _weekday = value);
        },
      ),
    );
  }

  Widget _buildMonthlyOptions() {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('יום בחודש'),
          trailing: DropdownButton<int>(
            value: _monthDay,
            items: List.generate(31, (i) => i + 1)
                .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _monthDay = value);
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('כל כמה חודשים'),
          trailing: DropdownButton<int>(
            value: _monthInterval,
            items: List.generate(12, (i) => i + 1)
                .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _monthInterval = value);
            },
          ),
        ),
      ],
    );
  }
}
