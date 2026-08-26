import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mantra_service.dart';
import '../models/mantra_item.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

class MantrasPage extends StatefulWidget {
  const MantrasPage({super.key});

  @override
  State<MantrasPage> createState() => _MantrasPageState();
}

class _MantrasPageState extends State<MantrasPage> {
  // נתחיל מהעמוד ה-10000 כדי שהמשתמש יוכל להחליק אחורה מהרגע הראשון
  final PageController _pageController = PageController(initialPage: 10000);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // הגדרת טיימר שמעביר לעמוד הבא כל 10 שניות
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // חובה לבטל את הטיימר כשהמסך נסגר
    _pageController.dispose();
    super.dispose();
  }

  // דיאלוג להוספה ועריכה
  void _showMantraDialog(BuildContext context, {MantraItem? existingMantra}) {
    final textController = TextEditingController(
      text: existingMantra?.text ?? '',
    );
    final mantraService = context.read<MantraService>();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: Text(
              existingMantra == null ? 'מנטרה חדשה ✨' : 'עריכת מנטרה',
              style: const TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: textController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'כתוב משפט מוטיבציה...',
                labelStyle: TextStyle(color: Colors.amber),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ביטול',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  if (textController.text.isNotEmpty) {
                    final mantra = MantraItem(
                      id:
                          existingMantra?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      text: textController.text,
                    );
                    mantraService.saveMantra(mantra);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'שמור',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('מנטרות ✨'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        drawer: const AppDrawer(),
        body: StreamBuilder<List<MantraItem>>(
          stream: context.read<MantraService>().streamMantras(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final mantras = snapshot.data ?? [];

            if (mantras.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'אין לך עדיין מנטרות.\nזה הזמן להוסיף קצת מוטיבציה!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                      ),
                      onPressed: () => _showMantraDialog(context),
                      child: const Text(
                        'הוסף מנטרה ראשונה',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              );
            }

            // תצוגת הקרוסלה
            return PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                // חישוב המיקום האמיתי מתוך הרשימה בעזרת מודולו
                final realIndex = index % mantras.length;
                final mantra = mantras[realIndex];

                return Stack(
                  children: [
                    // הטקסט עצמו ממורכז לחלוטין במסך
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          mantra.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // כפתורי העריכה והמחיקה בתחתית המסך (כדי לא להפריע לטקסט)
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                              size: 30,
                            ),
                            onPressed: () => _showMantraDialog(
                              context,
                              existingMantra: mantra,
                            ),
                          ),
                          const SizedBox(width: 40),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                              size: 30,
                            ),
                            onPressed: () => context
                                .read<MantraService>()
                                .deleteMantra(mantra.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        // כפתור הוספה למטה בצד
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.amber,
          onPressed: () => _showMantraDialog(context),
          child: const Icon(Icons.add, color: Colors.black),
        ),
        bottomNavigationBar: BottomNavigationBar(
          unselectedItemColor: Colors.grey,
          selectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              label: 'משימות',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              label: 'פרויקטים',
            ),
          ],
          onTap: (index) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainLayout(initialIndex: index),
              ),
            );
          },
        ),
      ),
    );
  }
}
