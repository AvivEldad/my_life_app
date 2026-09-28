import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_item.dart';
import '../models/habit_item.dart';
import 'penalty_policy.dart';
import '../constants/pokemon_constants.dart';
import 'notification_service.dart';
import '../models/project_item.dart';

class BinderConfig {
  final int level;
  final String theme;
  final List<int> itemIds;

  BinderConfig({
    required this.level,
    required this.theme,
    required this.itemIds,
  });
}

class GamificationService extends ChangeNotifier {
  // Database instance for saving our gamification stats
  final FirebaseFirestore _db;
  final Future<void> Function(double) _coinReminder;
  Future<void> _operations = Future<void>.value();

  int currentXp = 0;
  double currentCoins = 0.0;
  int currentXpThreshold = 100;
  int currentLevel = 1;
  List<int> unlockedPokemons = [];
  int currentBinder = 1;
  int totalCoinsSpent = 0;
  int totalXpEarned = 0;
  int totalTasksCompleted = 0;
  Map<String, dynamic> completedCategoriesCount = {};

  // The constructor runs automatically when the service is initialized
  GamificationService({
    FirebaseFirestore? firestore,
    Future<void> Function(double)? refreshCoinReminder,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _coinReminder =
           refreshCoinReminder ?? NotificationService().refreshCoinReminder {
    _serialize(_loadGamificationData).catchError((Object error) {
      debugPrint('Error loading gamification data: $error');
    });
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<T> _mutate<T>(Future<T> Function() action) => _serialize(() async {
    // A failed read must never turn default values into a saved balance.
    await _loadGamificationData();
    return action();
  });

  /// Pulls existing data from Firebase when the app starts
  Future<void> _loadGamificationData() async {
    try {
      final doc = await _db
          .collection('gamification')
          .doc('user_stats')
          .get(const GetOptions(source: Source.server));
      if (doc.exists) {
        final data = doc.data()!;
        currentXp = data['currentXp'] ?? 0;
        currentCoins = (data['currentCoins'] ?? 0).toDouble();
        currentXpThreshold = data['currentXpThreshold'] ?? 100;
        currentLevel = data['currentLevel'] ?? 1;
        unlockedPokemons = List<int>.from(data['unlockedPokemons'] ?? []);
        currentBinder = data['currentBinder'] ?? 1;

        // טעינת הסטטיסטיקות החדשות (אם הן לא קיימות, ניקח את ה-XP הנוכחי כברירת מחדל)
        totalCoinsSpent = data['totalCoinsSpent'] ?? 0;
        totalXpEarned = data['totalXpEarned'] ?? currentXp;
        totalTasksCompleted = data['totalTasksCompleted'] ?? 0;
        completedCategoriesCount = Map<String, dynamic>.from(
          data['completedCategoriesCount'] ?? {},
        );

        // Repair saved overflow from daily rewards that skipped level-ups.
        if (currentXpThreshold > 0 && currentXp >= currentXpThreshold) {
          _applyPendingLevelUps();
          await _saveData();
        }

        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveData() async {
    try {
      await _db.collection('gamification').doc('user_stats').set({
        'currentXp': currentXp,
        'currentCoins': currentCoins,
        'currentXpThreshold': currentXpThreshold,
        'currentLevel': currentLevel,
        'unlockedPokemons': unlockedPokemons,
        'currentBinder': currentBinder,

        // שמירת הסטטיסטיקות החדשות
        'totalCoinsSpent': totalCoinsSpent,
        'totalXpEarned': totalXpEarned,
        'totalTasksCompleted': totalTasksCompleted,
        'completedCategoriesCount': completedCategoriesCount,
      }, SetOptions(merge: true));

      await _refreshCoinReminder();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _refreshCoinReminder() async {
    try {
      await _coinReminder(currentCoins);
    } catch (error) {
      // Reminder failures must not make a committed balance change look failed.
      debugPrint('Could not refresh coin reminder: $error');
    }
  }

  Future<bool> spendCoins(int amount) => _mutate(() async {
    if (currentCoins >= amount) {
      currentCoins -= amount;
      totalCoinsSpent += amount;
      await _saveData();
      notifyListeners();
      return true;
    }
    return false;
  });

  /// Triggered when a task is checked off
  Future<int?> processTaskCompletion(TaskItem task) => _mutate(() async {
    final multiplier = task.isGolden ? 2 : 1;
    int earnedXp = task.level * 10 * multiplier;
    int earnedCoins = task.level * 5 * multiplier;

    if (task.isWeekly) {
      int currentDay = DateTime.now().weekday;
      int daysLeft = currentDay == 7
          ? 6
          : 6 - currentDay; // ראשון=6, שני=5..., שבת=0
      earnedXp += (task.level * 10) * daysLeft;
      earnedCoins += (task.level * 5) * daysLeft;
    }
    currentXp += earnedXp;
    currentCoins += earnedCoins;
    totalXpEarned += earnedXp;

    int? pulledPokemonId;
    bool leveledUp = false;
    int? thresholdBeforeLevelUp;
    // Check if we hit the threshold
    if (currentXp >= currentXpThreshold) {
      thresholdBeforeLevelUp = currentXpThreshold;
      currentXp -= currentXpThreshold;
      currentXpThreshold = (currentXpThreshold * 1.1).toInt();
      currentLevel++;
      leveledUp = true;
      pulledPokemonId = _pullPokemon();
    }

    // Stamp exactly what this completion granted onto the task itself,
    // so processTaskUncompletion can reverse it precisely later even if
    // task.level or task.isGolden change in the meantime (e.g. via edit).
    task.awardedXp = earnedXp;
    task.awardedCoins = earnedCoins;
    task.causedLevelUp = leveledUp;
    task.xpThresholdBeforeLevelUp = thresholdBeforeLevelUp;
    task.awardedPokemonId = pulledPokemonId;

    totalTasksCompleted++;
    String catId = task.categoryId ?? 'none';
    int catCount = (completedCategoriesCount[catId] as num?)?.toInt() ?? 0;
    completedCategoriesCount[catId] = catCount + 1;

    await _saveData();
    notifyListeners();

    return pulledPokemonId;
  });

  /// Triggered when every task in a project has been completed.
  /// Grants a flat 100 coins / 200 xp bonus (on top of whatever each task
  /// already granted individually).
  Future<int?> processProjectCompletion(ProjectItem project) =>
      _mutate(() async {
        const earnedXp = 200;
        const earnedCoins = 100;
        currentXp += earnedXp;
        currentCoins += earnedCoins;
        totalXpEarned += earnedXp;
        int? pulledPokemonId;
        bool leveledUp = false;
        int? thresholdBeforeLevelUp;
        if (currentXp >= currentXpThreshold) {
          thresholdBeforeLevelUp = currentXpThreshold;
          currentXp -= currentXpThreshold;
          currentXpThreshold = (currentXpThreshold * 1.1).toInt();
          currentLevel++;
          leveledUp = true;
          pulledPokemonId = _pullPokemon();
        }
        // Stamp what this completion granted onto the project itself, so
        // un-completing it later (e.g. re-opening one of its tasks) can
        // reverse it precisely — same pattern as processTaskCompletion.
        project.awardedXp = earnedXp;
        project.awardedCoins = earnedCoins;
        project.causedLevelUp = leveledUp;
        project.xpThresholdBeforeLevelUp = thresholdBeforeLevelUp;
        project.awardedPokemonId = pulledPokemonId;
        await _saveData();
        notifyListeners();
        return pulledPokemonId;
      });

  /// Reverses a project-completion reward — used if a task inside an
  /// already-completed project gets un-checked again.
  Future<void> processProjectUncompletion(ProjectItem project) =>
      _mutate(() async {
        if (project.awardedXp == null && project.awardedCoins == null) return;
        final xpToRemove = project.awardedXp ?? 0;
        final coinsToRemove = project.awardedCoins ?? 0;
        if (project.causedLevelUp) {
          currentLevel = currentLevel > 1 ? currentLevel - 1 : 1;
          currentXp += project.xpThresholdBeforeLevelUp ?? 0;
          if (project.xpThresholdBeforeLevelUp != null) {
            currentXpThreshold = project.xpThresholdBeforeLevelUp!;
          }
          if (project.awardedPokemonId != null) {
            unlockedPokemons.remove(project.awardedPokemonId);
          }
        }
        currentXp -= xpToRemove;
        if (currentXp < 0) currentXp = 0;
        totalXpEarned -= xpToRemove;
        if (totalXpEarned < 0) totalXpEarned = 0;
        currentCoins -= coinsToRemove;
        if (currentCoins < 0) currentCoins = 0;
        project.awardedXp = null;
        project.awardedCoins = null;
        project.causedLevelUp = false;
        project.xpThresholdBeforeLevelUp = null;
        project.awardedPokemonId = null;
        await _saveData();
        notifyListeners();
      });

  // A habit is worth the same as a level-1 task.
  static const int habitXpValue = 10;
  static const int habitCoinsValue = 5;
  static const double habitMissCoins = 0.5;
  static const int habitMissXp = 2;

  /// Triggered when a habit is marked done.
  Future<int?> processHabitCompletion() => _mutate(() async {
    currentXp += habitXpValue;
    currentCoins += habitCoinsValue;
    totalXpEarned += habitXpValue;

    int? pulledPokemonId;
    if (currentXp >= currentXpThreshold) {
      currentXp -= currentXpThreshold;
      currentXpThreshold = (currentXpThreshold * 1.1).toInt();
      currentLevel++;
      pulledPokemonId = _pullPokemon();
    }

    await _saveData();
    notifyListeners();

    return pulledPokemonId;
  });

  Future<int?> addCoinsAndXp(num coins, int xp) => _mutate(() async {
    currentCoins += coins;
    currentXp += xp;
    totalXpEarned += xp;

    final pulledPokemonId = _applyPendingLevelUps();

    await _saveData();
    notifyListeners();

    return pulledPokemonId;
  });

  int? _applyPendingLevelUps() {
    int? pulledPokemonId;
    while (currentXpThreshold > 0 && currentXp >= currentXpThreshold) {
      currentXp -= currentXpThreshold;
      currentXpThreshold = (currentXpThreshold * 1.1).toInt();
      currentLevel++;
      pulledPokemonId = _pullPokemon();
    }
    return pulledPokemonId;
  }

  final List<BinderConfig> binderConfigs = [
    BinderConfig(
      level: 1,
      theme: 'Gen 1 (Kanto)',
      itemIds: List.generate(151, (index) => index + 1),
    ),
    BinderConfig(
      level: 2,
      theme: 'Gen 2 (Johto)',
      itemIds: List.generate(100, (index) => index + 152),
    ),
    BinderConfig(
      level: 3,
      theme: 'Gen 3 (Hoenn)',
      itemIds: List.generate(135, (index) => index + 252),
    ),
    BinderConfig(
      level: 4,
      theme: 'Gen 4 (Sinnoh)',
      itemIds: List.generate(107, (index) => index + 387),
    ),
    BinderConfig(
      level: 5,
      theme: 'Gen 5 (Unova)',
      itemIds: List.generate(156, (index) => index + 494),
    ),
    BinderConfig(
      level: 6,
      theme: 'Gen 6 (Kalos)',
      itemIds: List.generate(72, (index) => index + 650),
    ),
    BinderConfig(
      level: 7,
      theme: 'Gen 7 (Alola)',
      itemIds: List.generate(88, (index) => index + 722),
    ),
    BinderConfig(
      level: 8,
      theme: 'Gen 8 (Galar)',
      itemIds: List.generate(96, (index) => index + 810),
    ),
    BinderConfig(
      level: 9,
      theme: 'Gen 9 (Paldea)',
      itemIds: List.generate(120, (index) => index + 906),
    ),
  ];

  /// Triggered when a previously-completed task is unchecked. Reverses
  /// exactly what processTaskCompletion granted for THIS task — using the
  /// amounts stamped on the task at completion time, not whatever
  /// task.level/isGolden happen to be now.
  Future<void> processTaskUncompletion(TaskItem task) => _mutate(() async {
    // This task was never completed through processTaskCompletion (e.g.
    // legacy data from before this feature), so there's nothing to undo.
    if (task.awardedXp == null && task.awardedCoins == null) return;

    final xpToRemove = task.awardedXp ?? 0;
    final coinsToRemove = task.awardedCoins ?? 0;

    if (task.causedLevelUp) {
      // Step the level back down (never below 1) and restore the XP
      // threshold that was in effect before this completion's level-up.
      currentLevel = currentLevel > 1 ? currentLevel - 1 : 1;
      currentXp += task.xpThresholdBeforeLevelUp ?? 0;
      if (task.xpThresholdBeforeLevelUp != null) {
        currentXpThreshold = task.xpThresholdBeforeLevelUp!;
      }

      // Remove the specific Pokémon this completion's level-up pulled.
      if (task.awardedPokemonId != null) {
        unlockedPokemons.remove(task.awardedPokemonId);
      }
    }

    currentXp -= xpToRemove;
    if (currentXp < 0) currentXp = 0;
    totalXpEarned -= xpToRemove;
    if (totalXpEarned < 0) totalXpEarned = 0;
    currentCoins -= coinsToRemove;
    if (currentCoins < 0) currentCoins = 0;

    // Clear the awarded-state so a future re-completion of this task
    // awards fresh, rather than accumulating stale bookkeeping.
    task.awardedXp = null;
    task.awardedCoins = null;
    task.causedLevelUp = false;
    task.xpThresholdBeforeLevelUp = null;
    task.awardedPokemonId = null;

    if (totalTasksCompleted > 0) totalTasksCompleted--;
    String catId = task.categoryId ?? 'none';
    int catCount = (completedCategoriesCount[catId] as num?)?.toInt() ?? 0;
    if (catCount > 0) {
      completedCategoriesCount[catId] = catCount - 1;
    }

    await _saveData();
    notifyListeners();
  });

  String getItemName(int id) {
    return pokemonNames[id] ?? 'Pokemon #$id';
  }

  /// לוגיקת משיכה אוניברסלית (ללא if-else!)
  int? _pullPokemon() {
    // 1. מוצאים את הגדרות האלבום הנוכחי מתוך הרשימה
    final currentConfig = binderConfigs.firstWhere(
      (config) => config.level == currentBinder,
      orElse: () => binderConfigs.last, // גיבוי למקרה חירום
    );

    // 2. מסננים את המזהים הפנויים לאלבום הזה
    List<int> availableIds = currentConfig.itemIds
        .where((id) => !unlockedPokemons.contains(id))
        .toList();

    // 3. משיכת הדמות
    if (availableIds.isNotEmpty) {
      final random = Random();
      int randomIndex = random.nextInt(availableIds.length);
      int pulledId = availableIds[randomIndex];

      unlockedPokemons.add(pulledId);
      return pulledId;
    } else {
      // 4. אם האלבום מלא, עוברים אוטומטית לאלבום הבא
      if (currentBinder < binderConfigs.length) {
        currentBinder++; // מעלים רמה לאלבום הבא
        debugPrint(
          '🎉 מזל טוב! פתחת את אלבום: ${binderConfigs[currentBinder - 1].theme}',
        );
        return _pullPokemon(); // מנסים למשוך שוב מיד מהאלבום החדש
      } else {
        debugPrint('מדהים! סיימת את כל האלבומים באפליקציה!');
        return null;
      }
    }
  }

  /// Checks if enough time has passed to purchase a prize
  bool canPurchasePrize(DateTime? lastPurchasedAt, Duration cooldownDuration) {
    if (lastPurchasedAt == null) return true;
    final difference = DateTime.now().difference(lastPurchasedAt);
    return difference >= cooldownDuration;
  }

  Future<void> processOverduePenalties() => _mutate(() async {
    final now = DateTime.now();
    final snapshot = await _db
        .collection('tasks')
        .where('isCompleted', isEqualTo: false)
        .get();
    for (final document in snapshot.docs) {
      await _db.runTransaction((transaction) async {
        final fresh = await transaction.get(document.reference);
        final statsRef = _db.collection('gamification').doc('user_stats');
        final stats = await transaction.get(statsRef);
        final data = fresh.data();
        if (data == null || data['isCompleted'] == true) return;
        final penalty = PenaltyPolicy.task(data, now);
        if (penalty.updates.isEmpty) return;
        transaction.update(document.reference, penalty.updates);
        transaction.set(
          statsRef,
          PenaltyPolicy.apply(
            stats.data() ?? {},
            penalty.coins,
            penalty.xp,
            now,
          ),
          SetOptions(merge: true),
        );
      });
    }
    await _loadGamificationData();
    await _refreshCoinReminder();
  });

  /// Read the occurrence again inside the transaction: a stale screen or
  /// another device must not charge the same miss twice.
  Future<HabitItem?> processMissedHabit(String habitId) => _mutate(() async {
    final now = DateTime.now();
    final habitRef = _db.collection('habits').doc(habitId);
    final result = await _db.runTransaction<HabitItem?>((transaction) async {
      final document = await transaction.get(habitRef);
      final statsRef = _db.collection('gamification').doc('user_stats');
      final stats = await transaction.get(statsRef);
      final data = document.data();
      if (data == null) return null;
      final habit = HabitItem.fromMap(habitId, data);
      if (now.isBefore(habit.missDeadline)) return null;
      // Skip the historical backlog, charging at most one occurrence.
      do {
        habit.markMissed();
      } while (!now.isBefore(habit.missDeadline));
      transaction.update(habitRef, habit.toMap());
      transaction.set(
        statsRef,
        PenaltyPolicy.apply(
          stats.data() ?? {},
          habitMissCoins,
          habitMissXp,
          now,
        ),
        SetOptions(merge: true),
      );
      return habit;
    });
    await _loadGamificationData();
    if (result != null) await _refreshCoinReminder();
    return result;
  });

  Future<void> addDailyRewards(double coins, int xp) async {
    await addCoinsAndXp(coins, xp);
  }
}
