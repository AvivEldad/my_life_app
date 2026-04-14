import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';

class DatabaseService {
  final CollectionReference _db = FirebaseFirestore.instance.collection('todo_items');

  // The "Pipe" for the StreamBuilder
  Stream<List<TodoItem>> get tasksStream {
    return _db.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return TodoItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // SAVE
  Future<void> saveTask(TodoItem item) async {
    await _db.add(item.toMap());
  }

  // UPDATE
  Future<void> updateTask(TodoItem item) async {
    await _db.doc(item.id).update(item.toMap());
  }

  // DELETE
  Future<void> deleteTask(String id) async {
    await _db.doc(id).delete();
  }
}