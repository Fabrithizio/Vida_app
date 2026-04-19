// ============================================================================
// FILE: lib/features/goals/data/repositories/goals_repository.dart
//
// O que este arquivo faz:
// - Define o contrato de persistência da nova central de metas
// ============================================================================

import '../models/goals_models.dart';

abstract class GoalsRepository {
  Future<List<GoalSummaryModel>> listGoals();
  Future<GoalPlanModel?> loadGoal(String goalId);
  Future<void> saveGoal(GoalPlanModel plan);
  Future<void> deleteGoal(String goalId);
}
