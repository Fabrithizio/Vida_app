// ============================================================================
// FILE: lib/features/goals/presentation/widgets/my_day_goals_section.dart
//
// O que este arquivo faz:
// - Cria um bloco pronto para puxar tarefas do dia para o Meu Dia
// - Mostra objetivos atrasados, prazos próximos e próximas ações
// - Permite marcar concluído rápido e abrir o detalhe completo
// ============================================================================

import 'package:flutter/material.dart';

import '../../data/models/goals_models.dart';
import '../../data/repositories/hive_goals_repository.dart';
import '../../domain/goals_runtime_service.dart';
import '../pages/goal_details_page.dart';

class MyDayGoalsSection extends StatefulWidget {
  const MyDayGoalsSection({super.key});

  @override
  State<MyDayGoalsSection> createState() => _MyDayGoalsSectionState();
}

class _MyDayGoalsSectionState extends State<MyDayGoalsSection> {
  final _repository = HiveGoalsRepository();
  final _runtime = GoalsRuntimeService();

  bool _loading = true;
  List<GoalPlanModel> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await _runtime.myDayItems(_repository, DateTime.now());

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openGoal(GoalPlanModel plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GoalDetailsPage(repository: _repository, initialPlan: plan),
      ),
    );
    await _reload();
  }

  Future<void> _quickDone(GoalPlanModel plan) async {
    final next = _runtime.completePlan(plan, DateTime.now());
    await _repository.saveGoal(next);
    await _reload();
  }

  String _dateLabel(int? ms) {
    if (ms == null) return 'Sem prazo';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10182B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Objetivos do dia',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _items.isEmpty
                ? 'Nada puxado para hoje. Excelente… ou suspeito demais.'
                : 'Tudo que a central de objetivos puxou para o seu Meu Dia.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Pendências com lembrete, atraso, prazo de hoje ou marcadas para aparecer no Meu Dia entram aqui automaticamente.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  height: 1.35,
                ),
              ),
            )
          else
            ..._items.take(6).map((goal) {
              final overdue = goal.isOverdue(DateTime.now());
              final accent = overdue
                  ? const Color(0xFFEF4444)
                  : goal.isDueSoon(DateTime.now(), withinDays: 2)
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF7C3AED);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _openGoal(goal),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            overdue
                                ? Icons.notification_important_rounded
                                : Icons.flag_rounded,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                goal.nextAction?.title ?? 'Sem próxima ação',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _dateLabel(goal.targetDateMs),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            IconButton(
                              onPressed: () => _quickDone(goal),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
