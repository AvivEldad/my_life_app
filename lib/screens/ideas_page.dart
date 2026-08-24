import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/idea_service.dart';
import '../models/idea_item.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

class IdeasPage extends StatelessWidget {
  const IdeasPage({super.key});

  void _showIdeaDialog(
    BuildContext context, {
    IdeaItem? existingIdea,
    int currentCount = 0,
  }) {
    final summaryController = TextEditingController(
      text: existingIdea?.summary ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingIdea?.description ?? '',
    );
    final ideaService = context.read<IdeaService>();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: Text(
              existingIdea == null ? 'רעיון חדש 💡' : 'עריכת רעיון',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: summaryController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'תקציר',
                      labelStyle: TextStyle(color: Colors.amber),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'תיאור מפורט',
                      labelStyle: TextStyle(color: Colors.amber),
                    ),
                  ),
                ],
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
                  if (summaryController.text.isNotEmpty) {
                    final idea = IdeaItem(
                      id:
                          existingIdea?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      summary: summaryController.text,
                      description: descriptionController.text,
                      createdAt: existingIdea?.createdAt,
                      // אם זה רעיון חדש, נוסיף אותו לסוף הרשימה
                      orderIndex: existingIdea?.orderIndex ?? currentCount,
                    );
                    ideaService.saveIdea(idea);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'שמור',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
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
        appBar: AppBar(title: const Text('הרעיונות שלי 💡'), centerTitle: true),
        drawer: const AppDrawer(),
        body: StreamBuilder<List<IdeaItem>>(
          stream: context.read<IdeaService>().streamIdeas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // חובה לייצר עותק שניתן לעריכה כדי לאפשר את הגרירה המקומית לפני השמירה בשרת
            final ideas = List<IdeaItem>.from(snapshot.data ?? []);

            if (ideas.isEmpty) {
              return const Center(
                child: Text(
                  'אין לך עדיין רעיונות.\nלחץ על ה- + למטה כדי להוסיף רעיון חדש!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            // וידג'ט שמאפשר גרירה ושינוי סדר
            return ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ideas.length,
              onReorder: (oldIndex, newIndex) {
                // תיקון האינדקס של פלאטר בגרירה למטה
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }

                // שינוי הסדר ברשימה המקומית
                final item = ideas.removeAt(oldIndex);
                ideas.insert(newIndex, item);

                // עדכון האינדקס החדש לכל הפריטים ושליחה למסד הנתונים
                for (int i = 0; i < ideas.length; i++) {
                  ideas[i].orderIndex = i;
                }
                context.read<IdeaService>().updateIdeasOrder(ideas);
              },
              itemBuilder: (context, index) {
                final idea = ideas[index];
                return Card(
                  // חובה לספק מפתח ייחודי (Key) לכל פריט ברשימה נגררת
                  key: ValueKey(idea.id),
                  color: Colors.grey.shade800,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    iconColor: Colors.amber,
                    collapsedIconColor: Colors.grey,
                    title: Text(
                      idea.summary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // הכפתורים עברו החוצה לשורת הכותרת!
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () =>
                              _showIdeaDialog(context, existingIdea: idea),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              context.read<IdeaService>().deleteIdea(idea.id),
                        ),
                        const Icon(
                          Icons.drag_indicator,
                          color: Colors.grey,
                        ), // אייקון שמסמן שאפשר לגרור
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            idea.description.isEmpty
                                ? 'אין תיאור.'
                                : idea.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.amber,
          onPressed: () => _showIdeaDialog(context),
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
      ), // סגירת Scaffold
    ); // סגירת Directionality
  }
}
