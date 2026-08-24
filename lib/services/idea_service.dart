import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/idea_item.dart';

class IdeaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveIdea(IdeaItem idea) async {
    try {
      await _db.collection('ideas').doc(idea.id).set(idea.toMap());
    } catch (e) {
      print('Error saving idea: $e');
    }
  }

  Future<void> deleteIdea(String id) async {
    try {
      await _db.collection('ideas').doc(id).delete();
    } catch (e) {
      print('Error deleting idea: $e');
    }
  }

  // פונקציה חדשה שמעדכנת את הסדר של כל הרעיונות בבת אחת לאחר גרירה
  Future<void> updateIdeasOrder(List<IdeaItem> ideas) async {
    try {
      WriteBatch batch = _db.batch();
      for (int i = 0; i < ideas.length; i++) {
        DocumentReference docRef = _db.collection('ideas').doc(ideas[i].id);
        batch.update(docRef, {'orderIndex': i});
      }
      await batch.commit();
    } catch (e) {
      print('Error updating ideas order: $e');
    }
  }

  // מעודכן: כעת ממיין לפי השדה orderIndex (מהקטן לגדול)
  Stream<List<IdeaItem>> streamIdeas() {
    return _db.collection('ideas').orderBy('orderIndex').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => IdeaItem.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}
