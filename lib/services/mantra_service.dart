import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mantra_item.dart';
import 'notification_service.dart';

class MantraService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveMantra(MantraItem mantra) async {
    try {
      await _db.collection('mantras').doc(mantra.id).set(mantra.toMap());
      await refreshNotifications();
    } catch (e) {
      print('Error saving mantra: $e');
    }
  }

  Future<void> deleteMantra(String id) async {
    try {
      await _db.collection('mantras').doc(id).delete();
      await refreshNotifications();
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

  // שולף את כל המנטרות ומרענן את לוח ההתראות. ציבורי כדי שנוכל
  // לחדש את ההתראות האקראיות גם בכל הפעלה של האפליקציה.
  Future<void> refreshNotifications() async {
    try {
      final snapshot = await _db.collection('mantras').get();
      final texts = snapshot.docs
          .map((doc) => doc.data()['text'] as String)
          .toList();
      await NotificationService().scheduleRandomMantras(texts);
    } catch (e) {
      print('Error refreshing mantra notifications: $e');
    }
  }
}
