import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:easy_localization/easy_localization.dart'; // <-- 1. Add EasyLocalization
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. INITIALIZE REVENUECAT
  await Purchases.setLogLevel(LogLevel.debug);
  PurchasesConfiguration configuration =
      PurchasesConfiguration("goog_zMYSipEpHgTPBdCqwDdQiTwPYvF");
  await Purchases.configure(configuration);

  // 4. INITIALIZE EASY LOCALIZATION
  await EasyLocalization.ensureInitialized();

  // 5. Wrap the app in the EasyLocalization engine
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('tr'),
        Locale('es'), // Spanish
        Locale('pt'), // Portuguese
        Locale('fr'), // French
        Locale('de'), // German
        Locale('zh'), // Chinese
      ],
      path: 'assets/translations', // MUST match your folder path exactly!
      fallbackLocale: const Locale('en'),
      child: const XScanner(),
    ),
  );
}

class XScanner extends StatelessWidget {
  const XScanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Röntgen',
      debugShowCheckedModeBanner: false,

      // ---> TELL MATERIAL APP TO USE THE TRANSLATIONS <---
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6200EA)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      // Use the AuthGate instead of going straight to MainScreen
      home: const AuthGate(),
    );
  }
}

// 3. The Gatekeeper: Listens for login state changes
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If data is loading, show a spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // If the user has a valid session, show the app
        if (snapshot.hasData) {
          return const MainScreen();
        }

        // Otherwise, show the Login Screen
        return const LoginScreen();
      },
    );
  }
}
