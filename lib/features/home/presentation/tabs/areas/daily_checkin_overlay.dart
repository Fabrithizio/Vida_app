// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/daily_checkin_overlay.dart
//
// Overlay bloqueante do check-in diário:
// - Aparece por cima de tudo
// - Não fecha até responder as 5 perguntas
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../../../features/areas/daily_checkin_service.dart';

class DailyCheckinOverlay extends StatefulWidget {
  const DailyCheckinOverlay({super.key});

  @override
  State<DailyCheckinOverlay> createState() => _DailyCheckinOverlayState();
}

class _DailyCheckinOverlayState extends State<DailyCheckinOverlay> {
  final DailyCheckinService _svc = DailyCheckinService();
  final DateTime _day = DateTime.now();
  late final List<DailyQuestion> _questions = _svc.questionsForToday(now: _day);

  bool _saving = false;

  Future<void> _setAnswer(DailyQuestion q, int value) async {
    setState(() => _saving = true);
    await _svc.answer(day: _day, questionId: q.id, value: value);
    final done = await _svc.tryCompleteIfAllAnswered(_day);
    if (!mounted) return;
    setState(() => _saving = false);

    if (done) {
      Navigator.of(context).pop(true); // fecha overlay
    } else {
      setState(() {}); // atualiza UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // bloqueia voltar
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.80),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Check-in do dia',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_saving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Responda 5 perguntas rápidas para manter seu Painel atualizado.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  for (final q in _questions) ...[
                    _QuestionRow(
                      day: _day,
                      question: q,
                      svc: _svc,
                      onAnswer: (v) => _setAnswer(q, v),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.day,
    required this.question,
    required this.svc,
    required this.onAnswer,
  });

  final DateTime day;
  final DailyQuestion question;
  final DailyCheckinService svc;
  final void Function(int value) onAnswer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: svc.getAnswer(day: day, questionId: question.id),
      builder: (context, snap) {
        final ans = snap.data;

        Widget pill(String text, bool selected, VoidCallback onTap) {
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.green.withValues(alpha: 0.18)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Colors.green.withValues(alpha: 0.55)
                      : Colors.white12,
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.green : Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                question.text,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            pill('SIM', ans == 1, () => onAnswer(1)),
            const SizedBox(width: 8),
            pill('NÃO', ans == 0, () => onAnswer(0)),
          ],
        );
      },
    );
  }
}
