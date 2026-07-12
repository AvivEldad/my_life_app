import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mantra_item.dart';

class MantraService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveMantra(MantraItem mantra) async {
    try {
      await _db.collection('mantras').doc(mantra.id).set(mantra.toMap());
      return true;
    } catch (e) {
      print('Error saving mantra: $e');
      throw Exception('error saving mantra');
    }
  }

  Stream<List<MantraItem>> streamMantras() {
    try {
      return _db
          .collection('mantras')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => MantraItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming mantras: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteMantra(String mantraId) async {
    try {
      await _db.collection('mantras').doc(mantraId).delete();
      return true;
    } catch (e) {
      print('Error deleting mantra: $e');
      throw Exception('mantra deletion faild');
    }
  }
}
