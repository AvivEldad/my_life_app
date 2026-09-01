class SubTask {
  final String id;
  String title;
  bool isCompleted;

  SubTask({required this.id, required this.title, this.isCompleted = false});

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'isCompleted': isCompleted};
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}

class TaskItem {
  final String id;
  String title;
  String? description;
  DateTime? dueDate;
  int level;
  bool isCompleted;
  bool isGolden;
  String? categoryId;
  bool isActive;
  List<SubTask> subTasks;

  String? projectId;
  String? projectName;

  int orderIndex;
  DateTime createdAt;
  DateTime? completedAt;
  DateTime? lastPenaltyDate;

  // Records exactly what the current completion granted, so that
  // un-completing the task can reverse it precisely (independent of
  // whatever task.level happens to be later, e.g. after an edit).
  int? awardedXp;
  int? awardedCoins;
  bool causedLevelUp;
  int? xpThresholdBeforeLevelUp;
  int? awardedPokemonId;

  bool isWeekly;
  DateTime? weeklyDeadline;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.level = 1,
    this.isCompleted = false,
    this.isGolden = false,
    this.categoryId,
    this.isActive = false,
    List<SubTask>? subTasks,
    this.projectId,
    this.projectName,
    this.orderIndex = 0,
    DateTime? createdAt,
    this.completedAt,
    this.lastPenaltyDate,
    this.awardedXp,
    this.awardedCoins,
    this.causedLevelUp = false,
    this.xpThresholdBeforeLevelUp,
    this.awardedPokemonId,
    this.isWeekly = false,
    DateTime? weeklyDeadline,
  }) : subTasks = subTasks ?? [],
       this.createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'level': level,
      'isCompleted': isCompleted,
      'isGolden': isGolden,
      'categoryId': categoryId,
      'isActive': isActive,
      'subTasks': subTasks.map((e) => e.toMap()).toList(),
      'projectId': projectId,
      'projectName': projectName,
      'orderIndex': orderIndex,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'lastPenaltyDate': lastPenaltyDate?.millisecondsSinceEpoch,
      'awardedXp': awardedXp,
      'awardedCoins': awardedCoins,
      'causedLevelUp': causedLevelUp,
      'xpThresholdBeforeLevelUp': xpThresholdBeforeLevelUp,
      'awardedPokemonId': awardedPokemonId,
      'isWeekly': isWeekly,
      'weeklyDeadline': weeklyDeadline?.millisecondsSinceEpoch,
    };
  }

  factory TaskItem.fromMap(String id, Map<String, dynamic> map) {
    final dueDateMs = map['dueDate'] as int?;
    final subTasksList = map['subTasks'] as List<dynamic>?;
    final completedAtMs = map['completedAt'] as int?;
    final lastPenaltyMs = map['lastPenaltyDate'] as int?;

    return TaskItem(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      dueDate: dueDateMs != null
          ? DateTime.fromMillisecondsSinceEpoch(dueDateMs)
          : null,
      level: (map['level'] as int?) ?? 1,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      isGolden: (map['isGolden'] as bool?) ?? false,
      categoryId: map['categoryId'] as String?,
      isActive: (map['isActive'] as bool?) ?? false,
      subTasks: subTasksList != null
          ? subTasksList
                .map((e) => SubTask.fromMap(e as Map<String, dynamic>))
                .toList()
          : [],
      projectId: map['projectId'] as String?,
      projectName: map['projectName'] as String?,
      orderIndex: (map['orderIndex'] as int?) ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      completedAt: completedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(completedAtMs)
          : null,
      lastPenaltyDate: lastPenaltyMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastPenaltyMs)
          : null,
      awardedXp: map['awardedXp'] as int?,
      awardedCoins: map['awardedCoins'] as int?,
      causedLevelUp: (map['causedLevelUp'] as bool?) ?? false,
      xpThresholdBeforeLevelUp: map['xpThresholdBeforeLevelUp'] as int?,
      awardedPokemonId: map['awardedPokemonId'] as int?,
      isWeekly: map['isWeekly'] ?? false,
      weeklyDeadline: map['weeklyDeadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['weeklyDeadline'])
          : null,
    );
  }
}
