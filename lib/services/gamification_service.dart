import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_item.dart';

class GamificationService extends ChangeNotifier {
  // Database instance for saving our gamification stats
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int currentXp = 0;
  int currentCoins = 0;
  int currentXpThreshold = 100;
  int currentLevel = 1;
  List<int> unlockedPokemons = [];

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

        // Tell the UI to refresh with the saved data
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

    // Check if we hit the threshold
    if (currentXp >= currentXpThreshold) {
      currentXp -= currentXpThreshold;
      currentXpThreshold = (currentXpThreshold * 1.1).toInt();
      currentLevel++; // <--- כאן אנחנו מעלים את הרמה ב-1!
      pulledPokemonId = _pullPokemon();
    }

    // Save the new progress to Firebase immediately
    await _saveData();
    notifyListeners();

    return pulledPokemonId;
  }

  /// Handles the random pull logic without duplicates
  int? _pullPokemon() {
    List<int> allGen1Ids = List.generate(151, (index) => index + 1);
    List<int> availableIds = allGen1Ids
        .where((id) => !unlockedPokemons.contains(id))
        .toList();

    if (availableIds.isNotEmpty) {
      final random = Random();
      int randomIndex = random.nextInt(availableIds.length);
      int pulledId = availableIds[randomIndex];

      unlockedPokemons.add(pulledId);
      return pulledId;
    }
    return null; // All Gen 1 unlocked
  }

  /// Checks if enough time has passed to purchase a prize
  bool canPurchasePrize(DateTime? lastPurchasedAt, Duration cooldownDuration) {
    if (lastPurchasedAt == null) return true;
    final difference = DateTime.now().difference(lastPurchasedAt);
    return difference >= cooldownDuration;
  }
}
