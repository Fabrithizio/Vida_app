// lib/features/goals/data/repositories/hive_goal_tree_repository.dart
import 'package:hive_flutter/hive_flutter.dart';

import '../models/goal_tree_models.dart';
import 'goal_tree_repository.dart';

class HiveGoalTreeRepository implements GoalTreeRepository {
  static const _boxName = 'goal_tree_box_v2';
  static const _indexKey = 'goals_index';

  Future<Box<dynamic>> _open() async => Hive.openBox<dynamic>(_boxName);

  String _goalKey(String id) => 'goal_$id';

  @override
  Future<List<GoalSummaryModel>> listGoals() async {
    final box = await _open();
    final raw = box.get(_indexKey);

    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => GoalSummaryModel.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  @override
  Future<GoalTreeStateModel?> loadGoal(String goalId) async {
    final box = await _open();
    final raw = box.get(_goalKey(goalId));
    if (raw is! Map) return null;
    return GoalTreeStateModel.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> saveGoal(GoalTreeStateModel state) async {
    final box = await _open();

    await box.put(_goalKey(state.goalId), state.toMap());

    final current = await listGoals();
    final next = <GoalSummaryModel>[
      ...current.where((g) => g.goalId != state.goalId),
      GoalSummaryModel(
        goalId: state.goalId,
        goalTitle: state.goalTitle,
        templateId: state.templateId,
        createdAtMs: state.createdAtMs,
      ),
    ]..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    await box.put(_indexKey, next.map((e) => e.toMap()).toList());
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final box = await _open();
    await box.delete(_goalKey(goalId));

    final current = await listGoals();
    final next = current.where((g) => g.goalId != goalId).toList();
    await box.put(_indexKey, next.map((e) => e.toMap()).toList());
  }
}
