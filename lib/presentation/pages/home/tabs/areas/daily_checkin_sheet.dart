// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/daily_checkin_sheet.dart
//
// Sheet de check-in (HUD):
// - Fecha tocando fora / arrastando para baixo
// - Serve para visualizar e (se quiser) responder também
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../../features/areas/daily_checkin_service.dart';

class DailyCheckinSheet extends StatefulWidget {
  const DailyCheckinSheet({super.key});

  @override
  State<DailyCheckinSheet> createState() => _DailyCheckinSheetState();
}

class _DailyCheckinSheetState extends State<DailyCheckinSheet> {
  final DailyCheckinService _svc = DailyCheckinService();
  final DateTime _day = DateTime.now();
  late final List<DailyQuestion> _questions = _svc.questionsForToday(now: _day);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 14,
          right: 14,
          bottom: 14 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Check-in do dia',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            for (final q in _questions) ...[
              _Row(
                day: _day,
                q: q,
                svc: _svc,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fechar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.day,
    required this.q,
    required this.svc,
    required this.onChanged,
  });

  final DateTime day;
  final DailyQuestion q;
  final DailyCheckinService svc;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: svc.getAnswer(day: day, questionId: q.id),
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
                q.text,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            pill('SIM', ans == 1, () async {
              await svc.answer(day: day, questionId: q.id, value: 1);
              onChanged();
            }),
            const SizedBox(width: 8),
            pill('NÃO', ans == 0, () async {
              await svc.answer(day: day, questionId: q.id, value: 0);
              onChanged();
            }),
          ],
        );
      },
    );
  }
}
