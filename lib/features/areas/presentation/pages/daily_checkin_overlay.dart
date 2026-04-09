// ============================================================================
// FILE: lib/features/areas/presentation/pages/daily_checkin_overlay.dart
//
// O que faz:
// - Bloqueia o uso do painel de Áreas até responder o check-in
// - Mostra uma pergunta por vez
// - Usa um visual mais forte e mais chamativo
// - Fecha automaticamente quando tudo for respondido
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart' as daily;

class DailyCheckinOverlay extends StatefulWidget {
  const DailyCheckinOverlay({super.key});

  @override
  State<DailyCheckinOverlay> createState() => _DailyCheckinOverlayState();
}

class _DailyCheckinOverlayState extends State<DailyCheckinOverlay> {
  final daily.DailyCheckinService _service = daily.DailyCheckinService();
  final DateTime _day = DateTime.now();

  List<daily.DailyQuestion> _questions = const [];
  final Map<String, int?> _answers = <String, int?>{};
  bool _loading = true;
  bool _saving = false;
  int _currentIndex = 0;
  int _answered = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final completed = await _service.isCompleted(_day);
    if (completed) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      });
      return;
    }

    final questions = await _service.questionsForToday(now: _day);

    for (final question in questions) {
      _answers[question.id] = await _service.getAnswer(
        day: _day,
        questionId: question.id,
      );
    }

    final answered = _answers.values.whereType<int>().length;
    final firstPending = questions.indexWhere((q) => _answers[q.id] == null);

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _answered = answered;
      _currentIndex = firstPending == -1 ? 0 : firstPending;
      _loading = false;
    });
  }

  Future<void> _answerCurrent(int value) async {
    if (_saving || _questions.isEmpty) return;
    final question = _questions[_currentIndex];

    setState(() {
      _saving = true;
      _answers[question.id] = value;
    });

    await _service.answer(day: _day, questionId: question.id, value: value);
    final answered = _answers.values.whereType<int>().length;
    final done = await _service.tryCompleteIfAllAnswered(_day);

    if (!mounted) return;

    if (done) {
      setState(() {
        _saving = false;
        _answered = answered;
        _completed = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _saving = false;
      _answered = answered;
      if (_currentIndex < _questions.length - 1) {
        _currentIndex += 1;
      } else {
        final nextPending = _questions.indexWhere(
          (q) => _answers[q.id] == null,
        );
        if (nextPending != -1) {
          _currentIndex = nextPending;
        }
      }
    });
  }

  void _goPrev() {
    if (_currentIndex == 0 || _saving) return;
    setState(() => _currentIndex -= 1);
  }

  void _goNext() {
    if (_currentIndex >= _questions.length - 1 || _saving) return;
    setState(() => _currentIndex += 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xCC000000),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_completed && _questions.isNotEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xE6000000),
        body: Center(child: _DoneOverlay()),
      );
    }

    final question = _questions[_currentIndex];
    final answer = _answers[question.id];
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentIndex + 1) / _questions.length;
    final accent = _accentForArea(question.areaId);
    final options = _service.optionsFor(question);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.86),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(14),
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF080B16),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white10),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF151B30), Color(0xFF080B16)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.14),
                    blurRadius: 30,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _TopBadge(
                        icon: Icons.bolt_rounded,
                        text: 'Missão de ontem',
                        color: accent,
                      ),
                      const Spacer(),
                      Text(
                        'Obrigatório',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Antes de entrar nas Áreas, complete esta rodada rápida sobre ontem.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Pergunta ${_currentIndex + 1} de ${_questions.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Respondidas: $_answered/${_questions.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _QuestionCard(
                      key: ValueKey<String>(question.id),
                      question: question,
                      accent: accent,
                      selectedValue: answer,
                      options: options,
                      saving: _saving,
                      onSelect: _answerCurrent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _NavButton(
                          icon: Icons.arrow_back_rounded,
                          label: 'Anterior',
                          onTap: _currentIndex == 0 || _saving ? null : _goPrev,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NavButton(
                          icon: Icons.arrow_forward_rounded,
                          label: 'Próxima',
                          filled: true,
                          color: accent,
                          onTap:
                              _currentIndex >= _questions.length - 1 || _saving
                              ? null
                              : _goNext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneOverlay extends StatelessWidget {
  const _DoneOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F2B2A), Color(0xFF0A0E18)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withValues(alpha: 0.16),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.20),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.greenAccent,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tudo pronto',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Liberando seu painel...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.accent,
    required this.selectedValue,
    required this.options,
    required this.saving,
    required this.onSelect,
  });

  final daily.DailyQuestion question;
  final Color accent;
  final int? selectedValue;
  final List<daily.DailyAnswerOption> options;
  final bool saving;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 310),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.18), const Color(0xFF0C1020)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBadge(
            icon: _iconForArea(question.areaId),
            text: question.areaLabel,
            color: accent,
          ),
          const SizedBox(height: 18),
          Text(
            question.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Escolha a opção que mais combina com ontem.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          for (final option in options) ...[
            _AnswerCard(
              text: option.label,
              description: option.description,
              accent: accent,
              selected: selectedValue == option.value,
              disabled: saving,
              onTap: () => onSelect(option.value),
            ),
            const SizedBox(height: 10),
          ],
          if (saving)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Salvando...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.text,
    this.description,
    required this.accent,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String text;
  final String? description;
  final Color accent;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.white12,
            width: selected ? 2 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: selected
                ? [
                    accent.withValues(alpha: 0.24),
                    accent.withValues(alpha: 0.10),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.02),
                  ],
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : Colors.transparent,
                border: Border.all(
                  color: selected ? accent : Colors.white24,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.90),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (description != null &&
                      description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.88)
                            : Colors.white.withValues(alpha: 0.62),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: selected ? accent : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: filled
              ? (enabled ? color : color.withValues(alpha: 0.35))
              : Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
          border: Border.all(
            color: filled ? Colors.transparent : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: filled
                  ? Colors.white
                  : (enabled ? Colors.white70 : Colors.white24),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: filled
                    ? Colors.white
                    : (enabled ? Colors.white70 : Colors.white24),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _accentForArea(String areaId) {
  switch (areaId) {
    case 'body_health':
      return const Color(0xFF00D68F);
    case 'mind_emotion':
      return const Color(0xFF8B7CFF);
    case 'finance_material':
      return const Color(0xFFFFC145);
    case 'work_vocation':
      return const Color(0xFF48A7FF);
    case 'learning_intellect':
      return const Color(0xFFFF7AD9);
    case 'relations_community':
      return const Color(0xFFFF6B6B);
    case 'digital_tech':
      return const Color(0xFF00C2FF);
    default:
      return const Color(0xFF8BE38B);
  }
}

IconData _iconForArea(String areaId) {
  switch (areaId) {
    case 'body_health':
      return Icons.favorite_rounded;
    case 'mind_emotion':
      return Icons.psychology_rounded;
    case 'finance_material':
      return Icons.savings_rounded;
    case 'work_vocation':
      return Icons.work_rounded;
    case 'learning_intellect':
      return Icons.school_rounded;
    case 'relations_community':
      return Icons.groups_rounded;
    case 'digital_tech':
      return Icons.phone_android_rounded;
    default:
      return Icons.stars_rounded;
  }
}
