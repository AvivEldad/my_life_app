import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/coin_service.dart';
import 'package:provider/provider.dart';

class DailyTask {
  final String id;
  String summary;
  bool isCompleted;

  DailyTask({
    required this.id,
    required this.summary,
    this.isCompleted = false,
  });
}

class DailyListPage extends StatefulWidget {
  const DailyListPage({super.key});

  @override
  State<DailyListPage> createState() => _DailyListPageState();
}

class _DailyListPageState extends State<DailyListPage> with WidgetsBindingObserver {
  final List<DailyTask> _tasks = [];
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  String _listDate = _todayString();

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndClearIfNewDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _checkAndClearIfNewDay();
      });
    }
  }

  void _checkAndClearIfNewDay() {
    final today = _todayString();
    if (_listDate != today) {
      _tasks.clear();
      _listDate = today;
    }
  }

  void _addTask(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _tasks.add(DailyTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        summary: text.trim(),
      ));
    });
    _inputController.clear();
  }

  void _toggleTask(String id) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        task.isCompleted = !task.isCompleted;
        
        final coinService = Provider.of<CoinService>(context, listen: false);
        if (task.isCompleted) {
          coinService.addCoins(5);
          HapticFeedback.lightImpact();
        } else {
          coinService.deductCoins(5);
        }
      }
    });
  }

  void _deleteTask(String id) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        if (_tasks[index].isCompleted) {
          Provider.of<CoinService>(context, listen: false).deductCoins(5);
        }
        _tasks.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // List view section
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Text(
                        'אין משימות להיום.\nלחץ על כפתור הפלוס כדי להוסיף!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Dismissible(
                          key: Key(task.id),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) => _deleteTask(task.id),
                          child: Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Checkbox(
                                value: task.isCompleted,
                                activeColor: Colors.amber,
                                checkColor: Colors.black,
                                onChanged: (value) => _toggleTask(task.id),
                              ),
                              title: Text(
                                task.summary,
                                style: TextStyle(
                                  color: task.isCompleted ? Colors.grey : Colors.white,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'הוסף משימה חדשה',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: _inputController,
                autofocus: true,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'מה ברצונך לעשות היום?',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.amber),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.amber, width: 2),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _addTask(value);
                  }
                  Navigator.pop(context);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ביטול', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    if (_inputController.text.trim().isNotEmpty) {
                      _addTask(_inputController.text);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('הוסף', style: TextStyle(color: Colors.amber)),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }
}