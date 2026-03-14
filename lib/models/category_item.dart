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
    Color(0xFFEF5350), // red
    Color(0xFFFF7043), // deep orange
    Color(0xFFFFCA28), // amber
    Color(0xFF66BB6A), // green
    Color(0xFF26C6DA), // cyan
    Color(0xFF42A5F5), // blue
    Color(0xFF7E57C2), // purple
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF78909C), // blue grey
  ];
}