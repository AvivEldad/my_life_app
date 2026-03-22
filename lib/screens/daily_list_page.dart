import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Called when app resumes from background — check if midnight passed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndClearIfNewDay();
    }
  }

  void _checkAndClearIfNewDay() {
    final today = _todayString();
    if (today != _listDate) {
      setState(() {
        _tasks.clear();
        _listDate = today;
      });
    }
  }

  void _addTask(String summary) {
    final text = summary.trim();
    if (text.isEmpty) return;
    setState(() {
      _tasks.add(DailyTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        summary: text,
      ));
    });
    _inputController.clear();
    _inputFocus.requestFocus();
  }

  void _toggleTask(DailyTask task) {
    setState(() => task.isCompleted = !task.isCompleted);
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((t) => t.id == id));
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = ['שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת', 'ראשון'];
    const months = ['', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ב${months[now.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final completed = _tasks.where((t) => t.isCompleted).length;
    final total = _tasks.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('רשימה יומית'),
          actions: [
            if (_tasks.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'נקה הכל',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('נקה רשימה'),
                    content: const Text('האם למחוק את כל המשימות?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('ביטול')),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _tasks.clear());
                          Navigator.pop(context);
                        },
                        child: const Text('נקה'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date header + progress
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formattedDate(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[300]),
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$completed/$total', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: LinearProgressIndicator(
                              value: completed / total,
                              minHeight: 6,
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                completed == total ? Colors.green : Colors.amber,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Task list
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Text(
                        'אין משימות להיום\nהתחל לכתוב למטה',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Dismissible(
                          key: ValueKey(task.id),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.redAccent,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteTask(task.id),
                          child: InkWell(
                            onTap: () => _toggleTask(task),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Checkbox
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.rectangle,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: task.isCompleted ? Colors.amber : Colors.grey[500]!,
                                        width: 2,
                                      ),
                                      color: task.isCompleted ? Colors.amber : Colors.transparent,
                                    ),
                                    child: task.isCompleted
                                        ? const Icon(Icons.check, size: 14, color: Colors.black)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  // Summary
                                  Expanded(
                                    child: Text(
                                      task.summary,
                                      style: TextStyle(
                                        fontSize: 16,
                                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                        color: task.isCompleted ? Colors.grey[600] : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Input row at the bottom
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'הוסף משימה...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: _addTask,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.amber),
                    onPressed: () => _addTask(_inputController.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}