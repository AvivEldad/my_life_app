import 'package:flutter/material.dart';

enum RecurrenceType { none, daily, weekly, monthly }

class TodoItem {
  final String id;
  String title;
  String? description;
  DateTime? dueDate;
  int level;
  bool isCompleted;
  bool isGolden;
  RecurrenceType recurrence;
  TimeOfDay? reminderTime;
  int? repeatValue;
  String? categoryId;

  TodoItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.level = 1,
    this.isCompleted = false,
    this.isGolden = false,
    this.recurrence = RecurrenceType.none,
    this.reminderTime,
    this.repeatValue,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'level': level,
      'isCompleted': isCompleted,
      'isGolden': isGolden,
      'recurrence': recurrence.index,
      'reminderHour': reminderTime?.hour,
      'reminderMinute': reminderTime?.minute,
      'repeatValue': repeatValue,
      'categoryId': categoryId,
    };
  }

  factory TodoItem.fromMap(String id, Map<String, dynamic> map) {
    final recurrenceIndex = (map['recurrence'] as int?) ?? 0;
    final reminderHour = map['reminderHour'] as int?;
    final reminderMinute = map['reminderMinute'] as int?;
    final dueDateMs = map['dueDate'] as int?;

    return TodoItem(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      dueDate: dueDateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dueDateMs)
          : null,
      level: (map['level'] as int?) ?? 1,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      isGolden: (map['isGolden'] as bool?) ?? false,
      recurrence: RecurrenceType.values[
          recurrenceIndex.clamp(0, RecurrenceType.values.length - 1)],
      reminderTime: reminderHour != null && reminderMinute != null
          ? TimeOfDay(hour: reminderHour, minute: reminderMinute)
          : null,
      repeatValue: map['repeatValue'] as int?,
      categoryId: map['categoryId'] as String?,
    );
  }
}