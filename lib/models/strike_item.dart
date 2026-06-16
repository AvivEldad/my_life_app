class StrikeItem {
  final String id;
  String title;
  int streak;
  String lastIncrementDate;

  StrikeItem({
    required this.id,
    required this.title,
    this.streak = 0,
    String? lastIncrementDate,
  }) : lastIncrementDate = lastIncrementDate ?? '';

  static String todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get incrementedToday => lastIncrementDate == todayString();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'streak': streak,
      'lastIncrementDate': lastIncrementDate,
    };
  }

  factory StrikeItem.fromMap(String id, Map<String, dynamic> map) {
    return StrikeItem(
      id: id,
      title: map['title'] ?? '',
      streak: (map['streak'] ?? 0).toInt(),
      lastIncrementDate: map['lastIncrementDate'] ?? '',
    );
  }
}