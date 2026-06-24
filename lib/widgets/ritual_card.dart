import 'package:flutter/material.dart';
import '../models/ritual_item.dart';
import '../models/category_item.dart';

class RitualCard extends StatelessWidget {
  final RitualItem ritual;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final CategoryItem? category;

  const RitualCard({
    super.key,
    required this.ritual,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.category,
  });

  String _getRecurrenceDetails(BuildContext context) {
    String time = ritual.reminderTime?.format(context) ?? "";
    String timeStr = time.isNotEmpty ? ' ב-$time' : '';

    switch (ritual.recurrence) {
      case RitualRecurrence.daily:
        return 'כל יום$timeStr';
      case RitualRecurrence.weekly:
        List<String> days = [
          '',
          'א\'',
          'ב\'',
          'ג\'',
          'ד\'',
          'ה\'',
          'ו\'',
          'ש\'',
        ];
        int dayIndex = ritual.repeatValue ?? 1;
        if (dayIndex < 1 || dayIndex > 7) dayIndex = 1;
        return 'כל יום ${days[dayIndex]}$timeStr';
      case RitualRecurrence.monthly:
        return 'ב-${ritual.repeatValue ?? 1} לכל חודש$timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color? stripeColor = category?.color;

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Checkbox(
        value: ritual.isCompleted,
        onChanged: (v) => onToggle(),
        activeColor: Colors.amber,
        shape: const CircleBorder(),
      ),
      title: Text(
        ritual.title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          decoration: ritual.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ritual.description != null && ritual.description!.isNotEmpty) ...[
            Text(ritual.description!, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              if (category != null) ...[
                Icon(Icons.label, size: 14, color: stripeColor ?? Colors.grey),
                const SizedBox(width: 4),
                Text(category!.name, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.sync, size: 14, color: Colors.blueAccent),
              const SizedBox(width: 4),
              Text(
                _getRecurrenceDetails(context),
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
          IconButton(
            icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: stripeColor == null
          ? tile
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: stripeColor),
                  Expanded(child: tile),
                ],
              ),
            ),
    );
  }
}
