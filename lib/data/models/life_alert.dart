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
