// lib/features/goals/data/models/goal_tree_models.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum GoalNodeStatus { locked, available, completed }

@immutable
class GoalNodeModel {
  const GoalNodeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.position,
    required this.parents,
    required this.rewardLabel,
  });

  final String id;
  final String title;
  final String description;
  final Offset position;
  final List<String> parents;
  final String rewardLabel;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'x': position.dx,
    'y': position.dy,
    'parents': parents,
    'rewardLabel': rewardLabel,
  };

  static GoalNodeModel fromMap(Map<String, dynamic> m) {
    return GoalNodeModel(
      id: m['id'] as String,
      title: m['title'] as String,
      description: m['description'] as String? ?? '',
      position: Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
      parents:
          (m['parents'] as List?)?.whereType<String>().toList() ?? const [],
      rewardLabel: m['rewardLabel'] as String? ?? '',
    );
  }
}

@immutable
class GoalTreeStateModel {
  const GoalTreeStateModel({
    required this.goalId,
    required this.goalTitle,
    required this.templateId,
    required this.nodes,
    required this.completedIds,
    required this.createdAtMs,
  });

  final String goalId;
  final String goalTitle;
  final String templateId;
  final List<GoalNodeModel> nodes;
  final Set<String> completedIds;
  final int createdAtMs;

  Map<String, dynamic> toMap() => {
    'goalId': goalId,
    'goalTitle': goalTitle,
    'templateId': templateId,
    'createdAtMs': createdAtMs,
    'completedIds': completedIds.toList(),
    'nodes': nodes.map((e) => e.toMap()).toList(),
  };

  static GoalTreeStateModel fromMap(Map<String, dynamic> m) {
    final nodesRaw = (m['nodes'] as List?) ?? const [];
    return GoalTreeStateModel(
      goalId: m['goalId'] as String,
      goalTitle: m['goalTitle'] as String? ?? 'Meta',
      templateId: m['templateId'] as String? ?? 'unknown',
      createdAtMs: (m['createdAtMs'] as num?)?.toInt() ?? 0,
      completedIds: ((m['completedIds'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
      nodes: nodesRaw
          .whereType<Map>()
          .map((e) => GoalNodeModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

@immutable
class GoalSummaryModel {
  const GoalSummaryModel({
    required this.goalId,
    required this.goalTitle,
    required this.templateId,
    required this.createdAtMs,
  });

  final String goalId;
  final String goalTitle;
  final String templateId;
  final int createdAtMs;

  Map<String, dynamic> toMap() => {
    'goalId': goalId,
    'goalTitle': goalTitle,
    'templateId': templateId,
    'createdAtMs': createdAtMs,
  };

  static GoalSummaryModel fromMap(Map<String, dynamic> m) {
    return GoalSummaryModel(
      goalId: m['goalId'] as String,
      goalTitle: m['goalTitle'] as String? ?? 'Meta',
      templateId: m['templateId'] as String? ?? 'unknown',
      createdAtMs: (m['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
