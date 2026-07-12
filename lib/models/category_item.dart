import 'package:flutter/material.dart';

class CategoryItem {
  String id;
  String name;
  Color color;

  CategoryItem({
    required this.id,
    required this.name,
    required this.color,
  });

  static const List<Color> palette = [
    Color(0xFFEF5350),
    Color(0xFFFF7043),
    Color(0xFFFFCA28),
    Color(0xFF66BB6A),
    Color(0xFF26C6DA),
    Color(0xFF42A5F5),
    Color(0xFF7E57C2),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': color.value,
    };
  }

  factory CategoryItem.fromMap(String id, Map<String, dynamic> map) {
    return CategoryItem(
      id: id,
      name: map['name'] as String? ?? '',
      color: Color((map['colorValue'] as int?) ?? 0xFFFFCA28),
    );
  }
}