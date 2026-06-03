import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/prize_item.dart';
import 'database_service.dart'; 

class CoinService extends ChangeNotifier {
  // --- Wealth (Coins) ---
  double _totalCoins = 0.0;
  DateTime? _lastPenaltyCheck;
  
  // --- Experience & Collection (Pokemon) ---
  int _xp = 0;
  List<int> _unlockedPokemon = [];
  final int xpRequiredPerPull = 100;
  
  // --- State ---
  List<PrizeItem> _prizes = [];
  bool _isInitialized = false;
  int? _newlyPulledPokemonId; // Used to trigger the UI animation

  // Getters
  double get totalCoins => _totalCoins;
  DateTime? get lastPenaltyCheck => _lastPenaltyCheck;
  int get xp => _xp;
  List<int> get unlockedPokemon => _unlockedPokemon;
  List<PrizeItem> get prizes => _prizes;
  bool get isInitialized => _isInitialized;
  int? get newlyPulledPokemonId => _newlyPulledPokemonId;

  CoinService() {
    _loadFromFirebase();
  }

  // --- Cloud Sync ---

  Future<void> _loadFromFirebase() async {
    try {
      final economyData = await DatabaseService.loadEconomy();
      if (economyData != null) {
        _totalCoins = (economyData['totalCoins'] ?? 0.0).toDouble();
        _xp = economyData['xp'] ?? 0;
        _unlockedPokemon = List<int>.from(economyData['unlockedPokemon'] ?? []);
        
        if (economyData['lastPenaltyCheck'] != null) {
          _lastPenaltyCheck = DateTime.tryParse(economyData['lastPenaltyCheck']);
        }
      } else {
        _lastPenaltyCheck = DateTime.now(); 
      }

      _prizes = await DatabaseService.loadPrizes();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading Gamification from Firebase: $e');
      _lastPenaltyCheck ??= DateTime.now();
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _saveEconomyToFirebase() {
    DatabaseService.updateEconomy(_totalCoins, _lastPenaltyCheck, _xp, _unlockedPokemon);
  }

  // ==========================================
  // SYNERGY & BUFF CALCULATIONS
  // ==========================================

  double _getEvolutionMultiplier() {
    double multiplier = 1.0;
    // Check Bulbasaur Line
    if (_unlockedPokemon.contains(1) && _unlockedPokemon.contains(2) && _unlockedPokemon.contains(3)) multiplier += 0.05;
    // Check Charmander Line
    if (_unlockedPokemon.contains(4) && _unlockedPokemon.contains(5) && _unlockedPokemon.contains(6)) multiplier += 0.05;
    // Check Squirtle Line
    if (_unlockedPokemon.contains(7) && _unlockedPokemon.contains(8) && _unlockedPokemon.contains(9)) multiplier += 0.05;
    
    return multiplier;
  }

  double _getDailyPagePassiveIncome() {
    double dailyBonus = 0.0;
    // Check how many full pages of 9 are complete
    for (int page = 0; page < 16; page++) { // 16 pages * 9 = 144
      bool pageComplete = true;
      for (int i = 1; i <= 9; i++) {
        int targetId = (page * 9) + i;
        if (targetId <= 151 && !_unlockedPokemon.contains(targetId)) {
          pageComplete = false;
          break;
        }
      }
      if (pageComplete) dailyBonus += 1.0; // +1 Coin per complete page
    }
    return dailyBonus;
  }

  // ==========================================
  // ECONOMY & XP ACTIONS
  // ==========================================
  
  void addCoins(double amount) {
    if (amount <= 0) return;
    _totalCoins += (amount * _getEvolutionMultiplier());
    notifyListeners();
    _saveEconomyToFirebase();
  }

  void deductCoins(double amount) {
    if (amount <= 0) return;
    _totalCoins -= amount;
    if (_totalCoins < 0) _totalCoins = 0.0;
    notifyListeners();
    _saveEconomyToFirebase();
  }

  void addXP(int amount) {
    if (amount <= 0) return;
    _xp += amount;
    
    // Check for level up / pull
    if (_xp >= xpRequiredPerPull) {
      _triggerRandomPull();
    } else {
      notifyListeners();
      _saveEconomyToFirebase();
    }
  }

  void _triggerRandomPull() {
    // Generate list of uncollected IDs (1 through 151)
    final availableIds = List.generate(151, (i) => i + 1)
        .where((id) => !_unlockedPokemon.contains(id))
        .toList();

    if (availableIds.isEmpty) {
      // User has all 151! Cap XP and grant coins instead.
      _xp = xpRequiredPerPull;
      addCoins(50.0); // Reward for max rank
      return;
    }

    // Pick a random ID
    final random = Random();
    final pulledId = availableIds[random.nextInt(availableIds.length)];

    // Update state
    _unlockedPokemon.add(pulledId);
    _xp -= xpRequiredPerPull; // Keep leftover XP
    _newlyPulledPokemonId = pulledId; // Set flag for UI animation

    notifyListeners();
    _saveEconomyToFirebase();
  }

  void clearPullFlag() {
    _newlyPulledPokemonId = null;
    // Don't need to notify listeners here, just resetting the UI trigger state
  }

  // --- Task Reward Formulas ---

  double calculateStandardTaskReward({required int level, bool isGolden = false, DateTime? dueDate, DateTime? completionDate}) {
    double reward = level * 2.0;
    if (isGolden) reward *= 2;
    if (dueDate != null) {
      final actualCompletion = completionDate ?? DateTime.now();
      if (actualCompletion.isBefore(dueDate)) {
        final daysRemaining = dueDate.difference(actualCompletion).inDays;
        if (daysRemaining > 0) reward += (daysRemaining * 0.5);
      }
    }
    return reward;
  }

  int calculateTaskXP({required int level, bool isGolden = false}) {
    int xpEarned = level * 10;
    if (isGolden) xpEarned *= 2;
    return xpEarned;
  }

  // --- Prize CRUD State ---

  Future<void> addNewPrize(PrizeItem prize) async {
    // Add to Firebase first to get the real ID
    final realId = await DatabaseService.addPrize(prize);
    final newPrize = PrizeItem(id: realId, title: prize.title, cost: prize.cost);
    
    _prizes.add(newPrize);
    notifyListeners();
  }

  Future<void> updatePrize(PrizeItem prize) async {
    final index = _prizes.indexWhere((p) => p.id == prize.id);
    if (index >= 0) {
      _prizes[index] = prize;
      notifyListeners();
      await DatabaseService.updatePrize(prize);
    }
  }

  Future<void> deletePrize(String id) async {
    _prizes.removeWhere((p) => p.id == id);
    notifyListeners();
    await DatabaseService.deletePrize(id);
  }

  // --- Dynamic Milestone Math ---
  double getNextMilestone() {
    final activePrizes = _prizes.where((p) => !p.isRedeemed).toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    return activePrizes.isEmpty ? 100.0 : activePrizes.first.cost;
  }

  double getBarProgress() {
    double milestone = getNextMilestone();
    if (milestone == 0) return 0.0;
    double progress = _totalCoins / milestone;
    return progress > 1.0 ? 1.0 : progress; 
  }


  void processActiveBleedPenalties(List<dynamic> uncompletedTasksWithDueDates) {
    if (!_isInitialized || _lastPenaltyCheck == null) return;
    final now = DateTime.now();
    final lastCheckMidnight = DateTime(_lastPenaltyCheck!.year, _lastPenaltyCheck!.month, _lastPenaltyCheck!.day);
    final currentMidnight = DateTime(now.year, now.month, now.day);
    final midnightsPassed = currentMidnight.difference(lastCheckMidnight).inDays;

    if (midnightsPassed <= 0) return; 

    double passiveIncome = _getDailyPagePassiveIncome() * midnightsPassed;
    if (passiveIncome > 0) {
      _totalCoins += passiveIncome;
    }

    final targetsWithDueDates = uncompletedTasksWithDueDates.where((t) => t.dueDate != null).toList();
    if (targetsWithDueDates.isEmpty) {
      _lastPenaltyCheck = now;
      _saveEconomyToFirebase();
      return;
    }

    double totalBleedPenalty = 0.0;
    for (var task in targetsWithDueDates) {
      final taskMidnight = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      if (lastCheckMidnight.isAfter(taskMidnight)) {
        totalBleedPenalty += (1.0 * midnightsPassed);
      } else if (currentMidnight.isAfter(taskMidnight)) {
        final daysOverdueInInterval = currentMidnight.difference(taskMidnight).inDays;
        totalBleedPenalty += (1.0 * daysOverdueInInterval);
      }
    }

    _lastPenaltyCheck = now;
    if (totalBleedPenalty > 0) {
      _totalCoins -= totalBleedPenalty;
      if (_totalCoins < 0) _totalCoins = 0.0;
    }
    notifyListeners();
    _saveEconomyToFirebase();
  }
}