import 'package:flutter/material.dart';
import '../models/project_item.dart';
import '../models/category_item.dart';
import '../widgets/project_card.dart';
import '../widgets/dialogs/project_dialog.dart';

class ProjectsTab extends StatefulWidget {
  final List<ProjectItem> projects;
  final List<CategoryItem> categories;
  final Future<void> Function(ProjectItem, bool isNew) onProjectSaved;
  final Future<void> Function(String id) onProjectDeleted;
  final VoidCallback onChanged;

  const ProjectsTab({
    super.key,
    required this.projects,
    required this.categories,
    required this.onProjectSaved,
    required this.onProjectDeleted,
    required this.onChanged,
  });

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final Set<String> _expanded = <String>{};

  void _showProjectDialog({ProjectItem? project}) {
    final isNew = project == null;
    showDialog(
      context: context,
      builder: (_) => ProjectDialog(
        project: project,
        categories: widget.categories,
        onSave: (saved) {
          if (isNew) widget.projects.insert(0, saved);
          widget.onProjectSaved(saved, isNew);
        },
        onDelete: project != null
            ? () {
                _expanded.remove(project.id);
                widget.projects.removeWhere((p) => p.id == project.id);
                widget.onProjectDeleted(project.id);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.projects.isEmpty
          ? Center(
              child: Text(
                'אין פרויקטים עדיין\nלחץ + כדי להוסיף',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          : ReorderableListView.builder(
              itemCount: widget.projects.length,
              onReorder: (oldIdx, newIdx) {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = widget.projects.removeAt(oldIdx);
                widget.projects.insert(newIdx, item);
                widget.onChanged();
              },
              itemBuilder: (context, index) {
                final project = widget.projects[index];
                return ReorderableDragStartListener(
                  key: ValueKey(project.id),
                  index: index,
                  child: ProjectCard(
                    project: project,
                    isExpanded: _expanded.contains(project.id),
                    categories: widget.categories,
                    onToggleExpand: () => setState(() {
                      if (_expanded.contains(project.id)) {
                        _expanded.remove(project.id);
                      } else {
                        _expanded.add(project.id);
                      }
                    }),
                    onDelete: () {
                      _expanded.remove(project.id);
                      widget.projects.removeWhere((p) => p.id == project.id);
                      widget.onProjectDeleted(project.id);
                    },
                    onChanged: () {
                      widget.onProjectSaved(project, false);
                      setState(() {});
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showProjectDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}