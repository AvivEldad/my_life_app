import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mantra_item.dart';
import 'notification_service.dart';

class MantraService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveMantra(MantraItem mantra) async {
    try {
      await _db.collection('mantras').doc(mantra.id).set(mantra.toMap());
      await _updateNotifications();
    } catch (e) {
      print('Error saving mantra: $e');
    }
  }

  Future<void> deleteMantra(String id) async {
    try {
      await _db.collection('mantras').doc(id).delete();
      await _updateNotifications();
    } catch (e) {
      print('Error deleting mantra: $e');
    }
  }

  Stream<List<MantraItem>> streamMantras() {
    return _db.collection('mantras').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MantraItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  // פונקציית עזר ששולפת את כל המנטרות כדי לעדכן את ההתראות ברקע
  Future<void> _updateNotifications() async {
    final snapshot = await _db.collection('mantras').get();
    final texts = snapshot.docs
        .map((doc) => doc.data()['text'] as String)
        .toList();
    await NotificationService().scheduleRandomMantras(texts);
  }
}
