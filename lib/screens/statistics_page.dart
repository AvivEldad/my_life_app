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
    // משיכת נתוני הגיימיפיקציה שיכילו כעת את ההיסטוריה השלמה
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

            // סינון רק של המשימות הפתוחות
            final openTasks = tasks.where((t) => !t.isCompleted).toList();
            final int openTasksCount = openTasks.length;

            // הפרדה בין משימות רגילות למשימות פרויקטים
            final int projectTasksCount = openTasks
                .where((t) => t.projectId != null)
                .length;

            return StreamBuilder<List<CategoryItem>>(
              stream: context.read<CategoryService>().streamCategories(),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? [];

                // המרת המידע מה-GamificationService לפורמט שהגרף מצפה לו
                Map<String, int> categoryCounts = {};
                gamificationService.completedCategoriesCount.forEach((
                  key,
                  value,
                ) {
                  categoryCounts[key] = (value as num).toInt();
                });

                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // --- כרטיסיות נתונים כלליים ---
                    // עטפנו ב-IntrinsicHeight כדי שהכרטיסיות ימתחו לגובה שווה
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch, // מתיחה של שני הצדדים
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'משימות פתוחות',
                              '$openTasksCount\n( מתוכם $projectTasksCount מפרויקטים)',
                              Icons.pending_actions,
                              Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'הושלמו (כל הזמנים)',
                              gamificationService.totalTasksCompleted
                                  .toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // עטפנו ב-IntrinsicHeight גם את השורה השנייה
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch, // מתיחה של שני הצדדים
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
                      gamificationService.totalTasksCompleted,
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

  // פונקציית עזר משופרת שתומכת בשורות מרובות ומתמרכזת יפה לגובה
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center, // ממורכז אנכית אם הכרטיסייה נמתחת
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
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

          final category = categories.firstWhere(
            (c) => c.id == catId,
            orElse: () => CategoryItem(
              id: 'none',
              name: 'ללא קטגוריה',
              color: Colors.grey,
            ),
          );

          final percentage = count / totalCompleted;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    category.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
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
