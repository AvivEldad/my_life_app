import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/home_page.dart';
import 'services/coin_service.dart'; // Ensure this matches your directory structure
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
  await FirebaseAuth.instance.signInAnonymously();
  print("Signed in anonymously to Firebase!");
} on FirebaseAuthException catch (e) {
  if (e.code == "operation-not-allowed") {
    print("Anonymous auth hasn't been enabled for this project.");
    // Make sure Anonymous authentication is enabled in your Firebase Console -> Authentication -> Sign-in method
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
    return ChangeNotifierProvider<CoinService>(
      create: (_) => CoinService(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('he', 'IL'),
        ],
        locale: const Locale('he', 'IL'),
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          primarySwatch: Colors.amber,
        ),
        home: const HomePage(),
      ),
    );
  }
}