import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strike_item.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

/// תוצאת סימון "בוצע היום" עבור סטרייק - כולל את הבונוס (אם היה) כדי
/// שהמסך יוכל להציג חגיגה מתאימה.
class StrikeCheckInResult {
  final StrikeItem strike;
  final int earnedCoins;
  final int earnedXp;
  final bool hitWeekMilestone;
  final bool hitMonthMilestone;

  StrikeCheckInResult({
    required this.strike,
    required this.earnedCoins,
    required this.earnedXp,
    required this.hitWeekMilestone,
    required this.hitMonthMilestone,
  });

  bool get earnedAnyReward => earnedCoins > 0 || earnedXp > 0;
}

class StrikeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveStrike(StrikeItem strike) async {
    try {
      if (strike.id.isEmpty) {
        // סטרייק חדש: ניתן ל-Firebase לייצר מזהה ייחודי באופן אוטומטי
        await _db.collection('strikes').add(strike.toMap());
      } else {
        await _db.collection('strikes').doc(strike.id).set(strike.toMap());
      }
      await updateStrikeReminderNotification();
      return true;
    } catch (e) {
      print('Error saving strike: $e');
      throw Exception('error saving strike');
    }
  }

  Stream<List<StrikeItem>> streamStrikes() {
    try {
      return _db
          .collection('strikes')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => StrikeItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming strikes: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteStrike(String strikeId) async {
    try {
      await _db.collection('strikes').doc(strikeId).delete();
      await updateStrikeReminderNotification();
      return true;
    } catch (e) {
      print('Error deleting strike: $e');
      throw Exception('strike deletion faild');
    }
  }

  /// מסמן שהסטרייק "בוצע" היום: מעלה את המונה ב-1 ומעניק בונוס אם עברנו
  /// רף של שבוע (כל 7 ימים, 1 מטבע + 5 XP) ו/או רף של חודש (כל 30 יום,
  /// 3 מטבעות + 15 XP). לא עושה כלום אם הסטרייק כבר סומן היום.
  Future<StrikeCheckInResult?> checkInStrike(
    String strikeId,
    GamificationService gamificationService,
  ) async {
    final doc = await _db.collection('strikes').doc(strikeId).get();
    if (!doc.exists) return null;

    final strike = StrikeItem.fromMap(doc.id, doc.data()!);
    if (strike.incrementedToday) return null;

    strike.streak += 1;
    strike.lastIncrementDate = StrikeItem.todayString();

    final weekMilestones = strike.streak ~/ 7;
    final monthMilestones = strike.streak ~/ 30;
    final newWeeks = weekMilestones - strike.rewardedWeekMilestones;
    final newMonths = monthMilestones - strike.rewardedMonthMilestones;

    int earnedCoins = 0;
    int earnedXp = 0;
    if (newWeeks > 0) {
      earnedCoins += newWeeks * 1;
      earnedXp += newWeeks * 5;
      strike.rewardedWeekMilestones = weekMilestones;
    }
    if (newMonths > 0) {
      earnedCoins += newMonths * 3;
      earnedXp += newMonths * 15;
      strike.rewardedMonthMilestones = monthMilestones;
    }

    if (earnedCoins > 0 || earnedXp > 0) {
      await gamificationService.addCoinsAndXp(earnedCoins, earnedXp);
    }

    await saveStrike(strike);

    return StrikeCheckInResult(
      strike: strike,
      earnedCoins: earnedCoins,
      earnedXp: earnedXp,
      hitWeekMilestone: newWeeks > 0,
      hitMonthMilestone: newMonths > 0,
    );
  }

  /// מאפס את המונה של הסטרייק ל-0 (לחיצת המשתמש על כפתור האיפוס).
  /// לא גורע בונוסים שכבר הוענקו על ימים שכבר עברו בפועל.
  Future<void> resetStrike(String strikeId) async {
    final doc = await _db.collection('strikes').doc(strikeId).get();
    if (!doc.exists) return;

    final strike = StrikeItem.fromMap(doc.id, doc.data()!);
    strike.streak = 0;
    strike.lastIncrementDate = '';
    strike.rewardedWeekMilestones = 0;
    strike.rewardedMonthMilestones = 0;

    await saveStrike(strike);
  }

  /// סורק את כל הסטרייקים ומעדכן את התראת התזכורת עם מספר הסטרייקים
  /// שעדיין לא סומנו היום.
  Future<void> updateStrikeReminderNotification() async {
    try {
      final snapshot = await _db.collection('strikes').get();
      int pendingCount = 0;
      for (final doc in snapshot.docs) {
        final strike = StrikeItem.fromMap(doc.id, doc.data());
        if (!strike.incrementedToday) pendingCount++;
      }
      await NotificationService().refreshStrikeReminder(pendingCount);
    } catch (e) {
      print('Error updating strike reminder notification: $e');
    }
  }
}
