// ============================================================================
// FILE: lib/presentation/app/app.dart
//
// MaterialApp do Axyo:
// - Define tema DARK consistente (fundo preto + ícones visíveis)
// - Configura AppBar/IconTheme/BottomAppBar para não "sumirem" no fundo escuro
// - Fluxo: authStateChanges -> Login / Home / Onboarding
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/onboarding_page.dart';

class VidaApp extends StatelessWidget {
  const VidaApp({super.key});

  Future<bool> onboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("onboarding_done") ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const seed = Colors.green;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Axyo',
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

        // ✅ Correção: aqui é BottomAppBarThemeData (não BottomAppBarTheme)
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

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          return FutureBuilder<bool>(
            future: onboardingDone(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (onboardingSnapshot.data == true) {
                return const HomePage();
              }

              return const OnboardingPage();
            },
          );
        },
      ),
    );
  }
}
