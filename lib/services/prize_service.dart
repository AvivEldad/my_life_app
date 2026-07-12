import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prize_item.dart';

class PrizeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> savePrize(PrizeItem prize) async {
    try {
      await _db.collection('prizes').doc(prize.id).set(prize.toMap());
      return true;
    } catch (e) {
      print('Error saving prize: $e');
      throw Exception('error saving prize');
    }
  }

  Stream<List<PrizeItem>> streamPrizes() {
    try {
      return _db
          .collection('prizes')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => PrizeItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming prizes: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deletePrize(String prizeId) async {
    try {
      await _db.collection('prizes').doc(prizeId).delete();
      return true;
    } catch (e) {
      print('Error deleting prize: $e');
      throw Exception('prize deletion faild');
    }
  }
}
