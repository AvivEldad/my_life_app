import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strike_item.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

class StrikeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Advance elapsed days and award unpaid milestones atomically.
  Future<void> syncStrikesForToday(GamificationService gamification) async {
    final snapshot = await _db.collection('strikes').get();
    for (final document in snapshot.docs) {
      await gamification.processStrikeSync(document.id);
    }
  }

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
      debugPrint('Error saving strike: $e');
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
      debugPrint('Error streaming strikes: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteStrike(String strikeId) async {
    try {
      await _db.collection('strikes').doc(strikeId).delete();
      await updateStrikeReminderNotification();
      return true;
    } catch (e) {
      debugPrint('Error deleting strike: $e');
      throw Exception('strike deletion faild');
    }
  }

  /// Reset the counter without taking away previously earned rewards.
  Future<void> resetStrike(String strikeId) async {
    final doc = await _db.collection('strikes').doc(strikeId).get();
    if (!doc.exists) return;
    final strike = StrikeItem.fromMap(doc.id, doc.data()!);
    strike.streak = 0;
    strike.lastIncrementDate = '';
    strike.lastAutoUpdateDate = StrikeItem.todayString();
    strike.rewardedWeekMilestones = 0;
    strike.rewardedMonthMilestones = 0;
    await saveStrike(strike);
  }

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
      debugPrint('Error updating strike reminder notification: $e');
    }
  }
}
