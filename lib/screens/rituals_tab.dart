import 'package:flutter/material.dart';
import '../models/ritual_item.dart';
import '../models/category_item.dart';
import '../widgets/ritual_card.dart';
import '../widgets/dialogs/ritual_dialog.dart';

class RitualsTab extends StatefulWidget {
  final List<RitualItem> rituals;
  final List<CategoryItem> categories;
  final Future<void> Function(RitualItem, bool isNew) onRitualSaved;
  final Future<void> Function(String id) onRitualDeleted;
  final VoidCallback onChanged;

  const RitualsTab({
    super.key,
    required this.rituals,
    required this.categories,
    required this.onRitualSaved,
    required this.onRitualDeleted,
    required this.onChanged,
  });

  @override
  State<RitualsTab> createState() => _RitualsTabState();
}

class _RitualsTabState extends State<RitualsTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<RitualItem> get _filtered {
    List<RitualItem> list = List.from(widget.rituals);
    list.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      return 0;
    });
    return list;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showRitualDialog({RitualItem? ritual}) {
    final isNew = ritual == null;
    showDialog(
      context: context,
      builder: (context) => RitualDialog(
        ritual: ritual,
        categories: widget.categories,
        onSave: (savedRitual) async {
          await widget.onRitualSaved(savedRitual, isNew);
          if (isNew) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToTop();
            });
          }
        },
        onDelete: () {
          if (ritual != null) {
            widget.onRitualDeleted(ritual.id);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final others = _filtered;

    return Scaffold(
      body: ListView.builder(
        controller: _scrollController,
        itemCount: others.length,
        itemBuilder: (context, index) {
          final ritual = others[index];
          return RitualCard(
            ritual: ritual,
            category: widget.categories
                .where((c) => c.id == ritual.categoryId)
                .firstOrNull,
            onToggle: () {
              ritual.isCompleted = !ritual.isCompleted;
              widget.onRitualSaved(ritual, false);
            },
            onEdit: () => _showRitualDialog(ritual: ritual),
            onDelete: () => widget.onRitualDeleted(ritual.id),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRitualDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
