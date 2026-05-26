import 'package:flutter/foundation.dart';
import '../models/prize_item.dart';
import 'database_service.dart';

class CoinService extends ChangeNotifier {
  double _totalCoins = 0.0;
  DateTime? _lastPenaltyCheck;
  List<PrizeItem> _prizes = [];
  bool _isInitialized = false;

  double get totalCoins => _totalCoins;
  DateTime? get lastPenaltyCheck => _lastPenaltyCheck;
  List<PrizeItem> get prizes => _prizes;
  bool get isInitialized => _isInitialized;

  CoinService() {
    _loadFromFirebase();
  }

  // --- Cloud Sync ---

  Future<void> _loadFromFirebase() async {
    try {
      // 1. Load Wallet
      final economyData = await DatabaseService.loadEconomy();
      if (economyData != null) {
        _totalCoins = (economyData['totalCoins'] ?? 0.0).toDouble();
        if (economyData['lastPenaltyCheck'] != null) {
          _lastPenaltyCheck = DateTime.tryParse(economyData['lastPenaltyCheck']);
        }
      } else {
        _lastPenaltyCheck = DateTime.now(); // First time setup
      }

      // 2. Load Prizes
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
    DatabaseService.updateEconomy(_totalCoins, _lastPenaltyCheck);
  }

  // --- Core Wallet State ---
  
  void addCoins(double amount) {
    if (amount <= 0) return;
    _totalCoins += amount;
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

  void processActiveBleedPenalties(List<dynamic> uncompletedTasksWithDueDates) {
    if (!_isInitialized || _lastPenaltyCheck == null) return;
    final now = DateTime.now();
    final lastCheckMidnight = DateTime(_lastPenaltyCheck!.year, _lastPenaltyCheck!.month, _lastPenaltyCheck!.day);
    final currentMidnight = DateTime(now.year, now.month, now.day);
    final midnightsPassed = currentMidnight.difference(lastCheckMidnight).inDays;

    if (midnightsPassed <= 0) return; 

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