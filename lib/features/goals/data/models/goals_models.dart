// ============================================================================
// FILE: lib/features/goals/data/models/goals_models.dart
//
// O que este arquivo faz:
// - Define os modelos novos da central de metas/objetivos
// - Troca a ideia de árvore fixa por um sistema mais útil para vida real:
//   captura livre -> marcos -> próximas ações -> progresso
// - Mantém tudo serializável para Hive
// ============================================================================

import 'package:flutter/foundation.dart';

enum GoalKind { objective, project, problem, habit }

enum GoalStatus { active, paused, completed, archived }

enum GoalArea {
  pessoal,
  casa,
  trabalho,
  empresa,
  estudo,
  saude,
  financas,
  relacionamento,
  outro,
}

@immutable
class GoalActionModel {
  const GoalActionModel({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAtMs,
    this.dayKey,
  });

  final String id;
  final String title;
  final bool isDone;
  final int createdAtMs;
  final String? dayKey;

  GoalActionModel copyWith({
    String? id,
    String? title,
    bool? isDone,
    int? createdAtMs,
    String? dayKey,
  }) {
    return GoalActionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      dayKey: dayKey ?? this.dayKey,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'createdAtMs': createdAtMs,
    'dayKey': dayKey,
  };

  static GoalActionModel fromMap(Map<String, dynamic> map) {
    return GoalActionModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isDone: map['isDone'] == true,
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      dayKey: map['dayKey'] as String?,
    );
  }
}

@immutable
class GoalMilestoneModel {
  const GoalMilestoneModel({
    required this.id,
    required this.title,
    required this.description,
    required this.order,
    required this.isDone,
    required this.actions,
  });

  final String id;
  final String title;
  final String description;
  final int order;
  final bool isDone;
  final List<GoalActionModel> actions;

  GoalMilestoneModel copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    bool? isDone,
    List<GoalActionModel>? actions,
  }) {
    return GoalMilestoneModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      isDone: isDone ?? this.isDone,
      actions: actions ?? this.actions,
    );
  }

  int get totalActions => actions.length;
  int get doneActions => actions.where((item) => item.isDone).length;
  double get progress =>
      actions.isEmpty ? (isDone ? 1 : 0) : doneActions / actions.length;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'order': order,
    'isDone': isDone,
    'actions': actions.map((item) => item.toMap()).toList(),
  };

  static GoalMilestoneModel fromMap(Map<String, dynamic> map) {
    final raw = (map['actions'] as List?) ?? const [];
    return GoalMilestoneModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      isDone: map['isDone'] == true,
      actions: raw
          .whereType<Map>()
          .map(
            (item) => GoalActionModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

@immutable
class GoalPlanModel {
  const GoalPlanModel({
    required this.id,
    required this.title,
    required this.captureText,
    required this.kind,
    required this.area,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.milestones,
    this.whyItMatters = '',
    this.currentStageLabel = '',
    this.targetDateMs,
  });

  final String id;
  final String title;
  final String captureText;
  final GoalKind kind;
  final GoalArea area;
  final GoalStatus status;
  final int createdAtMs;
  final int updatedAtMs;
  final List<GoalMilestoneModel> milestones;
  final String whyItMatters;
  final String currentStageLabel;
  final int? targetDateMs;

  GoalPlanModel copyWith({
    String? id,
    String? title,
    String? captureText,
    GoalKind? kind,
    GoalArea? area,
    GoalStatus? status,
    int? createdAtMs,
    int? updatedAtMs,
    List<GoalMilestoneModel>? milestones,
    String? whyItMatters,
    String? currentStageLabel,
    int? targetDateMs,
  }) {
    return GoalPlanModel(
      id: id ?? this.id,
      title: title ?? this.title,
      captureText: captureText ?? this.captureText,
      kind: kind ?? this.kind,
      area: area ?? this.area,
      status: status ?? this.status,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      milestones: milestones ?? this.milestones,
      whyItMatters: whyItMatters ?? this.whyItMatters,
      currentStageLabel: currentStageLabel ?? this.currentStageLabel,
      targetDateMs: targetDateMs ?? this.targetDateMs,
    );
  }

  int get totalMilestones => milestones.length;
  int get doneMilestones => milestones.where((item) => item.isDone).length;
  int get totalActions =>
      milestones.fold<int>(0, (sum, item) => sum + item.totalActions);
  int get doneActions =>
      milestones.fold<int>(0, (sum, item) => sum + item.doneActions);

  double get progress {
    if (milestones.isEmpty) return 0;
    if (totalActions > 0) {
      return doneActions / totalActions;
    }
    return doneMilestones / milestones.length;
  }

  GoalMilestoneModel? get currentMilestone {
    for (final item in milestones) {
      if (!item.isDone) return item;
    }
    return milestones.isEmpty ? null : milestones.last;
  }

  GoalActionModel? get nextAction {
    for (final milestone in milestones) {
      for (final action in milestone.actions) {
        if (!action.isDone) return action;
      }
    }
    return null;
  }

  bool get isCompleted =>
      status == GoalStatus.completed ||
      (milestones.isNotEmpty && milestones.every((item) => item.isDone));

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'captureText': captureText,
    'kind': kind.name,
    'area': area.name,
    'status': status.name,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'whyItMatters': whyItMatters,
    'currentStageLabel': currentStageLabel,
    'targetDateMs': targetDateMs,
    'milestones': milestones.map((item) => item.toMap()).toList(),
  };

  static GoalPlanModel fromMap(Map<String, dynamic> map) {
    final raw = (map['milestones'] as List?) ?? const [];
    return GoalPlanModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Nova meta',
      captureText: map['captureText'] as String? ?? '',
      kind: GoalKind.values.firstWhere(
        (item) => item.name == (map['kind'] as String? ?? ''),
        orElse: () => GoalKind.objective,
      ),
      area: GoalArea.values.firstWhere(
        (item) => item.name == (map['area'] as String? ?? ''),
        orElse: () => GoalArea.outro,
      ),
      status: GoalStatus.values.firstWhere(
        (item) => item.name == (map['status'] as String? ?? ''),
        orElse: () => GoalStatus.active,
      ),
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt() ?? 0,
      whyItMatters: map['whyItMatters'] as String? ?? '',
      currentStageLabel: map['currentStageLabel'] as String? ?? '',
      targetDateMs: (map['targetDateMs'] as num?)?.toInt(),
      milestones: raw
          .whereType<Map>()
          .map(
            (item) =>
                GoalMilestoneModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

@immutable
class GoalSummaryModel {
  const GoalSummaryModel({
    required this.id,
    required this.title,
    required this.kind,
    required this.area,
    required this.status,
    required this.updatedAtMs,
    required this.progress,
    required this.currentStageLabel,
    required this.nextActionTitle,
  });

  final String id;
  final String title;
  final GoalKind kind;
  final GoalArea area;
  final GoalStatus status;
  final int updatedAtMs;
  final double progress;
  final String currentStageLabel;
  final String nextActionTitle;

  factory GoalSummaryModel.fromPlan(GoalPlanModel plan) {
    return GoalSummaryModel(
      id: plan.id,
      title: plan.title,
      kind: plan.kind,
      area: plan.area,
      status: plan.isCompleted ? GoalStatus.completed : plan.status,
      updatedAtMs: plan.updatedAtMs,
      progress: plan.progress,
      currentStageLabel: plan.currentMilestone?.title.isNotEmpty == true
          ? plan.currentMilestone!.title
          : (plan.currentStageLabel.isNotEmpty
                ? plan.currentStageLabel
                : 'Sem etapa'),
      nextActionTitle: plan.nextAction?.title ?? 'Sem próxima ação',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'area': area.name,
    'status': status.name,
    'updatedAtMs': updatedAtMs,
    'progress': progress,
    'currentStageLabel': currentStageLabel,
    'nextActionTitle': nextActionTitle,
  };

  static GoalSummaryModel fromMap(Map<String, dynamic> map) {
    return GoalSummaryModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Nova meta',
      kind: GoalKind.values.firstWhere(
        (item) => item.name == (map['kind'] as String? ?? ''),
        orElse: () => GoalKind.objective,
      ),
      area: GoalArea.values.firstWhere(
        (item) => item.name == (map['area'] as String? ?? ''),
        orElse: () => GoalArea.outro,
      ),
      status: GoalStatus.values.firstWhere(
        (item) => item.name == (map['status'] as String? ?? ''),
        orElse: () => GoalStatus.active,
      ),
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt() ?? 0,
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      currentStageLabel: map['currentStageLabel'] as String? ?? 'Sem etapa',
      nextActionTitle: map['nextActionTitle'] as String? ?? 'Sem próxima ação',
    );
  }
}
