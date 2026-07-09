class Reward {
  final int xp;
  final double coins;

  Reward({required this.xp, required this.coins});
}

class RewardEngine {
  // 1. Tasks & Rituals (Levels 1-5)
  static Reward calculateTaskReward(int level, {bool isGolden = false}) {
    // Base formulas
    int xp = level * 5;
    double coins = level * 2.0;

    // Golden Task Multiplier
    if (isGolden) {
      xp *= 2;
      coins *= 2;
    }

    return Reward(xp: xp, coins: coins);
  }

  // 2. Daily List Items
  static Reward calculateDailyItemReward() {
    return Reward(xp: 1, coins: 0.5);
  }

  static Reward calculateDailyListCompletionBonus() {
    return Reward(xp: 15, coins: 10.0);
  }

  // 3. Strikes (Milestone System)
  static Reward? calculateStrikeMilestone(int currentStreak) {
    if (currentStreak == 7) return Reward(xp: 10, coins: 15.0);
    if (currentStreak == 14) return Reward(xp: 20, coins: 30.0);

    // Monthly milestones (30, 60, 90, etc.)
    if (currentStreak >= 30 && currentStreak % 30 == 0) {
      return Reward(xp: 50, coins: 50.0);
    }

    return null; // No reward for non-milestone days
  }

  static double getStrikePenalty() {
    return 5.0; // Penalty for breaking a punishable strike before 7 days
  }

  // 4. Projects
  static Reward calculateProjectCompletionBonus(int totalSubtasks) {
    // Flat bonus + a small scaling bonus based on project size
    int xp = 50 + (totalSubtasks * 2);
    double coins = 50.0 + (totalSubtasks * 1.0);
    return Reward(xp: xp, coins: coins);
  }

  // 5. XP Bar Scaling Formula
  static int calculateMaxXpForNextPull(int totalUnlockedPokemon) {
    // Starts at 100, increases by 15 for every Pokemon owned
    return 100 + (totalUnlockedPokemon * 15);
  }
}
