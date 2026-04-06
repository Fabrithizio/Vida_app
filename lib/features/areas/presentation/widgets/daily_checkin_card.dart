// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/daily_checkin_card.dart
//
// O que faz:
// - Mostra o card compacto do check-in diário dentro da tela de Areas
// - Exibe as perguntas do dia com as opções corretas de cada escala
// - Salva respostas graduais no DailyCheckinService
//
// Nesta revisão:
// - remove o SIM / NÃO fixo da UI
// - passa a usar optionsFor(question)
// - preserva o layout base do card, mudando só a lógica das respostas
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';

class DailyCheckinCard extends StatefulWidget {
  const DailyCheckinCard({super.key});

  @override
  State<DailyCheckinCard> createState() => _DailyCheckinCardState();
}

class _DailyCheckinCardState extends State<DailyCheckinCard> {
  final DailyCheckinService _svc = DailyCheckinService();
  late final DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DailyQuestion>>(
      future: _svc.questionsForToday(now: _day),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Erro ao carregar perguntas',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final questions = snapshot.data ?? const <DailyQuestion>[];

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
              for (final q in questions) ...[
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
      },
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
        final answer = snap.data;
        final options = svc.optionsFor(question);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    _AnswerPill(
                      text: options[i].shortLabel,
                      selected: answer == options[i].value,
                      onTap: () async {
                        await svc.answer(
                          day: day,
                          questionId: question.id,
                          value: options[i].value,
                        );
                        onChanged();
                      },
                    ),
                    if (i != options.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnswerPill extends StatelessWidget {
  const _AnswerPill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
}
