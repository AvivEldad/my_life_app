class PrizeItem {
  final String id;
  String title;
  int cost;
  bool isRedeemed;
  bool isRepeatable;
  int cooldownHours;
  DateTime? lastRedeemed;

  PrizeItem({
    required this.id,
    required this.title,
    required this.cost,
    this.isRedeemed = false,
    this.isRepeatable = false,
    this.cooldownHours = 24,
    this.lastRedeemed,
  });

  bool get isOnCooldown {
    if (lastRedeemed == null || !isRepeatable) return false;
    final timeSinceRedeemed = DateTime.now().difference(lastRedeemed!);
    return timeSinceRedeemed.inHours < cooldownHours;
  }

  int get remainingCooldownHours {
    if (lastRedeemed == null || !isRepeatable) return 0;
    final timeSinceRedeemed = DateTime.now().difference(lastRedeemed!);
    return cooldownHours - timeSinceRedeemed.inHours;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'cost': cost,
      'isRedeemed': isRedeemed,
      'isRepeatable': isRepeatable,
      'cooldownHours': cooldownHours,
      'lastRedeemed': lastRedeemed?.millisecondsSinceEpoch,
    };
  }

  factory PrizeItem.fromMap(String id, Map<String, dynamic> map) {
    return PrizeItem(
      id: id,
      title: map['title'] ?? '',
      cost: (map['cost'] ?? 0).toInt(),
      isRedeemed: map['isRedeemed'] ?? false,
      isRepeatable: map['isRepeatable'] ?? false,
      cooldownHours: map['cooldownHours'] ?? 24,
      lastRedeemed: map['lastRedeemed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastRedeemed'])
          : null,
    );
  }
}
