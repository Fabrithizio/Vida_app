// ============================================================================
// FILE: lib/presentation/app/app.dart
//
// Gate global do app:
//
// Fluxo:
// - Se não logado -> LoginPage
// - Se logado e não fez personal -> Onboarding (personal)
// - Se logado e não fez life -> Onboarding (life)
// - Senão -> HomePage
//
// CORREÇÃO DE BUG:
// - Corrige caso em que o login Google autentica, mas a tela fica presa no login
// - Usa userChanges() + fallback em currentUser
// - Evita recriar futures críticos de forma instável a cada rebuild
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/onboarding/questions.dart';
import '../data/local/session_storage.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';

class VidaApp extends StatelessWidget {
  const VidaApp({super.key});

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
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _preparedUid;
  Future<void>? _prepareFuture;
  Future<bool>? _personalDoneFuture;
  Future<bool>? _lifeDoneFuture;

  Future<void> _migrateLegacyPrefs(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    const legacyKeys = [
      'gender',
      'focus',
      'goal',
      'age',
      'nickname',
      'name',
      'dob',
      'cpf',
    ];

    for (final key in legacyKeys) {
      final legacyVal = prefs.getString(key);
      if (legacyVal == null || legacyVal.trim().isEmpty) continue;

      final uidKey = '$uid:$key';
      final already = prefs.getString(uidKey);

      if (already == null || already.trim().isEmpty) {
        await prefs.setString(uidKey, legacyVal);

        if (key == 'nickname' || key == 'name') {
          await SessionStorage().saveNickname(uid, legacyVal.trim());
        }
      }

      await prefs.remove(key);
    }
  }

  Future<void> _ensureDefaultNickname(User user) async {
    final uid = user.uid;
    final storage = SessionStorage();
    final existing = (await storage.readNickname(uid))?.trim() ?? '';

    if (existing.isNotEmpty) return;

    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) {
      await storage.saveNickname(uid, display);
      return;
    }

    final email = (user.email ?? '').trim();
    if (email.contains('@')) {
      await storage.saveNickname(uid, email.split('@').first);
      return;
    }

    await storage.saveNickname(uid, 'Usuário');
  }

  Future<bool> _done(User user, String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${key}_${user.uid}') ?? false;
  }

  Future<void> _prepareUser(User user) async {
    await _migrateLegacyPrefs(user);
    await _ensureDefaultNickname(user);
  }

  void _primeUserState(User user) {
    if (_preparedUid == user.uid &&
        _prepareFuture != null &&
        _personalDoneFuture != null &&
        _lifeDoneFuture != null) {
      return;
    }

    _preparedUid = user.uid;
    _prepareFuture = _prepareUser(user);
    _personalDoneFuture = _done(user, 'personal_done');
    _lifeDoneFuture = _done(user, 'life_done');
  }

  Widget _loading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            FirebaseAuth.instance.currentUser == null) {
          return _loading();
        }

        final user = snap.data ?? FirebaseAuth.instance.currentUser;

        if (user == null) {
          _preparedUid = null;
          _prepareFuture = null;
          _personalDoneFuture = null;
          _lifeDoneFuture = null;
          return const LoginPage();
        }

        _primeUserState(user);

        return FutureBuilder<void>(
          future: _prepareFuture,
          builder: (context, prepSnap) {
            if (prepSnap.connectionState == ConnectionState.waiting) {
              return _loading();
            }

            if (prepSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erro ao preparar sessão do usuário:\n${prepSnap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              );
            }

            return FutureBuilder<bool>(
              future: _personalDoneFuture,
              builder: (context, personalSnap) {
                if (personalSnap.connectionState == ConnectionState.waiting) {
                  return _loading();
                }

                final personalDone = personalSnap.data ?? false;

                if (!personalDone) {
                  return const OnboardingPage(stage: OnboardingStage.personal);
                }

                return FutureBuilder<bool>(
                  future: _lifeDoneFuture,
                  builder: (context, lifeSnap) {
                    if (lifeSnap.connectionState == ConnectionState.waiting) {
                      return _loading();
                    }

                    final lifeDone = lifeSnap.data ?? false;

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
    );
  }
}
