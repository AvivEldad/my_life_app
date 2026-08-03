import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_item.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveCategory(CategoryItem category) async {
    try {
      await _db.collection('categories').doc(category.id).set(category.toMap());
      return true;
    } catch (e) {
      print('Error saving category: $e');
      throw Exception('error saving category');
    }
  }

  Stream<List<CategoryItem>> streamCategories() {
    try {
      return _db
          .collection('categories')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CategoryItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming categories: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _db.collection('categories').doc(categoryId).delete();
      return true;
    } catch (e) {
      print('Error deleting category: $e');
      throw Exception('category deletion faild');
    }
  }
}
