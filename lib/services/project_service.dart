import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_item.dart';

class ProjectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveProject(ProjectItem project) async {
    try {
      await _db.collection('projects').doc(project.id).set(project.toMap());
      return true;
    } catch (e) {
      print('Error saving project: $e');
      throw Exception('error saving the project');
    }
  }

  Stream<List<ProjectItem>> streamProjects() {
    try {
      return _db
          .collection('projects')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => ProjectItem.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (e) {
      print('Error streaming projects: $e');
      return const Stream.empty();
    }
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      await _db.collection('projects').doc(projectId).delete();
      return true;
    } catch (e) {
      print('Error deleting project: $e');
      throw Exception('project deletion faild');
    }
  }
}
