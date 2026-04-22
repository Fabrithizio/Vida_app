// ============================================================================
// FILE: lib/features/goals/goals_alerts_bridge.dart
//
// O que este arquivo faz:
// - Converte objetivos importantes em alertas do sino do app
// - Reaproveita o modelo LifeAlert já existente
// - Permite integrar a central de objetivos ao sistema global de notificações
// ============================================================================

import 'package:vida_app/data/models/life_alert.dart';
import 'package:vida_app/features/goals/data/repositories/hive_goals_repository.dart';
import 'package:vida_app/features/goals/domain/goals_runtime_service.dart';

class GoalsAlertsBridge {
  GoalsAlertsBridge({
    HiveGoalsRepository? repository,
    GoalsRuntimeService? runtime,
  }) : _repository = repository ?? HiveGoalsRepository(),
       _runtime = runtime ?? GoalsRuntimeService();

  final HiveGoalsRepository _repository;
  final GoalsRuntimeService _runtime;

  Future<List<LifeAlert>> build(DateTime now) async {
    final plans = await _runtime.loadAllPlans(_repository);
    final items = _runtime.buildAttentionList(plans, now);

    return items.map((item) {
      final priority = item.severity >= 90
          ? LifeAlertPriority.critical
          : item.severity >= 75
          ? LifeAlertPriority.high
          : LifeAlertPriority.medium;

      return LifeAlert(
        id: item.id,
        type: LifeAlertType.goalMomentum,
        title: item.title,
        message: item.message,
        priority: priority,
        createdAt: now,
        areaId: 'goals',
        actionLabel: 'Abrir objetivo',
        routeHint: 'goals',
        metadata: {'goalId': item.goalId, 'openGoalsToday': true},
      );
    }).toList();
  }
}
