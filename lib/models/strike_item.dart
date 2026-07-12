class StrikeItem {
  final String id;
  String title;
  int streak;
  String lastIncrementDate;
  bool isPunishable; // Determines if breaking it early costs coins

  StrikeItem({
    required this.id,
    required this.title,
    this.streak = 0,
    String? lastIncrementDate,
    this.isPunishable = false,
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
      'isPunishable': isPunishable,
    };
  }

  factory StrikeItem.fromMap(String id, Map<String, dynamic> map) {
    return StrikeItem(
      id: id,
      title: map['title'] ?? '',
      streak: (map['streak'] ?? 0).toInt(),
      lastIncrementDate: map['lastIncrementDate'] ?? '',
      isPunishable: map['isPunishable'] ?? false,
    );
  }
}
