import 'dart:math';
import 'package:flutter/material.dart'; // חובה לייבא כדי להשתמש ב-ChangeNotifier
import '../models/task_item.dart';

// הוספנו את המילה 'extends ChangeNotifier'
class GamificationService extends ChangeNotifier {
  int currentXp = 0;
  int currentCoins = 0;
  int currentXpThreshold = 100;
  List<int> unlockedPokemons = [];

  void processTaskCompletion(TaskItem task) {
    int earnedXp = task.level * 10;
    int earnedCoins = task.level * 5;

    currentXp += earnedXp;
    currentCoins += earnedCoins;

    print('הרווחת $earnedXp XP ו-$earnedCoins מטבעות!');

    if (currentXp >= currentXpThreshold) {
      currentXp -= currentXpThreshold;
      currentXpThreshold = (currentXpThreshold * 1.5).toInt();
      _pullPokemon();
    }

    // קריאה קריטית: מודיעה לאפליקציה שהנתונים השתנו כדי שתרענן את המסך!
    notifyListeners();
  }

  void _pullPokemon() {
    List<int> allGen1Ids = List.generate(151, (index) => index + 1);
    List<int> availableIds = allGen1Ids
        .where((id) => !unlockedPokemons.contains(id))
        .toList();

    if (availableIds.isNotEmpty) {
      final random = Random();
      int randomIndex = random.nextInt(availableIds.length);
      int pulledId = availableIds[randomIndex];

      unlockedPokemons.add(pulledId);
      print('🎉 מדהים! פתחת את פוקימון מספר: $pulledId');
    } else {
      print('השלמת את כל 151 הפוקימונים של הדור הראשון!');
    }
  }

  bool canPurchasePrize(DateTime? lastPurchasedAt, Duration cooldownDuration) {
    if (lastPurchasedAt == null) return true;
    final difference = DateTime.now().difference(lastPurchasedAt);
    return difference >= cooldownDuration;
  }
}
