import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_todo_app/services/category_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart';
import 'services/task_service.dart';
import 'services/project_service.dart';
import 'services/habit_service.dart';
import 'services/prize_service.dart';
import 'services/strike_service.dart';
import 'services/mantra_service.dart';
import 'services/daily_task_service.dart';
import 'services/gamification_service.dart';
import 'services/idea_service.dart';

import 'screens/main_layout.dart';
import 'screens/habits_page.dart';
import 'screens/mantras_page.dart';
import 'screens/prizes_page.dart';
import 'screens/strikes_page.dart';
import 'screens/daily_tasks_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
NotificationResponse? _pendingNotificationResponse;

void appNotificationResponseHandler(NotificationResponse response) {
  if (response.actionId == HabitService.kSnoozeActionId) {
    habitNotificationBackgroundHandler(response);
    return;
  }

  if (appNavigatorKey.currentState == null) {
    _pendingNotificationResponse = response;
    return;
  }
  _openNotificationDestination(response);
}

void _openNotificationDestination(NotificationResponse response) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) {
    _pendingNotificationResponse = response;
    return;
  }

  final payload = response.payload;
  final id = response.id;
  late final Widget destination;

  if (payload == NotificationService.dailyListPayload || id == 6) {
    destination = const DailyTasksPage();
  } else if (payload == NotificationService.strikesPayload || id == 4) {
    destination = const StrikesPage();
  } else if (payload?.startsWith(NotificationService.habitsPayloadPrefix) ==
          true ||
      (id != null && id >= 1000000)) {
    destination = const HabitsPage();
  } else if (payload == NotificationService.mantrasPayload ||
      id == 101 ||
      id == 102 ||
      (id != null && id >= 10100 && id < 10160)) {
    destination = const MantrasPage();
  } else if (payload == NotificationService.prizesPayload || id == 2) {
    destination = const PrizesPage();
  } else if (payload == NotificationService.homePayload ||
      id == 1 ||
      id == 3 ||
      id == 5 ||
      id == 200 ||
      id == 201) {
    destination = const MainLayout(initialIndex: 0);
  } else {
    return;
  }

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => destination),
    (route) => route.isFirst,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print("Signed in anonymously to Firebase!");
  } on FirebaseAuthException catch (e) {
    if (e.code == "operation-not-allowed") {
      print("Anonymous auth hasn't been enabled for this project.");
    } else {
      print("Unknown error during anonymous sign-in: ${e.message}");
    }
  }
  final notificationService = NotificationService();
  await notificationService.init(
    onNotificationResponse: appNotificationResponseHandler,
    onBackgroundNotificationResponse: habitNotificationBackgroundHandler,
  );
  final launchDetails = await notificationService.getAppLaunchDetails();
  final launchResponse = launchDetails?.didNotificationLaunchApp == true
      ? launchDetails?.notificationResponse
      : null;
  await MantraService().refreshNotifications();
  runApp(const TaskApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final response = launchResponse ?? _pendingNotificationResponse;
    _pendingNotificationResponse = null;
    if (response != null) {
      _openNotificationDestination(response);
    }
  });
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TaskService>(create: (_) => TaskService()),
        ChangeNotifierProvider<GamificationService>(
          create: (_) => GamificationService(),
        ),
        Provider<ProjectService>(create: (_) => ProjectService()),
        Provider<HabitService>(create: (_) => HabitService()),
        Provider(create: (_) => MantraService()),
        Provider<PrizeService>(create: (_) => PrizeService()),
        Provider<StrikeService>(create: (_) => StrikeService()),
        Provider<MantraService>(create: (_) => MantraService()),
        Provider(create: (_) => DailyTaskService()),
        Provider<CategoryService>(create: (_) => CategoryService()),
        Provider(create: (_) => IdeaService()),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          // Keep every screen, dialog, and bottom action above the phone's
          // system navigation area, including devices using gesture navigation.
          return SafeArea(top: false, child: child ?? const SizedBox.shrink());
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('he', 'IL')],
        locale: const Locale('he', 'IL'),
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarThemeData(
            backgroundColor: Color(0xFF121212),
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: Colors.grey.shade900,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Colors.amber),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.grey.shade900,
            selectedItemColor: Colors.amber,
            unselectedItemColor: Colors.grey,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.amber, width: 2),
            ),
          ),
        ),
        home: const MainLayout(),
      ),
    );
  }
}
