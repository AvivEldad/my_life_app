import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_item.dart';

class GamificationService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int currentXp = 0;
  int currentCoins = 0;
  int currentXpThreshold = 100;
  List<int> unlockedPokemons = [];

  // Call this when the app starts to load saved data
  Future<void> loadGamificationData() async {
    try {
      final doc = await _db.collection('gamification').doc('user_stats').get();
      if (doc.exists) {
        final data = doc.data()!;
        currentXp = data['currentXp'] ?? 0;
        currentCoins = data['currentCoins'] ?? 0;
        currentXpThreshold = data['currentXpThreshold'] ?? 100;
        unlockedPokemons = List<int>.from(data['unlockedPokemons'] ?? []);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading gamification data: $e');
    }
  }

  // Private method to save data after any change
  Future<void> _saveData() async {
    try {
      await _db.collection('gamification').doc('user_stats').set({
        'currentXp': currentXp,
        'currentCoins': currentCoins,
        'currentXpThreshold': currentXpThreshold,
        'unlockedPokemons': unlockedPokemons,
      });
    } catch (e) {
      print('Error saving gamification data: $e');
    }
  }

  // Notice it now returns a Future<int?>. It returns the ID if a pull happens, or null if not.
  Future<int?> processTaskCompletion(TaskItem task) async {
    int earnedXp = task.level * 10;
    int earnedCoins = task.level * 5;

    currentXp += earnedXp;
    currentCoins += earnedCoins;

    int? pulledPokemonId; // Will store the new ID if we level up

    if (currentXp >= currentXpThreshold) {
      currentXp -= currentXpThreshold;
      currentXpThreshold = (currentXpThreshold * 1.3).toInt();
      pulledPokemonId = _pullPokemon();
    }

    await _saveData(); // Save progress to Firebase
    notifyListeners();

    return pulledPokemonId; // Return the ID to the UI
  }

  // Changed to return the pulled ID
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
}
