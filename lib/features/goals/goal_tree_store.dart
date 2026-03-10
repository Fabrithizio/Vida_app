// lib/features/goals/goal_tree_store.dart
import 'package:flutter/foundation.dart';
import 'data/models/goal_tree_models.dart';
import 'data/repositories/goal_tree_repository.dart';

class GoalTreeStore extends ChangeNotifier {
  GoalTreeStore({required GoalTreeRepository repo, required String goalId})
    : _repo = repo,
      _goalId = goalId;

  final GoalTreeRepository _repo;
  final String _goalId;

  GoalTreeStateModel? _state;
  final Map<String, GoalNodeStatus> _status = <String, GoalNodeStatus>{};

  GoalTreeStateModel get state {
    final s = _state;
    if (s == null) {
      // Deve sempre carregar antes, mas protege.
      return GoalTreeStateModel(
        goalId: _goalId,
        goalTitle: 'Meta',
        templateId: 'unknown',
        nodes: const [],
        completedIds: <String>{},
        createdAtMs: 0,
      );
    }
    return s;
  }

  Map<String, GoalNodeStatus> get statuses => Map.unmodifiable(_status);

  Future<void> load() async {
    final loaded = await _repo.loadGoal(_goalId);
    if (loaded == null) {
      _state = GoalTreeStateModel(
        goalId: _goalId,
        goalTitle: 'Meta',
        templateId: 'unknown',
        nodes: const [],
        completedIds: <String>{},
        createdAtMs: 0,
      );
    } else {
      _state = loaded;
    }

    _recomputeStatuses();
    notifyListeners();
  }

  Future<void> replaceState(GoalTreeStateModel state) async {
    _state = state;
    _recomputeStatuses();
    notifyListeners();
    await _repo.saveGoal(state);
  }

  Future<void> resetProgress() async {
    final s = state;
    final next = GoalTreeStateModel(
      goalId: s.goalId,
      goalTitle: s.goalTitle,
      templateId: s.templateId,
      nodes: s.nodes,
      completedIds: <String>{},
      createdAtMs: s.createdAtMs,
    );
    await replaceState(next);
  }

  bool complete(String nodeId) {
    final st = _status[nodeId] ?? GoalNodeStatus.locked;
    if (st != GoalNodeStatus.available) return false;

    final s = state;
    final next = GoalTreeStateModel(
      goalId: s.goalId,
      goalTitle: s.goalTitle,
      templateId: s.templateId,
      nodes: s.nodes,
      completedIds: {...s.completedIds, nodeId},
      createdAtMs: s.createdAtMs,
    );
    _state = next;
    _recomputeStatuses();
    notifyListeners();
    _repo.saveGoal(next);
    return true;
  }

  List<GoalNodeModel> missingParents(String nodeId) {
    final node = state.nodes
        .where((n) => n.id == nodeId)
        .cast<GoalNodeModel?>()
        .firstWhere((e) => e != null, orElse: () => null);
    if (node == null) return const [];

    final done = state.completedIds;
    final missing = node.parents.where((p) => !done.contains(p)).toSet();
    return state.nodes.where((n) => missing.contains(n.id)).toList();
  }

  void _recomputeStatuses() {
    _status.clear();
    final s = state;

    for (final n in s.nodes) {
      if (s.completedIds.contains(n.id)) {
        _status[n.id] = GoalNodeStatus.completed;
        continue;
      }
      if (n.parents.isEmpty) {
        _status[n.id] = GoalNodeStatus.available;
        continue;
      }
      final ok = n.parents.every(s.completedIds.contains);
      _status[n.id] = ok ? GoalNodeStatus.available : GoalNodeStatus.locked;
    }
  }
}
