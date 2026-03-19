// ============================================================================
// FILE: lib/presentation/pages/onboarding_page.dart
//
// Correção:
// - Salva respostas e onboarding_done por UID (onboarding_done_<uid>)
// - Ao finalizar, vai para HomePage via pushReplacement (não pop)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/onboarding/questions.dart';
import 'home/home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int currentQuestion = 0;
  final Map<String, String> answers = {};
  bool _saving = false;

  Future<void> selectAnswer(String answer) async {
    if (_saving) return;

    answers[onboardingQuestions[currentQuestion].id] = answer;

    if (currentQuestion < onboardingQuestions.length - 1) {
      setState(() => currentQuestion++);
      return;
    }

    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão inválida. Faça login novamente.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Salva respostas por UID
    for (final e in answers.entries) {
      await prefs.setString('${user.uid}:${e.key}', e.value);
    }

    // Marca onboarding por UID
    await prefs.setBool('onboarding_done_${user.uid}', true);

    if (!mounted) return;

    // ✅ Troca para Home (não use pop, onboarding é a home route)
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    final question = onboardingQuestions[currentQuestion];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      question.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Pergunta ${currentQuestion + 1} de ${onboardingQuestions.length}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 22),
                    ...question.options.map((option) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _saving
                                ? null
                                : () => selectAnswer(option),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(option),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
