import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/todo_item.dart';
import '../models/project_item.dart';
import '../models/category_item.dart';
import '../models/mantra_item.dart';

class DatabaseService {
  static final _db = FirebaseFirestore.instance;

  static final _tasksCol = _db.collection('tasks');
  static final _projectsCol = _db.collection('projects');
  static final _categoriesCol = _db.collection('categories');
  static final _mantrasCol = _db.collection('mantras');

  // ─── Load all data at startup ─────────────────────────────────────
  static Future<List<TodoItem>> loadTasks() async {
    final snap = await _tasksCol.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => TodoItem.fromMap(d.id, d.data()))
        .toList();
  }

  static Future<List<ProjectItem>> loadProjects() async {
    final snap = await _projectsCol.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => ProjectItem.fromMap(d.id, d.data()))
        .toList();
  }

  static Future<List<CategoryItem>> loadCategories() async {
    final snap = await _categoriesCol.get();
    return snap.docs
        .map((d) => CategoryItem.fromMap(d.id, d.data()))
        .toList();
  }

  // ─── Tasks ────────────────────────────────────────────────────────
  static Future<String> addTask(TodoItem item) async {
    final doc = await _tasksCol.add({
      ...item.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> updateTask(TodoItem item) async {
    await _tasksCol.doc(item.id).update(item.toMap());
  }

  static Future<void> deleteTask(String id) async {
    await _tasksCol.doc(id).delete();
  }

  // ─── Projects ─────────────────────────────────────────────────────
  static Future<String> addProject(ProjectItem item) async {
    final doc = await _projectsCol.add({
      ...item.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Future<void> updateProject(ProjectItem item) async {
    await _projectsCol.doc(item.id).update(item.toMap());
  }

  static Future<void> deleteProject(String id) async {
    await _projectsCol.doc(id).delete();
  }

  // ─── Categories ───────────────────────────────────────────────────
  static Future<String> addCategory(CategoryItem item) async {
    final doc = await _categoriesCol.add(item.toMap());
    return doc.id;
  }

  static Future<void> updateCategory(CategoryItem item) async {
    await _categoriesCol.doc(item.id).update(item.toMap());
  }

  static Future<void> deleteCategory(String id) async {
    await _categoriesCol.doc(id).delete();
  }


  // ─── Mantras ───────────────────────────────────────────────────
    static Future<List<MantraItem>> loadMantras() async {
      final snap = await _mantrasCol.get();
      return snap.docs.map((d) => MantraItem.fromMap(d.id, d.data())).toList();
    }

    static Future<String> addMantra(MantraItem item) async {
      final doc = await _mantrasCol.add(item.toMap());
      return doc.id;
    }

    static Future<void> updateMantra(MantraItem item) async {
      await _mantrasCol.doc(item.id).update(item.toMap());
    }

    static Future<void> deleteMantra(String id) async {
      await _mantrasCol.doc(id).delete();
    }
}