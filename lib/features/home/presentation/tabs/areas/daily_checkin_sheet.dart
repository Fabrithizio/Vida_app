// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/daily_checkin_sheet.dart
//
// O que faz:
// - Abre o check-in diário manualmente
// - Mostra as perguntas do dia
// - Salva respostas
// - Finaliza o check-in quando tudo for respondido
//
// Correção:
// - questionsForToday agora é async, então este arquivo usa await corretamente
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

  List<daily.DailyQuestion> _questions = [];
  bool _loading = true;
  bool _saving = false;
  int _answered = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final questions = await _service.questionsForToday(now: _day);
    final answered = await _service.answeredCount(_day);
    final completed = await _service.isCompleted(_day);

    if (!mounted) return;

    setState(() {
      _questions = questions;
      _answered = answered;
      _completed = completed;
      _loading = false;
    });
  }

  Future<void> _setAnswer(daily.DailyQuestion question, int value) async {
    if (!mounted) return;

    setState(() => _saving = true);

    await _service.answer(day: _day, questionId: question.id, value: value);

    final answered = await _service.answeredCount(_day);
    final done = await _service.tryCompleteIfAllAnswered(_day);

    if (!mounted) return;

    setState(() {
      _saving = false;
      _answered = answered;
      _completed = done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _questions.isEmpty ? 0.0 : _answered / _questions.length;
    final remaining = (_questions.length - _answered).clamp(
      0,
      _questions.length,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
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
                  Text(
                    _completed
                        ? 'Seu check-in de hoje já está completo.'
                        : remaining == 0
                        ? 'Tudo certo. Finalizando seu check-in...'
                        : 'Responda as perguntas rápidas para manter o Painel da Vida atualizado.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Respondidas: $_answered/${_questions.length}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final question in _questions) ...[
                            _QuestionRow(
                              day: _day,
                              question: question,
                              service: _service,
                              onAnswer: (value) => _setAnswer(question, value),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(_completed),
                      child: Text(_completed ? 'Fechar' : 'Voltar'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.day,
    required this.question,
    required this.service,
    required this.onAnswer,
  });

  final DateTime day;
  final daily.DailyQuestion question;
  final daily.DailyCheckinService service;
  final void Function(int value) onAnswer;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: service.getAnswer(day: day, questionId: question.id),
      builder: (context, snapshot) {
        final answer = snapshot.data;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                question.text,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 10),
            pill('SIM', answer == 1, () => onAnswer(1)),
            const SizedBox(width: 8),
            pill('NÃO', answer == 0, () => onAnswer(0)),
          ],
        );
      },
    );
  }
}
