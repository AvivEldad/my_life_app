import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ritual_item.dart';

class RitualService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveRitual(RitualItem ritual) async {
    try {
      await _db.collection('rituals').doc(ritual.id).set(ritual.toMap());
      return true;
    } catch (e) {
      print('Error saving ritual: $e');
      throw Exception('error saving ritaul');
    }
  }

  Stream<List<RitualItem>> streamRituals() {
    try {
      return _db
          .collection('rituals')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => RitualItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming rituals: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteRitual(String ritualId) async {
    try {
      await _db.collection('rituals').doc(ritualId).delete();
      return true;
    } catch (e) {
      print('Error deleting ritual: $e');
      throw Exception('ritual deletion faild');
    }
  }
}
