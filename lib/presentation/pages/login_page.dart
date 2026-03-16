// ============================================================================
// FILE: lib/presentation/pages/login_page.dart
//
// Login correto:
// - NÃO navega manualmente pro Home (VidaApp decide via authStateChanges)
// - Loading + validação simples + dispose controllers
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth auth = FirebaseAuth.instance;

  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = emailController.text.trim();
    final pass = passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) return 'Digite um email válido.';
    if (pass.length < 6) return 'A senha precisa ter no mínimo 6 caracteres.';
    return null;
  }

  Future<void> loginEmail() async {
    final err = _validate();
    if (err != null) return showError(err);

    await _runWithLoading(() async {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    });
  }

  Future<void> register() async {
    final err = _validate();
    if (err != null) return showError(err);

    await _runWithLoading(() async {
      await auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    });
  }

  Future<void> loginGoogle() async {
    await _runWithLoading(() async {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await auth.signInWithCredential(credential);
    });
  }

  Future<void> _runWithLoading(Future<void> Function() fn) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await fn();
    } on FirebaseAuthException catch (e) {
      showError(_friendlyAuthError(e));
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email inválido.';
      case 'user-disabled':
        return 'Usuário desabilitado.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'Esse email já está em uso.';
      case 'weak-password':
        return 'Senha fraca. Use uma senha mais forte.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      default:
        return e.message ?? 'Erro no login.';
    }
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Image.asset("assets/icons/axyo_foreground.png", width: 120),
              const SizedBox(height: 20),
              const Text(
                "Axyo",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                enabled: !_loading,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: Colors.green),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                enabled: !_loading,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Senha",
                  labelStyle: TextStyle(color: Colors.green),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _loading ? null : loginEmail,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Entrar"),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loading ? null : register,
                child: const Text(
                  "Criar conta",
                  style: TextStyle(color: Colors.yellow),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _loading ? null : loginGoogle,
                child: const Text(
                  "Entrar com Google",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
