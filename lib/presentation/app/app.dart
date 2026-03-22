// ============================================================================
// FILE: lib/presentation/app/app.dart
//
// Gate profissional:
// - Se não logado -> LoginPage
// - Se logado e não fez personal -> Onboarding (personal)
// - Se logado e não fez life -> Onboarding (life)
// - Senão -> Home
//
// Fix do "parece o mesmo usuário":
// - Migra/remova chaves globais antigas (gender, focus, goal, age, nickname) para não vazar
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../core/onboarding/questions.dart';
import '../../data/local/session_storage.dart';

class VidaApp extends StatelessWidget {
  const VidaApp({super.key});

  Future<void> _migrateLegacyPrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    // Keys globais antigas que vazam entre usuários
    const legacyKeys = ['gender', 'focus', 'goal', 'age', 'nickname', 'name'];

    for (final key in legacyKeys) {
      final legacyVal = prefs.getString(key);
      if (legacyVal == null || legacyVal.trim().isEmpty) continue;

      final uidKey = '$uid:$key';
      final already = prefs.getString(uidKey);

      // Migra se o uid ainda não tiver valor
      if (already == null || already.trim().isEmpty) {
        await prefs.setString(uidKey, legacyVal);
        if (key == 'nickname' || key == 'name') {
          await SessionStorage().saveNickname(uid, legacyVal.trim());
        }
      }

      // Remove legado sempre, pra não vazar pra próximo usuário
      await prefs.remove(key);
    }
  }

  Future<bool> _done(User user, String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${key}_${user.uid}') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const seed = Colors.green;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Axyo',
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
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snap.data;
          if (user == null) return const LoginPage();

          return FutureBuilder<void>(
            future: _migrateLegacyPrefs(user),
            builder: (context, migSnap) {
              if (migSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return FutureBuilder<bool>(
                future: _done(user, 'personal_done'),
                builder: (context, pSnap) {
                  if (pSnap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final personalDone = pSnap.data ?? false;
                  if (!personalDone) {
                    return const OnboardingPage(
                      stage: OnboardingStage.personal,
                    );
                  }

                  return FutureBuilder<bool>(
                    future: _done(user, 'life_done'),
                    builder: (context, lSnap) {
                      if (lSnap.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final lifeDone = lSnap.data ?? false;
                      return lifeDone
                          ? const HomePage()
                          : const OnboardingPage(stage: OnboardingStage.life);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
