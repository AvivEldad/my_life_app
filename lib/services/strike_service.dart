import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/strike_item.dart';

class StrikeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveStrike(StrikeItem strike) async {
    try {
      await _db.collection('strikes').doc(strike.id).set(strike.toMap());
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
      return true;
    } catch (e) {
      print('Error deleting strike: $e');
      throw Exception('strike deletion prize');
    }
  }
}
