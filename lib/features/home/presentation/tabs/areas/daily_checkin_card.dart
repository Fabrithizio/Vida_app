// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/daily_checkin_card.dart
//
// Card de check-in diário (5 perguntas):
// - Mostra as perguntas do dia
// - Permite responder SIM / NÃO (salva offline)
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../areas/daily_checkin_service.dart';

class DailyCheckinCard extends StatefulWidget {
  const DailyCheckinCard({super.key});

  @override
  State<DailyCheckinCard> createState() => _DailyCheckinCardState();
}

class _DailyCheckinCardState extends State<DailyCheckinCard> {
  final DailyCheckinService _svc = DailyCheckinService();

  late final DateTime _day = DateTime.now();
  late final List<DailyQuestion> _questions = _svc.questionsForToday(now: _day);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Check-in do dia',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Responda rápido para manter seu Painel atualizado.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          for (final q in _questions) ...[
            _QuestionRow(
              question: q,
              day: _day,
              svc: _svc,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.day,
    required this.svc,
    required this.onChanged,
  });

  final DailyQuestion question;
  final DateTime day;
  final DailyCheckinService svc;
  final VoidCallback onChanged;

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
                  fontWeight: FontWeight.w800,
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
            pill('SIM', ans == 1, () async {
              await svc.answer(day: day, questionId: question.id, value: 1);
              onChanged();
            }),
            const SizedBox(width: 8),
            pill('NÃO', ans == 0, () async {
              await svc.answer(day: day, questionId: question.id, value: 0);
              onChanged();
            }),
          ],
        );
      },
    );
  }
}
