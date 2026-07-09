class PrizeItem {
  final String id;
  String title;
  double cost;
  bool isRedeemed;
  int cooldownHours; // How long until it can be bought again
  DateTime? lastRedeemed; // When it was last bought

  PrizeItem({
    required this.id,
    required this.title,
    required this.cost,
    this.isRedeemed = false,
    this.cooldownHours = 24, // Default to 24 hours
    this.lastRedeemed,
  });

  // Helper to check if the prize is currently locked
  bool get isOnCooldown {
    if (lastRedeemed == null) return false;
    final timeSinceRedeemed = DateTime.now().difference(lastRedeemed!);
    return timeSinceRedeemed.inHours < cooldownHours;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'cost': cost,
      'isRedeemed': isRedeemed,
      'cooldownHours': cooldownHours,
      'lastRedeemed': lastRedeemed?.millisecondsSinceEpoch,
    };
  }

  factory PrizeItem.fromMap(String id, Map<String, dynamic> map) {
    return PrizeItem(
      id: id,
      title: map['title'] ?? '',
      cost: (map['cost'] ?? 0).toDouble(),
      isRedeemed: map['isRedeemed'] ?? false,
      cooldownHours: map['cooldownHours'] ?? 24,
      lastRedeemed: map['lastRedeemed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastRedeemed'])
          : null,
    );
  }
}
