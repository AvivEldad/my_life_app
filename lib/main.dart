import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/task_service.dart';
import 'services/project_service.dart';
import 'services/ritual_service.dart';
import 'services/prize_service.dart';
import 'services/strike_service.dart';
import 'services/mantra_service.dart';
import 'services/daily_task_service.dart';

import 'screens/test_screen.dart';

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
  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TaskService>(create: (_) => TaskService()),
        Provider<ProjectService>(create: (_) => ProjectService()),
        Provider<RitualService>(create: (_) => RitualService()),
        Provider<PrizeService>(create: (_) => PrizeService()),
        Provider<StrikeService>(create: (_) => StrikeService()),
        Provider<MantraService>(create: (_) => MantraService()),
        Provider<DailyTaskService>(create: (_) => DailyTaskService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
          primarySwatch: Colors.amber,
        ),
        home: const TestScreen(),
      ),
    );
  }
}
