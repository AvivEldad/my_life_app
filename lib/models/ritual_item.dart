import 'package:flutter/material.dart';

enum RitualRecurrence { daily, weekly, monthly }

class RitualItem {
  final String id;
  String title;
  String? description;
  int level;
  bool isCompleted;
  RitualRecurrence recurrence;
  TimeOfDay? reminderTime;
  int? repeatValue;
  String? categoryId;

  RitualItem({
    required this.id,
    required this.title,
    this.description,
    this.level = 1,
    this.isCompleted = false,
    required this.recurrence,
    this.reminderTime,
    this.repeatValue,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'level': level,
      'isCompleted': isCompleted,
      'recurrence': recurrence.index,
      'reminderHour': reminderTime?.hour,
      'reminderMinute': reminderTime?.minute,
      'repeatValue': repeatValue,
      'categoryId': categoryId,
    };
  }

  factory RitualItem.fromMap(String id, Map<String, dynamic> map) {
    final recurrenceIndex = (map['recurrence'] as int?) ?? 0;
    final reminderHour = map['reminderHour'] as int?;
    final reminderMinute = map['reminderMinute'] as int?;

    return RitualItem(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      level: (map['level'] as int?) ?? 1,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      recurrence: RitualRecurrence
          .values[recurrenceIndex.clamp(0, RitualRecurrence.values.length - 1)],
      reminderTime: reminderHour != null && reminderMinute != null
          ? TimeOfDay(hour: reminderHour, minute: reminderMinute)
          : null,
      repeatValue: map['repeatValue'] as int?,
      categoryId: map['categoryId'] as String?,
    );
  }
}
