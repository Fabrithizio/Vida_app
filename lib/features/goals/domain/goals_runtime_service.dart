// ============================================================================
// FILE: lib/features/goals/domain/goals_runtime_service.dart
//
// O que este arquivo faz:
// - Centraliza a lógica viva do módulo de objetivos
// - Resolve recorrência, lembretes, tarefas do Meu Dia e itens atrasados
// - Gera uma leitura pronta para alertas do sino sem espalhar regra no app
// ============================================================================

import '../data/models/goals_models.dart';
import '../data/repositories/goals_repository.dart';

class GoalRuntimeAttention {
  const GoalRuntimeAttention({
    required this.id,
    required this.title,
    required this.message,
    required this.goalId,
    required this.severity,
  });

  final String id;
  final String title;
  final String message;
  final String goalId;
  final int severity;
}

class GoalsRuntimeService {
  Future<List<GoalPlanModel>> loadAllPlans(GoalsRepository repository) async {
    final summaries = await repository.listGoals();
    final items = <GoalPlanModel>[];

    for (final summary in summaries) {
      final plan = await repository.loadGoal(summary.id);
      if (plan != null) {
        items.add(plan);
      }
    }

    items.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return items;
  }

  Future<List<GoalPlanModel>> myDayItems(
    GoalsRepository repository,
    DateTime now,
  ) async {
    final plans = await loadAllPlans(repository);
    return plans.where((item) => item.shouldAppearInMyDay(now)).toList()
      ..sort((a, b) {
        final aOverdue = a.isOverdue(now) ? 1 : 0;
        final bOverdue = b.isOverdue(now) ? 1 : 0;
        if (aOverdue != bOverdue) return bOverdue.compareTo(aOverdue);

        final aReminder = a.reminderAtMs ?? 1 << 60;
        final bReminder = b.reminderAtMs ?? 1 << 60;
        if (aReminder != bReminder) return aReminder.compareTo(bReminder);

        final aDue = a.targetDateMs ?? 1 << 60;
        final bDue = b.targetDateMs ?? 1 << 60;
        return aDue.compareTo(bDue);
      });
  }

  List<GoalRuntimeAttention> buildAttentionList(
    List<GoalPlanModel> plans,
    DateTime now,
  ) {
    final out = <GoalRuntimeAttention>[];

    for (final plan in plans) {
      if (plan.isCompleted) continue;

      if (plan.isOverdue(now)) {
        out.add(
          GoalRuntimeAttention(
            id: 'goal_overdue_${plan.id}',
            title: 'Objetivo atrasado',
            message: '${plan.title} já passou do prazo e ainda pede ação.',
            goalId: plan.id,
            severity: 100,
          ),
        );
      } else if (plan.isDueSoon(now, withinDays: 2)) {
        out.add(
          GoalRuntimeAttention(
            id: 'goal_due_soon_${plan.id}',
            title: 'Prazo chegando',
            message: '${plan.title} está perto do prazo e merece atenção.',
            goalId: plan.id,
            severity: 80,
          ),
        );
      } else if (plan.isReminderDue(now)) {
        out.add(
          GoalRuntimeAttention(
            id: 'goal_reminder_${plan.id}',
            title: 'Lembrete de objetivo',
            message:
                'Você pediu para lembrar de ${plan.title}. A próxima ação está te esperando.',
            goalId: plan.id,
            severity: 70,
          ),
        );
      } else if (plan.pinToMyDay &&
          plan.nextAction != null &&
          !plan.waitingForSomeone &&
          !plan.somedayMaybe) {
        out.add(
          GoalRuntimeAttention(
            id: 'goal_next_action_${plan.id}',
            title: 'Tarefa puxada para hoje',
            message:
                'A próxima ação de ${plan.title} foi puxada para o Meu Dia.',
            goalId: plan.id,
            severity: 50,
          ),
        );
      }
    }

    out.sort((a, b) => b.severity.compareTo(a.severity));
    return out;
  }

  GoalPlanModel completePlan(GoalPlanModel plan, DateTime now) {
    final nextMilestones = plan.milestones
        .map(
          (milestone) => milestone.copyWith(
            isDone: true,
            actions: milestone.actions
                .map((action) => action.copyWith(isDone: true))
                .toList(),
          ),
        )
        .toList();

    final doneVersion = plan.copyWith(
      milestones: nextMilestones,
      status: GoalStatus.completed,
      updatedAtMs: now.millisecondsSinceEpoch,
      currentStageLabel: 'Concluído',
      lastCompletedAtMs: now.millisecondsSinceEpoch,
    );

    if (!plan.isRecurring) return doneVersion;
    return reopenForRecurrence(doneVersion, now);
  }

  GoalPlanModel reopenForRecurrence(GoalPlanModel plan, DateTime now) {
    final nextMilestones = plan.milestones
        .map(
          (milestone) => milestone.copyWith(
            isDone: false,
            actions: milestone.actions
                .map((action) => action.copyWith(isDone: false))
                .toList(),
          ),
        )
        .toList();

    final nextReminder = _advanceRecurrence(
      now: now,
      recurrence: plan.recurrence,
      interval: plan.recurrenceInterval,
    );

    return plan.copyWith(
      milestones: nextMilestones,
      status: GoalStatus.active,
      updatedAtMs: now.millisecondsSinceEpoch,
      currentStageLabel: nextMilestones.isEmpty
          ? 'Sem etapa'
          : nextMilestones.first.title,
      reminderAtMs: nextReminder.millisecondsSinceEpoch,
      targetDateMs: plan.targetDateMs == null
          ? null
          : nextReminder.millisecondsSinceEpoch,
    );
  }

  DateTime _advanceRecurrence({
    required DateTime now,
    required GoalRecurrenceType recurrence,
    required int interval,
  }) {
    switch (recurrence) {
      case GoalRecurrenceType.none:
        return now;
      case GoalRecurrenceType.daily:
        return now.add(Duration(days: interval));
      case GoalRecurrenceType.weekly:
        return now.add(Duration(days: 7 * interval));
      case GoalRecurrenceType.monthly:
        return DateTime(
          now.year,
          now.month + interval,
          now.day,
          now.hour,
          now.minute,
        );
    }
  }
}
