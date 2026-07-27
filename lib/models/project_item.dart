class ProjectItem {
  String id;
  String title;
  String description;
  bool isSequential;

  ProjectItem({
    required this.id,
    required this.title,
    this.description = '',
    this.isSequential = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isSequential': isSequential,
    };
  }

  factory ProjectItem.fromMap(Map<String, dynamic> map, String documentId) {
    return ProjectItem(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isSequential: map['isSequential'] ?? false,
    );
  }
}
