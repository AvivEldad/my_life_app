import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mantra_item.dart';
import '../services/database_service.dart';

class MantrasPage extends StatefulWidget {
  const MantrasPage({super.key});

  @override
  State<MantrasPage> createState() => _MantrasPageState();
}

class _MantrasPageState extends State<MantrasPage> {
  final List<MantraItem> _mantras = [];
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMantras();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (_mantras.isEmpty) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentPage < _mantras.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _fetchMantras() async {
    final data = await DatabaseService.loadMantras();
    setState(() {
      _mantras.clear();
      _mantras.addAll(data);
      _loading = false;
    });
    _startAutoScroll();
  }

  void _showMantraDialog({MantraItem? mantra}) {
    final controller = TextEditingController(text: mantra?.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mantra == null ? 'מנטרה חדשה' : 'עריכת מנטרה'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'הכנס טקסט כאן...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              if (mantra == null) {
                final newItem = MantraItem(id: '', text: controller.text);
                final id = await DatabaseService.addMantra(newItem);
                setState(() => _mantras.add(MantraItem(id: id, text: newItem.text)));
              } else {
                mantra.text = controller.text;
                await DatabaseService.updateMantra(mantra);
                setState(() {});
              }
              Navigator.pop(context);
              _startAutoScroll();
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('מנטרות'),
        actions: [
          IconButton(icon: const Icon(Icons.list), onPressed: _showManageSheet),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mantras.isEmpty
              ? const Center(child: Text('אין מנטרות עדיין'))
              : PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => _currentPage = idx,
                  itemCount: _mantras.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          _mantras[index].text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMantraDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _mantras.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(_mantras[i].text, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _showMantraDialog(mantra: _mantras[i])),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () async {
                  await DatabaseService.deleteMantra(_mantras[i].id);
                  setState(() => _mantras.removeAt(i));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}