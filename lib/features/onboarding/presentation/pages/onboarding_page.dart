// ============================================================================
// FILE: lib/features/onboarding/presentation/pages/onboarding_page.dart
//
// Ajuste:
// - Suporta pergunta do tipo texto (nickname)
// - Salva nickname e respostas por UID
// - Marca onboarding_done_<uid>
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/onboarding/questions.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../../data/local/session_storage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int currentQuestion = 0;
  final Map<String, String> answers = {};
  bool _saving = false;

  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
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

    // ✅ salva nickname em chave dedicada (mais fácil de usar no app)
    final nickname = answers['nickname']?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      await SessionStorage().saveNickname(user.uid, nickname);
    }

    // Marca onboarding por UID
    await prefs.setBool('onboarding_done_${user.uid}', true);

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  void _goNextOrFinish() {
    if (currentQuestion < onboardingQuestions.length - 1) {
      setState(() => currentQuestion++);
      return;
    }
    _finishOnboarding();
  }

  Future<void> selectAnswer(String answer) async {
    if (_saving) return;

    answers[onboardingQuestions[currentQuestion].id] = answer;
    _goNextOrFinish();
  }

  Future<void> _submitTextAnswer() async {
    if (_saving) return;

    final q = onboardingQuestions[currentQuestion];
    final value = _textController.text.trim();

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um nome/apelido para continuar.')),
      );
      return;
    }

    answers[q.id] = value;
    _textController.clear();
    _goNextOrFinish();
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

                    if (question.type == QuestionType.options) ...[
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
                    ] else ...[
                      TextField(
                        controller: _textController,
                        enabled: !_saving,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTextAnswer(),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Nome/apelido",
                          labelStyle: TextStyle(color: Colors.green),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _saving ? null : _submitTextAnswer,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("Continuar"),
                        ),
                      ),
                    ],
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
