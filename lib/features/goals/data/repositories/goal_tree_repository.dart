// lib/features/goals/data/repositories/goal_tree_repository.dart
import '../models/goal_tree_models.dart';

abstract class GoalTreeRepository {
  Future<List<GoalSummaryModel>> listGoals();
  Future<GoalTreeStateModel?> loadGoal(String goalId);
  Future<void> saveGoal(GoalTreeStateModel state);
  Future<void> deleteGoal(String goalId);
}
