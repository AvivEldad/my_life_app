import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prize_item.dart';

class CoinService extends ChangeNotifier {
  static const String _keyTotalCoins = 'questlog_total_coins';
  static const String _keyLastPenaltyCheck = 'questlog_last_penalty_check';

  double _totalCoins = 0.0;
  DateTime? _lastPenaltyCheck;
  List<PrizeItem> _prizes = [];
  bool _isInitialized = false;

  double get totalCoins => _totalCoins;
  DateTime? get lastPenaltyCheck => _lastPenaltyCheck;
  List<PrizeItem> get prizes => _prizes;
  bool get isInitialized => _isInitialized;

  CoinService({List<PrizeItem>? initialPrizes, DateTime? lastCheck}) {
    _prizes = initialPrizes ?? _getMockPrizes();
    _lastPenaltyCheck = lastCheck;
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalCoins = prefs.getDouble(_keyTotalCoins) ?? 0.0;
      
      final savedCheckStr = prefs.getString(_keyLastPenaltyCheck);
      if (savedCheckStr != null) {
        _lastPenaltyCheck = DateTime.tryParse(savedCheckStr);
      } else {
        _lastPenaltyCheck = DateTime.now();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading coin statistics from local storage: $e');
      _lastPenaltyCheck ??= DateTime.now();
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyTotalCoins, _totalCoins);
      if (_lastPenaltyCheck != null) {
        await prefs.setString(_keyLastPenaltyCheck, _lastPenaltyCheck!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error syncing wallet values to local storage: $e');
    }
  }

  // --- Core Wallet State management ---
  
  void addCoins(double amount) {
    if (amount <= 0) return;
    _totalCoins += amount;
    notifyListeners();
    _saveToStorage();
  }

  void deductCoins(double amount) {
    if (amount <= 0) return;
    _totalCoins -= amount;
    if (_totalCoins < 0) _totalCoins = 0.0;
    notifyListeners();
    _saveToStorage();
  }

  // --- Dynamic Milestone Math ---

  double getNextMilestone() {
    final activePrizes = _prizes.where((p) => !p.isRedeemed).toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));

    if (activePrizes.isEmpty) {
      return 100.0;
    }
    return activePrizes.first.cost;
  }

  double getBarProgress() {
    double milestone = getNextMilestone();
    if (milestone == 0) return 0.0;
    
    double progress = _totalCoins / milestone;
    return progress > 1.0 ? 1.0 : progress; 
  }

  // --- Task Reward Formulas ---

  double calculateStandardTaskReward({
    required int level,
    bool isGolden = false,
    DateTime? dueDate,
    DateTime? completionDate,
  }) {
    double reward = level * 2.0;
    if (isGolden) reward *= 2;

    if (dueDate != null) {
      final actualCompletion = completionDate ?? DateTime.now();
      
      if (actualCompletion.isBefore(dueDate)) {
        final daysRemaining = dueDate.difference(actualCompletion).inDays;
        if (daysRemaining > 0) {
          reward += (daysRemaining * 0.5);
        }
      }
    }
    return reward;
  }

  // --- Midnight Bleed Processing Engine ---

  void processActiveBleedPenalties(List<dynamic> uncompletedTasksWithDueDates) {
    if (!_isInitialized || _lastPenaltyCheck == null) return;

    final now = DateTime.now();
    
    final lastCheckMidnight = DateTime(_lastPenaltyCheck!.year, _lastPenaltyCheck!.month, _lastPenaltyCheck!.day);
    final currentMidnight = DateTime(now.year, now.month, now.day);
    final midnightsPassed = currentMidnight.difference(lastCheckMidnight).inDays;

    if (midnightsPassed <= 0) return; // Optimization Shield: Already checked today

    final targetsWithDueDates = uncompletedTasksWithDueDates.where((t) => t.dueDate != null).toList();
    if (targetsWithDueDates.isEmpty) {
      _lastPenaltyCheck = now;
      _saveToStorage();
      return;
    }

    double totalBleedPenalty = 0.0;

    for (var task in targetsWithDueDates) {
      final taskMidnight = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      
      if (lastCheckMidnight.isAfter(taskMidnight)) {
        totalBleedPenalty += (1.0 * midnightsPassed);
      } 
      else if (currentMidnight.isAfter(taskMidnight)) {
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
    _saveToStorage();
  }

  List<PrizeItem> _getMockPrizes() {
    return [
      PrizeItem(id: 'p1', title: '30 Mins Gaming', cost: 50.0),
      PrizeItem(id: 'p2', title: 'Cheat Meal / Snack', cost: 100.0),
      PrizeItem(id: 'p3', title: 'Buy New Gadget/LEGO', cost: 500.0),
    ];
  }
}