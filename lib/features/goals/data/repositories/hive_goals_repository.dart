// ============================================================================
// FILE: lib/features/goals/data/repositories/hive_goals_repository.dart
//
// O que este arquivo faz:
// - Salva a nova central de metas por usuário no Hive
// - Mantém um índice leve para carregar o hub rápido
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/goals_models.dart';
import 'goals_repository.dart';

class HiveGoalsRepository implements GoalsRepository {
  static const _boxPrefix = 'goal_planner_box_v1_';
  static const _indexKey = 'goals_index';

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> _open() async =>
      Hive.openBox<dynamic>('$_boxPrefix${_uidOrAnon()}');

  String _goalKey(String id) => 'goal_$id';

  @override
  Future<List<GoalSummaryModel>> listGoals() async {
    final box = await _open();
    final raw = box.get(_indexKey);
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map(
          (item) => GoalSummaryModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList()
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
  }

  @override
  Future<GoalPlanModel?> loadGoal(String goalId) async {
    final box = await _open();
    final raw = box.get(_goalKey(goalId));
    if (raw is! Map) return null;
    return GoalPlanModel.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> saveGoal(GoalPlanModel plan) async {
    final box = await _open();
    await box.put(_goalKey(plan.id), plan.toMap());

    final current = await listGoals();
    final next = <GoalSummaryModel>[
      ...current.where((item) => item.id != plan.id),
      GoalSummaryModel.fromPlan(plan),
    ]..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

    await box.put(_indexKey, next.map((item) => item.toMap()).toList());
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final box = await _open();
    await box.delete(_goalKey(goalId));

    final current = await listGoals();
    final next = current.where((item) => item.id != goalId).toList();
    await box.put(_indexKey, next.map((item) => item.toMap()).toList());
  }
}
