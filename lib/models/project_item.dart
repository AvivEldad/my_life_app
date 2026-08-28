class ProjectItem {
  String id;
  String title;
  String description;
  bool isSequential;

  bool isCompleted;
  DateTime? completedAt;
  DateTime createdAt;

  // Records exactly what completing this project granted, so that
  // un-completing it (e.g. re-opening a task) can reverse the reward
  // precisely, the same way TaskItem does for individual tasks.
  int? awardedXp;
  int? awardedCoins;
  bool causedLevelUp;
  int? xpThresholdBeforeLevelUp;
  int? awardedPokemonId;

  ProjectItem({
    required this.id,
    required this.title,
    this.description = '',
    this.isSequential = false,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    this.awardedXp,
    this.awardedCoins,
    this.causedLevelUp = false,
    this.xpThresholdBeforeLevelUp,
    this.awardedPokemonId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isSequential': isSequential,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'awardedXp': awardedXp,
      'awardedCoins': awardedCoins,
      'causedLevelUp': causedLevelUp,
      'xpThresholdBeforeLevelUp': xpThresholdBeforeLevelUp,
      'awardedPokemonId': awardedPokemonId,
    };
  }

  factory ProjectItem.fromMap(Map<String, dynamic> map, String documentId) {
    final completedAtMs = map['completedAt'] as int?;
    final createdAtMs = map['createdAt'] as int?;

    return ProjectItem(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isSequential: map['isSequential'] ?? false,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      completedAt: completedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(completedAtMs)
          : null,
      createdAt: createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now(),
      awardedXp: map['awardedXp'] as int?,
      awardedCoins: map['awardedCoins'] as int?,
      causedLevelUp: (map['causedLevelUp'] as bool?) ?? false,
      xpThresholdBeforeLevelUp: map['xpThresholdBeforeLevelUp'] as int?,
      awardedPokemonId: map['awardedPokemonId'] as int?,
    );
  }
}
