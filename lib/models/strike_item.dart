class StrikeItem {
  final String id;
  String title;
  int streak;
  String lastIncrementDate;
  bool isPunishable; // Determines if breaking it early costs coins
  DateTime createdAt;

  // כמה "בונוסי שבוע" (כל 7 ימים) וכמה "בונוסי חודש" (כל 30 ימים) כבר
  // הוענקו על הסטרייק הזה - כדי שלא ניתן את אותו הבונוס פעמיים.
  int rewardedWeekMilestones;
  int rewardedMonthMilestones;

  StrikeItem({
    required this.id,
    required this.title,
    this.streak = 0,
    String? lastIncrementDate,
    this.isPunishable = false,
    DateTime? createdAt,
    this.rewardedWeekMilestones = 0,
    this.rewardedMonthMilestones = 0,
  }) : lastIncrementDate = lastIncrementDate ?? '',
       createdAt = createdAt ?? DateTime.now();

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
      'createdAt': createdAt.millisecondsSinceEpoch,
      'rewardedWeekMilestones': rewardedWeekMilestones,
      'rewardedMonthMilestones': rewardedMonthMilestones,
    };
  }

  factory StrikeItem.fromMap(String id, Map<String, dynamic> map) {
    final createdAtMs = map['createdAt'] as int?;

    return StrikeItem(
      id: id,
      title: map['title'] ?? '',
      streak: (map['streak'] ?? 0).toInt(),
      lastIncrementDate: map['lastIncrementDate'] ?? '',
      isPunishable: map['isPunishable'] ?? false,
      createdAt: createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
      rewardedWeekMilestones: (map['rewardedWeekMilestones'] ?? 0).toInt(),
      rewardedMonthMilestones: (map['rewardedMonthMilestones'] ?? 0).toInt(),
    );
  }
}
