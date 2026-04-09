// ============================================================================
// FILE: lib/features/onboarding/presentation/pages/onboarding_page.dart
//
// Tela do onboarding inicial.
// - Mantém o fluxo atual em 2 etapas (personal -> life -> home)
// - Adiciona uma tela inicial explicativa
// - Mostra a área da vida ligada a cada pergunta
// - Mantém CPF opcional com validação
// - Coloca barras automaticamente nas datas (DD/MM/AAAA)
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _saving = false;

  final Map<String, String> _answers = <String, String>{};
  final TextEditingController _textController = TextEditingController();

  List<Question> get _questions => widget.stage == OnboardingStage.personal
      ? personalQuestions
      : lifeQuestions;

  Question get _currentQuestion => _questions[_currentIndex];

  String get _stageTitle => widget.stage == OnboardingStage.personal
      ? 'Perfil inicial'
      : 'Contexto da sua vida';

  String _doneKey(String uid) => widget.stage == OnboardingStage.personal
      ? 'personal_done_$uid'
      : 'life_done_$uid';

  @override
  void initState() {
    super.initState();
    _syncControllerWithCurrentQuestion();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _persistAndFinishStage() async {
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

    for (final entry in _answers.entries) {
      await prefs.setString('${user.uid}:${entry.key}', entry.value);
    }

    final nickname = (_answers['nickname'] ?? '').trim();
    if (nickname.isNotEmpty) {
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

  void _goToNextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _syncControllerWithCurrentQuestion();
      return;
    }
    _persistAndFinishStage();
  }

  void _goToPreviousQuestion() {
    if (_saving || _currentIndex == 0) return;
    setState(() => _currentIndex--);
    _syncControllerWithCurrentQuestion();
  }

  void _setAnswerAndNext(String value) {
    _answers[_currentQuestion.id] = value;
    _goToNextQuestion();
  }

  void _syncControllerWithCurrentQuestion() {
    final q = _currentQuestion;
    final raw = (_answers[q.id] ?? '').trim();

    if (q.type == QuestionType.date) {
      _textController.text = _formatIsoToBrIfPossible(raw);
      return;
    }

    if (q.id == 'cpf') {
      _textController.text = _digitsOnly(raw);
      return;
    }

    _textController.text = raw;
  }

  String _formatIsoToBrIfPossible(String raw) {
    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!regex.hasMatch(raw)) return raw;

    final parts = raw.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

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
      return mod < 2 ? 0 : 11 - mod;
    }

    final d1 = calcDigit(9);
    final d2 = calcDigit(10);

    return cpf[9] == '$d1' && cpf[10] == '$d2';
  }

  DateTime? _parseBrazilDate(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    if (year < 1900 || year > DateTime.now().year) return null;

    try {
      final dt = DateTime(year, month, day);
      if (dt.year != year || dt.month != month || dt.day != day) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;

    final alreadyHadBirthday =
        (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);

    if (!alreadyHadBirthday) age--;

    return age;
  }

  void _submitTextQuestion() {
    if (_saving) return;

    final q = _currentQuestion;

    if (q.type == QuestionType.info) {
      _goToNextQuestion();
      return;
    }

    final raw = _textController.text.trim();

    if (raw.isEmpty) {
      if (q.optional) {
        _goToNextQuestion();
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

    if (q.type == QuestionType.date) {
      final dt = _parseBrazilDate(raw);

      if (dt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data inválida. Use DD/MM/AAAA.')),
        );
        return;
      }

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

  List<TextInputFormatter> _inputFormattersFor(Question q) {
    if (q.type == QuestionType.date) {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
        _BrazilDateTextInputFormatter(),
      ];
    }

    if (q.id == 'cpf') {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ];
    }

    return const <TextInputFormatter>[];
  }

  TextInputType _keyboardTypeFor(Question q) {
    if (q.type == QuestionType.date || q.id == 'cpf') {
      return TextInputType.number;
    }
    return TextInputType.text;
  }

  double get _progressValue {
    if (_questions.isEmpty) return 0;
    return (_currentIndex + 1) / _questions.length;
  }

  @override
  Widget build(BuildContext context) {
    final q = _currentQuestion;
    final isInfo = q.type == QuestionType.info;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (_currentIndex > 0)
                          IconButton(
                            onPressed: _saving ? null : _goToPreviousQuestion,
                            icon: const Icon(Icons.arrow_back_ios_new),
                            color: Colors.white70,
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _stageTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _progressValue,
                                  minHeight: 8,
                                  backgroundColor: Colors.white12,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.green,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Etapa ${_currentIndex + 1} de ${_questions.length}',
                                style: const TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (q.sectionTitle != null) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.40),
                            ),
                          ),
                          child: Text(
                            q.sectionTitle!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      if ((q.sectionDescription ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          q.sectionDescription!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                    ] else ...[
                      const SizedBox(height: 24),
                    ],
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101010),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            q.question,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isInfo ? 28 : 24,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                            ),
                          ),
                          if (q.helper != null &&
                              q.helper!.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              q.helper!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isInfo)
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _goToNextQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(q.ctaText ?? 'Continuar'),
                        ),
                      )
                    else if (q.type == QuestionType.options) ...[
                      for (final option in q.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _setAnswerAndNext(option),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E1E1E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                side: const BorderSide(color: Colors.white12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                option,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (q.optional)
                        TextButton(
                          onPressed: _saving ? null : _goToNextQuestion,
                          child: const Text('Pular'),
                        ),
                    ] else ...[
                      TextField(
                        controller: _textController,
                        enabled: !_saving,
                        keyboardType: _keyboardTypeFor(q),
                        inputFormatters: _inputFormattersFor(q),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitTextQuestion(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: q.type == QuestionType.date
                              ? 'DD/MM/AAAA'
                              : q.id == 'cpf'
                              ? '11 dígitos'
                              : 'Digite aqui',
                          labelStyle: const TextStyle(color: Colors.green),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
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
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _submitTextQuestion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(q.ctaText ?? 'Continuar'),
                              ),
                            ),
                          ),
                          if (q.optional) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _saving ? null : _goToNextQuestion,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
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

class _BrazilDateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 3) {
        if (i != digits.length - 1) {
          buffer.write('/');
        }
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
