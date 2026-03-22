// ============================================================================
// FILE: lib/features/onboarding/presentation/pages/onboarding_page.dart
//
// Onboarding em 2 níveis + DOB + CPF opcional (com botão "Pular").
// - Salva tudo por UID: '${uid}:${questionId}'
// - Nickname também em SessionStorage.nickname_<uid>
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
      _textController.clear();
      return;
    }
    _persistAndNext();
  }

  void _setAnswerAndNext(String value) {
    _answers[_questions[_currentIndex].id] = value;
    _textController.clear();
    _goNextOrFinish();
  }

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  bool _isValidCpf(String raw) {
    final cpf = _digitsOnly(raw);
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    int calcDigit(int length) {
      int sum = 0;
      int weight = length + 1;
      for (int i = 0; i < length; i++) {
        sum += int.parse(cpf[i]) * (weight--);
      }
      final mod = sum % 11;
      return (mod < 2) ? 0 : (11 - mod);
    }

    final d1 = calcDigit(9);
    final d2 = calcDigit(10);
    return cpf[9] == '$d1' && cpf[10] == '$d2';
  }

  DateTime? _parseBrazilDate(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (y < 1900 || y > DateTime.now().year) return null;

    try {
      final dt = DateTime(y, m, d);
      if (dt.year != y || dt.month != m || dt.day != d) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    final hasHadBirthdayThisYear =
        (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hasHadBirthdayThisYear) age--;
    return age;
  }

  void _submitTextNumberDate() {
    if (_saving) return;

    final q = _questions[_currentIndex];
    final raw = _textController.text.trim();

    if (raw.isEmpty) {
      if (q.optional) {
        _goNextOrFinish();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preencha para continuar.')));
      return;
    }

    if (q.id == 'cpf') {
      if (!_isValidCpf(raw)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CPF inválido. Você pode corrigir ou pular.'),
          ),
        );
        return;
      }
      _setAnswerAndNext(_digitsOnly(raw));
      return;
    }

    if (q.type == QuestionType.number) {
      final n = int.tryParse(raw);
      if (n == null || n < 0 || n > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite um número válido.')),
        );
        return;
      }
      _setAnswerAndNext(n.toString());
      return;
    }

    if (q.type == QuestionType.date) {
      final dt = _parseBrazilDate(raw);
      if (dt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data inválida. Use DD/MM/AAAA.')),
        );
        return;
      }

      // Se for DOB, valida idade mínima lógica
      if (q.id == 'dob') {
        final age = _ageFromDob(dt);
        if (age < 5 || age > 120) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data de nascimento inválida.')),
          );
          return;
        }
      }

      final iso =
          '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
      _setAnswerAndNext(iso);
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
                    if (q.helper != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        q.helper!,
                        style: const TextStyle(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                      if (q.optional) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _saving ? null : _goNextOrFinish,
                          child: const Text('Pular'),
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: _textController,
                        enabled: !_saving,
                        keyboardType: q.type == QuestionType.number
                            ? TextInputType.number
                            : TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTextNumberDate(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: q.type == QuestionType.date
                              ? 'DD/MM/AAAA'
                              : (q.type == QuestionType.number
                                    ? 'Número'
                                    : 'Texto'),
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
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: _saving
                                    ? null
                                    : _submitTextNumberDate,
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
                          ),
                          if (q.optional) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _saving ? null : _goNextOrFinish,
                                child: const Text('Pular'),
                              ),
                            ),
                          ],
                        ],
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
