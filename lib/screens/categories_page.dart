import 'package:flutter/material.dart';
import '../models/category_item.dart';

class CategoriesPage extends StatefulWidget {
  final List<CategoryItem> categories;
  final Future<void> Function(CategoryItem, bool isNew) onSaved;
  final Future<void> Function(String id) onDeleted;

  const CategoriesPage({
    super.key,
    required this.categories,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {

  void _showCategoryDialog({CategoryItem? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    Color selectedColor = category?.color ?? CategoryItem.palette.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'עריכת קטגוריה' : 'קטגוריה חדשה'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(hintText: 'שם הקטגוריה'),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: CategoryItem.palette.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () {
                  widget.categories.removeWhere((c) => c.id == category.id);
                  widget.onDeleted(category.id);
                  setState(() {});
                  Navigator.pop(context);
                },
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
            ElevatedButton(
              onPressed: nameController.text.isEmpty ? null : () {
                if (isEditing) {
                  category.name = nameController.text;
                  category.color = selectedColor;
                  widget.onSaved(category, false);
                } else {
                  final newCat = CategoryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    color: selectedColor,
                  );
                  widget.categories.add(newCat);
                  widget.onSaved(newCat, true);
                }
                setState(() {});
                Navigator.pop(context);
              },
              child: Text(isEditing ? 'שמור' : 'צור'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('קטגוריות')),
        body: widget.categories.isEmpty
            ? Center(
                child: Text(
                  'אין קטגוריות עדיין\nלחץ + כדי להוסיף',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            : ListView.builder(
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final c = widget.categories[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                      ),
                      title: Text(c.name, style: const TextStyle(fontSize: 16)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showCategoryDialog(category: c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                            onPressed: () {
                              setState(() => widget.categories.removeWhere((cat) => cat.id == c.id));
                              widget.onDeleted(c.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCategoryDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}