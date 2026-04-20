// ============================================================================
// FILE: lib/data/models/life_alert.dart
//
// O que este arquivo faz:
// - Centraliza os tipos e prioridades do centro de alertas do app
// - Permite marcar alertas como lidos
// - Suporta alertas do radar, corpo em dia, jornada, finanças e metas
// ============================================================================

import 'package:flutter/foundation.dart';

enum LifeAlertPriority { low, medium, high, critical }

enum LifeAlertType {
  overdueCheckup,
  staleArea,
  badCheckinStreak,
  budgetExceeded,
  highSpendingMonth,
  upcomingTimelineEvent,
  overdueTimelineEvent,
  alwaysOnRelevant,
  bodyCarePending,
  goalMomentum,
  lifeJourneyUnlocked,
  genericUnlock,
}

@immutable
class LifeAlert {
  const LifeAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
    required this.createdAt,
    this.areaId,
    this.relatedId,
    this.isRead = false,
    this.actionLabel,
    this.routeHint,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final LifeAlertType type;
  final String title;
  final String message;
  final LifeAlertPriority priority;
  final DateTime createdAt;
  final String? areaId;
  final String? relatedId;
  final bool isRead;
  final String? actionLabel;
  final String? routeHint;
  final Map<String, dynamic> metadata;

  LifeAlert copyWith({
    String? id,
    LifeAlertType? type,
    String? title,
    String? message,
    LifeAlertPriority? priority,
    DateTime? createdAt,
    String? areaId,
    String? relatedId,
    bool? isRead,
    String? actionLabel,
    String? routeHint,
    Map<String, dynamic>? metadata,
  }) {
    return LifeAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      areaId: areaId ?? this.areaId,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      actionLabel: actionLabel ?? this.actionLabel,
      routeHint: routeHint ?? this.routeHint,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'priority': priority.name,
    'createdAt': createdAt.toIso8601String(),
    'areaId': areaId,
    'relatedId': relatedId,
    'isRead': isRead,
    'actionLabel': actionLabel,
    'routeHint': routeHint,
    'metadata': metadata,
  };

  static LifeAlert fromMap(Map<String, dynamic> map) {
    return LifeAlert(
      id: map['id'] as String? ?? '',
      type: LifeAlertType.values.firstWhere(
        (item) => item.name == (map['type'] as String? ?? ''),
        orElse: () => LifeAlertType.genericUnlock,
      ),
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      priority: LifeAlertPriority.values.firstWhere(
        (item) => item.name == (map['priority'] as String? ?? ''),
        orElse: () => LifeAlertPriority.low,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      areaId: map['areaId'] as String?,
      relatedId: map['relatedId'] as String?,
      isRead: map['isRead'] == true,
      actionLabel: map['actionLabel'] as String?,
      routeHint: map['routeHint'] as String?,
      metadata: Map<String, dynamic>.from(
        (map['metadata'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  static int comparePriority(LifeAlertPriority value) {
    switch (value) {
      case LifeAlertPriority.critical:
        return 4;
      case LifeAlertPriority.high:
        return 3;
      case LifeAlertPriority.medium:
        return 2;
      case LifeAlertPriority.low:
        return 1;
    }
  }
}
