// ============================================================================
// FILE: lib/features/onboarding/presentation/pages/onboarding_page.dart
//
// Onboarding em 2 níveis:
// - OnboardingStage.personal (perfil): nickname, gender, age
// - OnboardingStage.life (vida): foco, objetivo, etc.
//
// Persistência:
// - Tudo salvo por UID: '${uid}:${questionId}'
// - Nickname também salvo em SessionStorage.nickname_<uid>
// - Flags:
//   - personal_done_<uid>
//   - life_done_<uid>
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/onboarding/questions.dart';
import '../../../../data/local/session_storage.dart';
import '../../../home/presentation/pages/home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.stage});

  final OnboardingStage stage;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  bool _saving = false;

  final TextEditingController _textController = TextEditingController();

  List<Question> get _questions => widget.stage == OnboardingStage.personal
      ? personalQuestions
      : lifeQuestions;

  String get _stageTitle =>
      widget.stage == OnboardingStage.personal ? 'Perfil' : 'Sua vida';

  String _doneKey(String uid) => widget.stage == OnboardingStage.personal
      ? 'personal_done_$uid'
      : 'life_done_$uid';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _persistAndNext() async {
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

    for (final e in _answers.entries) {
      await prefs.setString('${user.uid}:${e.key}', e.value);
    }

    final nickname = _answers['nickname']?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      await SessionStorage().saveNickname(user.uid, nickname);
    }

    await prefs.setBool(_doneKey(user.uid), true);

    if (!mounted) return;

    if (widget.stage == OnboardingStage.personal) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OnboardingPage(stage: OnboardingStage.life),
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  void _goNextOrFinish() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      return;
    }
    _persistAndNext();
  }

  void _setAnswerAndNext(String value) {
    _answers[_questions[_currentIndex].id] = value;
    _textController.clear();
    _goNextOrFinish();
  }

  void _submitTextOrNumber() {
    if (_saving) return;

    final q = _questions[_currentIndex];
    final raw = _textController.text.trim();

    if (raw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preencha para continuar.')));
      return;
    }

    if (q.type == QuestionType.number) {
      final n = int.tryParse(raw);
      if (n == null || n < 5 || n > 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite uma idade válida.')),
        );
        return;
      }
      _setAnswerAndNext(n.toString());
      return;
    }

    _setAnswerAndNext(raw);
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];

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
                      _stageTitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      q.question,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Pergunta ${_currentIndex + 1} de ${_questions.length}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 22),

                    if (q.type == QuestionType.options) ...[
                      ...q.options.map((opt) {
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
                                  : () => _setAnswerAndNext(opt),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(opt),
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      TextField(
                        controller: _textController,
                        enabled: !_saving,
                        keyboardType: q.type == QuestionType.number
                            ? TextInputType.number
                            : TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTextOrNumber(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: q.type == QuestionType.number
                              ? 'Idade'
                              : 'Texto',
                          labelStyle: const TextStyle(color: Colors.green),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                          focusedBorder: const OutlineInputBorder(
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
                          onPressed: _saving ? null : _submitTextOrNumber,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Continuar'),
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
