// ============================================================================
// FILE: lib/data/models/area_assessment.dart
//
// O que faz:
// - Representa uma avaliação de subárea/área
// - Salva e lê status, score, motivo, fonte e metadados
//
// Nesta versão:
// - remove leitura legada de status
// - usa somente os nomes do sistema novo em storage
// ============================================================================

import 'area_data_source.dart';
import 'area_status.dart';

class AreaAssessment {
  const AreaAssessment({
    required this.status,
    this.score,
    this.reason,
    this.source = AreaDataSource.unknown,
    this.lastUpdatedAt,
    this.recommendedAction,
    this.details,
  });

  final AreaStatus status;
  final int? score;
  final String? reason;
  final AreaDataSource source;
  final DateTime? lastUpdatedAt;
  final String? recommendedAction;
  final String? details;

  bool get hasScore => score != null;
  bool get hasReason => (reason ?? '').trim().isNotEmpty;
  bool get hasRecommendedAction => (recommendedAction ?? '').trim().isNotEmpty;

  AreaAssessment copyWith({
    AreaStatus? status,
    int? score,
    bool clearScore = false,
    String? reason,
    bool clearReason = false,
    AreaDataSource? source,
    DateTime? lastUpdatedAt,
    bool clearLastUpdatedAt = false,
    String? recommendedAction,
    bool clearRecommendedAction = false,
    String? details,
    bool clearDetails = false,
  }) {
    return AreaAssessment(
      status: status ?? this.status,
      score: clearScore ? null : (score ?? this.score),
      reason: clearReason ? null : (reason ?? this.reason),
      source: source ?? this.source,
      lastUpdatedAt: clearLastUpdatedAt
          ? null
          : (lastUpdatedAt ?? this.lastUpdatedAt),
      recommendedAction: clearRecommendedAction
          ? null
          : (recommendedAction ?? this.recommendedAction),
      details: clearDetails ? null : (details ?? this.details),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.storageName,
      'score': score,
      'reason': reason,
      'source': source.storageName,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
      'recommendedAction': recommendedAction,
      'details': details,
    };
  }

  static AreaAssessment fromMap(Map map) {
    final rawStatus = map['status']?.toString();
    final rawScore = map['score'];
    final rawSource = map['source']?.toString();
    final rawLastUpdatedAt = map['lastUpdatedAt']?.toString();

    return AreaAssessment(
      status: AreaStatusUi.fromStorageName(rawStatus ?? ''),
      score: rawScore is int ? rawScore : int.tryParse('${rawScore ?? ''}'),
      reason: map['reason'] as String?,
      source: AreaDataSourceUi.fromStorage(rawSource),
      lastUpdatedAt: rawLastUpdatedAt == null || rawLastUpdatedAt.isEmpty
          ? null
          : DateTime.tryParse(rawLastUpdatedAt),
      recommendedAction: map['recommendedAction'] as String?,
      details: map['details'] as String?,
    );
  }
}
