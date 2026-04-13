// ============================================================================
// FILE: lib/features/areas/presentation/pages/daily_checkin_sheet.dart
//
// O que faz:
// - Abre o check-in diário manualmente
// - Mostra uma pergunta por vez
// - Usa um visual mais forte, chamativo e com cara de mini game
// - Mantém o salvamento pelo DailyCheckinService
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart' as daily;

class DailyCheckinSheet extends StatefulWidget {
  const DailyCheckinSheet({super.key});

  @override
  State<DailyCheckinSheet> createState() => _DailyCheckinSheetState();
}

class _DailyCheckinSheetState extends State<DailyCheckinSheet> {
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
    final questions = await _service.questionsForToday(now: _day);
    final completed = await _service.isCompleted(_day);

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
      _completed = completed;
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

    final isLast = _currentIndex >= _questions.length - 1;
    final nextPending = _questions.indexWhere((q) => _answers[q.id] == null);

    setState(() {
      _saving = false;
      _answered = answered;
      _completed = done;
      if (!done) {
        if (!isLast) {
          _currentIndex += 1;
        } else if (nextPending != -1) {
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

  Widget _buildReviewSheet(BuildContext context) {
    return Container(
      height: 560,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF080B16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13182A), Color(0xFF090B16)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _TopBadge(
                icon: Icons.history_rounded,
                text: 'Suas respostas',
                color: Color(0xFF48A7FF),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          Text(
            'Confira o que você respondeu para ontem e toque em uma pergunta se quiser ajustar.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _questions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final question = _questions[index];
                final accent = _accentForArea(question.areaId);
                final value = _answers[question.id];
                final label = value == null
                    ? 'Sem resposta'
                    : _service.answerLabel(value, question: question);
                String? description;
                if (value != null) {
                  for (final option in _service.optionsFor(question)) {
                    if (option.value == value) {
                      description = option.description;
                      break;
                    }
                  }
                }
                return InkWell(
                  onTap: () {
                    setState(() {
                      _completed = false;
                      _currentIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.16),
                          ),
                          child: Icon(
                            _iconForArea(question.areaId),
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (description != null &&
                                  description.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit_rounded,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 430,
        decoration: BoxDecoration(
          color: const Color(0xFF090B16),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_completed && _questions.isNotEmpty) {
      return _buildReviewSheet(context);
    }

    final question = _questions[_currentIndex];
    final answer = _answers[question.id];
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentIndex + 1) / _questions.length;
    final accent = _accentForArea(question.areaId);
    final options = _service.optionsFor(question);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF080B16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13182A), Color(0xFF090B16)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _TopBadge(
                  icon: Icons.auto_awesome_rounded,
                  text: 'Missão de ontem',
                  color: accent,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(_completed),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Responda uma por vez. Rápido, bonito e sem poluir a tela.',
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
                    onTap: _currentIndex >= _questions.length - 1 || _saving
                        ? null
                        : _goNext,
                  ),
                ),
              ],
            ),
          ],
        ),
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
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 26,
            spreadRadius: 1,
          ),
        ],
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
            'Toque na opção que mais combina com o que aconteceu ontem.',
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
                    'Salvando sua resposta...',
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
