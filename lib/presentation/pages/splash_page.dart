import 'package:flutter/material.dart';

import '../../data/local/session_storage.dart';
import 'login_page.dart';
import 'home/home_page.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _storage = SessionStorage();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await Future.delayed(const Duration(milliseconds: 900));
      final token = await _storage.readToken();
      if (!mounted) return;

      final next = (token != null && token.isNotEmpty)
          ? const HomePage()
          : const LoginPage();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.20),
              theme.colorScheme.secondary.withValues(alpha: 0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/splash_lista.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 16),
                Text('Vida App', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
