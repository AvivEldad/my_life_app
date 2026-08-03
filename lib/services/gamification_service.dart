import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_item.dart';

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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int currentXp = 0;
  int currentCoins = 0;
  int currentXpThreshold = 100;
  int currentLevel = 1;
  List<int> unlockedPokemons = [];
  int currentBinder = 1;

  // The constructor runs automatically when the service is initialized
  GamificationService() {
    _loadGamificationData();
  }

  /// Pulls existing data from Firebase when the app starts
  Future<void> _loadGamificationData() async {
    try {
      final doc = await _db.collection('gamification').doc('user_stats').get();
      if (doc.exists) {
        final data = doc.data()!;
        currentXp = data['currentXp'] ?? 0;
        currentCoins = data['currentCoins'] ?? 0;
        currentXpThreshold = data['currentXpThreshold'] ?? 100;
        currentLevel = data['currentLevel'] ?? 1;
        unlockedPokemons = List<int>.from(data['unlockedPokemons'] ?? []);
        currentBinder = data['currentBinder'] ?? 1;

        notifyListeners();
      }
    } catch (e) {
      print('Error loading gamification data: $e');
    }
  }

  /// Pushes the current state to Firebase
  Future<void> _saveData() async {
    try {
      await _db.collection('gamification').doc('user_stats').set({
        'currentXp': currentXp,
        'currentCoins': currentCoins,
        'currentXpThreshold': currentXpThreshold,
        'currentLevel': currentLevel,
        'unlockedPokemons': unlockedPokemons,
        'currentBinder': currentBinder,
      });
    } catch (e) {
      print('Error saving gamification data: $e');
    }
  }

  /// Triggered when a task is checked off
  Future<int?> processTaskCompletion(TaskItem task) async {
    final multiplier = task.isGolden ? 2 : 1;
    final earnedXp = task.level * 10 * multiplier;
    final earnedCoins = task.level * 5 * multiplier;

    currentXp += earnedXp;
    currentCoins += earnedCoins;

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

    await _saveData();
    notifyListeners();

    return pulledPokemonId;
  }

  final List<BinderConfig> binderConfigs = [
    BinderConfig(
      level: 1,
      theme: 'Pokemon Gen 1',
      itemIds: List.generate(151, (index) => index + 1), // מזהים 1 עד 151
    ),
    BinderConfig(
      level: 2,
      theme: 'Marvel MCU',
      // זמני: עד שנמצא API למארוול, נגדיר כאן מזהים דמיוניים מ-1000 עד 1050
      itemIds: List.generate(50, (index) => index + 1000),
    ),
    // קל מאוד להוסיף כאן את Dragon Ball Z בעתיד!
  ];

  /// Triggered when a previously-completed task is unchecked. Reverses
  /// exactly what processTaskCompletion granted for THIS task — using the
  /// amounts stamped on the task at completion time, not whatever
  /// task.level/isGolden happen to be now.
  Future<void> processTaskUncompletion(TaskItem task) async {
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

    currentCoins -= coinsToRemove;
    if (currentCoins < 0) currentCoins = 0;

    // Clear the awarded-state so a future re-completion of this task
    // awards fresh, rather than accumulating stale bookkeeping.
    task.awardedXp = null;
    task.awardedCoins = null;
    task.causedLevelUp = false;
    task.xpThresholdBeforeLevelUp = null;
    task.awardedPokemonId = null;

    await _saveData();
    notifyListeners();
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
        print(
          '🎉 מזל טוב! פתחת את אלבום: ${binderConfigs[currentBinder - 1].theme}',
        );
        return _pullPokemon(); // מנסים למשוך שוב מיד מהאלבום החדש
      } else {
        print('מדהים! סיימת את כל האלבומים באפליקציה!');
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

  Future<void> processOverduePenalties() async {
    try {
      final now = DateTime.now();
      // יצירת תאריך מדויק של חצות היום, כדי שחישוב הימים יהיה נקי משעות
      final startOfToday = DateTime(now.year, now.month, now.day);

      // משיכת כל המשימות הפעילות ממסד הנתונים
      final snapshot = await _db
          .collection('tasks')
          .where('isCompleted', isEqualTo: false)
          .get();

      bool gamificationChanged = false;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dueDateMs = data['dueDate'] as int?;
        final lastPenaltyMs = data['lastPenaltyDate'] as int?;

        // אם אין תאריך יעד, מדלגים על המשימה
        if (dueDateMs == null) continue;

        final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateMs);
        final startOfDueDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        );

        // בודקים אם תאריך היעד עבר
        if (startOfDueDate.isBefore(startOfToday)) {
          // מחשבים ממתי צריך לקנוס - מתאריך היעד, או מהפעם האחרונה שקנסנו
          DateTime calculationDate = startOfDueDate;
          if (lastPenaltyMs != null) {
            calculationDate = DateTime.fromMillisecondsSinceEpoch(
              lastPenaltyMs,
            );
            calculationDate = DateTime(
              calculationDate.year,
              calculationDate.month,
              calculationDate.day,
            );
          }

          // חישוב מספר הימים שעברו
          int daysLate = startOfToday.difference(calculationDate).inDays;

          if (daysLate > 0) {
            // החלת הקנסות
            int xpPenalty = daysLate * 5;
            int coinsPenalty = daysLate * 1;

            currentXp -= xpPenalty;
            if (currentXp < 0) currentXp = 0; // מונע מ-XP לרדת מתחת לאפס

            currentCoins -= coinsPenalty;
            if (currentCoins < 0) {
              currentCoins = 0;
            }
            // עדכון תאריך הקנס האחרון למשימה במסד הנתונים
            await _db.collection('tasks').doc(doc.id).update({
              'lastPenaltyDate': startOfToday.millisecondsSinceEpoch,
            });

            gamificationChanged = true;
          }
        }
      }

      // אם היו שינויים, שומרים ומודיעים למסך להתעדכן
      if (gamificationChanged) {
        await _saveData();
        notifyListeners();
      }
    } catch (e) {
      print('שגיאה בחישוב קנסות: $e');
    }
  }
}
