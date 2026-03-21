// ============================================================================
// FILE: lib/presentation/app/app.dart
//
// Localização pt-BR:
// - Define locale pt_BR para o app inteiro
// - Ativa delegates de localização (meses/dias/botões em português)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';

class VidaApp extends StatelessWidget {
  const VidaApp({super.key});

  Future<bool> onboardingDoneForUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done_${user.uid}') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const seed = Colors.green;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Axyo',

      // ✅ pt-BR no app inteiro
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: seed,
        scaffoldBackgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Color(0xFF0F0F1A),
          elevation: 8,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: seed,
          foregroundColor: Colors.black,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) return const LoginPage();

          return FutureBuilder<bool>(
            future: onboardingDoneForUser(user),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final done = onboardingSnapshot.data ?? false;
              return done ? const HomePage() : const OnboardingPage();
            },
          );
        },
      ),
    );
  }
}
