class MantraItem {
  final String id;
  String text;

  MantraItem({required this.id, required this.text});

  Map<String, dynamic> toMap() => {'text': text};

  factory MantraItem.fromMap(String id, Map<String, dynamic> map) {
    return MantraItem(id: id, text: map['text'] ?? '');
  }
}