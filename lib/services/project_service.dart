import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_item.dart';
import 'gamification_service.dart';

class ProjectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> saveProject(ProjectItem project) async {
    try {
      if (project.id.isEmpty) {
        // פרויקט חדש: ניתן ל-Firebase לייצר מזהה (ID) ייחודי באופן אוטומטי
        await _db.collection('projects').add(project.toMap());
      } else {
        // פרויקט קיים: נעדכן את המסמך הקיים לפי ה-ID שלו
        await _db.collection('projects').doc(project.id).set(project.toMap());
      }
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
                .map((doc) => ProjectItem.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (e) {
      print('Error streaming projects: $e');
      return const Stream.empty();
    }
  }

  Future<ProjectItem?> getProjectOnce(String projectId) async {
    try {
      final doc = await _db.collection('projects').doc(projectId).get();
      if (!doc.exists) return null;
      return ProjectItem.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error fetching project: $e');
      return null;
    }
  }

  /// Deletes a project AND every task that belongs to it, in one atomic
  /// batch. The caller is responsible for confirming with the user first.
  Future<bool> deleteProjectWithTasks(String projectId) async {
    try {
      final tasksSnapshot = await _db
          .collection('tasks')
          .where('projectId', isEqualTo: projectId)
          .get();

      final batch = _db.batch();
      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_db.collection('projects').doc(projectId));

      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting project with tasks: $e');
      throw Exception('project deletion faild');
    }
  }

  /// Kept for backward compatibility / cases where the caller explicitly
  /// wants to delete only the project document (tasks are handled elsewhere).
  Future<bool> deleteProject(String projectId) async {
    try {
      await _db.collection('projects').doc(projectId).delete();
      return true;
    } catch (e) {
      print('Error deleting project: $e');
      throw Exception('project deletion faild');
    }
  }

  /// Returns true if the project has at least one task and every task
  /// belonging to it is completed.
  Future<bool> areAllProjectTasksCompleted(String projectId) async {
    final snapshot = await _db
        .collection('tasks')
        .where('projectId', isEqualTo: projectId)
        .get();

    if (snapshot.docs.isEmpty) return false;

    return snapshot.docs.every(
      (doc) => (doc.data()['isCompleted'] as bool?) ?? false,
    );
  }

  /// Call this right after a task belonging to [projectId] gets marked
  /// completed. If that was the LAST open task in the project, marks the
  /// project as completed, grants the 100 coins / 200 xp bonus via
  /// [gamificationService], and returns the updated (now-completed)
  /// project. Returns null if the project isn't fully completed yet, or
  /// was already marked completed before (so the reward isn't granted
  /// twice).
  Future<ProjectItem?> checkAndAwardProjectCompletion(
    String projectId,
    GamificationService gamificationService,
  ) async {
    final project = await getProjectOnce(projectId);
    if (project == null || project.isCompleted) return null;

    final allDone = await areAllProjectTasksCompleted(projectId);
    if (!allDone) return null;

    await gamificationService.processProjectCompletion(project);

    project.isCompleted = true;
    project.completedAt = DateTime.now();
    await saveProject(project);

    return project;
  }

  /// Call this right after a task belonging to [projectId] gets
  /// un-checked. If the project had already been marked completed (and
  /// rewarded), this re-opens it and reverses the reward.
  Future<void> revertProjectCompletionIfNeeded(
    String projectId,
    GamificationService gamificationService,
  ) async {
    final project = await getProjectOnce(projectId);
    if (project == null || !project.isCompleted) return;

    await gamificationService.processProjectUncompletion(project);

    project.isCompleted = false;
    project.completedAt = null;
    await saveProject(project);
  }

  /// Deletes every project that was completed before today (i.e. "at the
  /// end of the day" of its completion), along with its tasks. Call this
  /// from a daily-checks routine, the same way TaskService.clearCompletedTasks
  /// is used for regular tasks.
  Future<void> clearCompletedProjects() async {
    try {
      final snapshot = await _db
          .collection('projects')
          .where('isCompleted', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      for (final doc in snapshot.docs) {
        final project = ProjectItem.fromMap(doc.data(), doc.id);
        if (project.completedAt != null &&
            project.completedAt!.isBefore(startOfToday)) {
          await deleteProjectWithTasks(project.id);
        }
      }
    } catch (e) {
      print('Error clearing completed projects: $e');
    }
  }
}
