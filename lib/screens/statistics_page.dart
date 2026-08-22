import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../services/gamification_service.dart';
import '../services/category_service.dart';
import '../models/task_item.dart';
import '../models/category_item.dart';
import '../widgets/app_drawer.dart';
import 'main_layout.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // משיכת נתוני הגיימיפיקציה ישירות
    final gamificationService = context.watch<GamificationService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('סטטיסטיקות'), centerTitle: true),
        drawer: const AppDrawer(),
        body: StreamBuilder<List<TaskItem>>(
          stream: context.read<TaskService>().streamTasks(),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = taskSnapshot.data ?? [];
            final completedTasks = tasks.where((t) => t.isCompleted).toList();
            final int openTasksCount = tasks.length - completedTasks.length;
            final int completedTasksCount = completedTasks.length;

            return StreamBuilder<List<CategoryItem>>(
              stream: context.read<CategoryService>().streamCategories(),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? [];

                // לוגיקה לגרף: ספירת משימות שהושלמו לפי קטגוריה
                Map<String, int> categoryCounts = {};
                for (var task in completedTasks) {
                  final catId = task.categoryId ?? 'none';
                  categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
                }

                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // --- כרטיסיות נתונים כלליים ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'משימות פתוחות',
                            openTasksCount.toString(),
                            Icons.pending_actions,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'משימות שהושלמו',
                            completedTasksCount.toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'סך XP (כל הזמנים)',
                            '${gamificationService.totalXpEarned} 🌟',
                            Icons.star,
                            Colors.purpleAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'מטבעות שבוזבזו',
                            '${gamificationService.totalCoinsSpent} 🪙',
                            Icons.shopping_cart,
                            Colors.amber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // --- אזור הגרף ---
                    const Text(
                      'משימות שהושלמו לפי קטגוריות',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBasicCategoryGraph(
                      categoryCounts,
                      categories,
                      completedTasksCount,
                    ),
                  ],
                );
              },
            );
          },
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

  // פונקציית עזר לבניית כרטיסיות סטטיסטיקה
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // פונקציה לבניית גרף פסים אופקי בסיסי ומעוצב
  Widget _buildBasicCategoryGraph(
    Map<String, int> counts,
    List<CategoryItem> categories,
    int totalCompleted,
  ) {
    if (totalCompleted == 0 || counts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'עדיין אין מספיק נתונים 📊',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // ממירים את המפה לרשימה וממיינים כדי שהקטגוריות עם הכי הרבה משימות יופיעו למעלה
    var sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: sortedEntries.map((entry) {
          final catId = entry.key;
          final count = entry.value;

          // איתור שם הקטגוריה והצבע שלה (אם נמחקה או חסרה, ניתן ערך ברירת מחדל)
          final category = categories.firstWhere(
            (c) => c.id == catId,
            orElse: () => CategoryItem(
              id: 'none',
              name: 'ללא קטגוריה',
              color: Colors.grey,
            ),
          );

          // חישוב אחוז ההשלמה ביחס לסך המשימות שהושלמו (0.0 עד 1.0)
          final percentage = count / totalCompleted;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // שם הקטגוריה
                SizedBox(
                  width: 80,
                  child: Text(
                    category.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // פס ההתקדמות הוויזואלי (הגרף האופקי)
                Expanded(
                  child: Stack(
                    children: [
                      // רקע הפס
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // הפס הצבעוני שמתמלא
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: category.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ספירת המשימות המספרית
                SizedBox(
                  width: 30,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
