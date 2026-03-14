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
}