// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_daily_questions_engine.dart
//
// O que faz:
// - Lê o histórico do check-in diário
// - Transforma respostas em score 0..100 para subáreas do Areas
// - Permite impacto cruzado de uma pergunta em várias subáreas
// - Aplica persistência com decaimento quando o usuário some
//
// Revisão desta versão:
// - integra AreasConfidenceEngine
// - usa consistência do histórico e completude da janela
// - mantém o decaimento aprovado após 14 dias sem atualização
// ============================================================================

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_confidence_engine.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';

class AreasDailyQuestionsEngine {
  AreasDailyQuestionsEngine({
    DailyCheckinService? dailyCheckinService,
    AreasConfidenceEngine? confidenceEngine,
  }) : _dailyCheckinService = dailyCheckinService ?? DailyCheckinService(),
       _confidence = confidenceEngine ?? const AreasConfidenceEngine();

  final DailyCheckinService _dailyCheckinService;
  final AreasConfidenceEngine _confidence;

  static const int staleStartsAfterDays = 14;
  static const double dailyDecayRate = 0.05;

  Future<AreaAssessment?> computedDailyQuestionItem(
    String areaId,
    String itemId, {
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    if (_shouldSkipGenericDaily(areaId, itemId)) {
      return null;
    }

    final history = await readImpactedHistory(
      areaId: areaId,
      itemId: itemId,
      day: DateTime.now(),
      days: DailyCheckinService.historyDays,
    );

    if (history.isEmpty) return null;

    final rawScore = weightedScaledHistoryScore(history);
    final decayedScore = applyDecayIfNeeded(
      score: rawScore,
      lastUpdatedAt: history.first.date,
      now: DateTime.now(),
    );

    if (decayedScore <= 0) {
      return null;
    }

    final lastAnsweredAt = history.first.date;
    final daysSinceLast = DateTime.now().difference(lastAnsweredAt).inDays;
    final consistency01 = _confidence.consistencyFromHistory(
      history.map((e) => e.value.round()).toList(),
    );
    final completeness01 = _confidence.completenessFromCounts(
      filledCount: history.length,
      expectedCount: DailyCheckinService.historyDays,
    );
    final source = _isEstimatedTarget(areaId, itemId)
        ? AreaDataSource.estimated
        : AreaDataSource.dailyQuestions;
    final confidenceAdjusted = _confidence.effectiveScore(
      rawScore: decayedScore,
      source: source,
      daysSinceUpdate: daysSinceLast,
      consistency01: consistency01,
      completeness01: completeness01,
    );

    if (confidenceAdjusted <= 0) return null;

    final status = _statusFromNumericScore(confidenceAdjusted);
    final trend = trendFromScaledHistory(history);
    final latestValue = history.first.value;
    final averageValue =
        history.map((e) => e.value).reduce((a, b) => a + b) / history.length;

    if (onAreaUpdated != null) {
      await onAreaUpdated(areaId);
    }

    final copy = _copyFor(areaId, itemId);
    final positive = latestValue >= 65;
    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };
    final staleSentence = daysSinceLast <= 0
        ? 'Último registro: hoje.'
        : daysSinceLast == 1
        ? 'Último registro: ontem.'
        : 'Último registro: há $daysSinceLast dias.';
    final decaySentence = daysSinceLast > staleStartsAfterDays
        ? 'O score entrou em decaimento por falta de atualização.'
        : 'O score ainda está dentro da janela ativa de atualização.';

    return AreaAssessment(
      status: status,
      score: confidenceAdjusted,
      reason: positive ? copy.positiveReason : copy.negativeReason,
      source: source,
      lastUpdatedAt: lastAnsweredAt,
      recommendedAction: positive ? copy.positiveAction : copy.negativeAction,
      details:
          '${copy.details}\n\n'
          'Histórico usado: ${history.length} registros nos últimos '
          '${DailyCheckinService.historyDays} dias. Média recente: '
          '${averageValue.toStringAsFixed(0)}/100. Score bruto: '
          '$rawScore/100. Score após decaimento: $decayedScore/100. '
          'Score final com confiança: $confidenceAdjusted/100. '
          'Consistência: ${(consistency01 * 100).toStringAsFixed(0)}%. '
          'Completude: ${(completeness01 * 100).toStringAsFixed(0)}%. '
          '$trendSentence $staleSentence $decaySentence',
    );
  }

  bool _shouldSkipGenericDaily(String areaId, String itemId) {
    if (areaId == 'finance_material') return true;
    if (areaId == 'environment_home') return true;
    if (areaId == 'body_health') return true;
    if (areaId == 'digital_tech') return true;
    return false;
  }

  bool _isEstimatedTarget(String areaId, String itemId) {
    final key = '$areaId.$itemId';
    return const {
      'work_vocation.balance',
      'learning_intellect.planning',
      'learning_intellect.execution',
      'learning_intellect.consistency',
      'learning_intellect.progress',
      'relations_community.family',
      'relations_community.friends',
      'relations_community.partner',
      'purpose_values.direction',
      'purpose_values.goals_review',
      'purpose_values.gratitude',
      'purpose_values.self_control',
    }.contains(key);
  }

  Future<AreaAssessment?> assessmentFromDailyQuestions({
    required String areaId,
    required DateTime day,
    required List<String> questionIds,
    required String positiveReason,
    required String negativeReason,
    required String positiveAction,
    required String negativeAction,
    required String details,
    bool estimated = false,
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    final history = await readDailyScaledHistory(
      day: day,
      questionIds: questionIds,
      days: DailyCheckinService.historyDays,
    );

    if (history.isEmpty) return null;

    final rawScore = weightedScaledHistoryScore(history);
    final decayedScore = applyDecayIfNeeded(
      score: rawScore,
      lastUpdatedAt: history.first.date,
      now: day,
    );

    if (decayedScore <= 0) {
      return null;
    }

    final lastAnsweredAt = history.first.date;
    final daysSinceLast = day.difference(lastAnsweredAt).inDays;
    final source = estimated
        ? AreaDataSource.estimated
        : AreaDataSource.dailyQuestions;
    final consistency01 = _confidence.consistencyFromHistory(
      history.map((e) => e.value.round()).toList(),
    );
    final completeness01 = _confidence.completenessFromCounts(
      filledCount: history.length,
      expectedCount: DailyCheckinService.historyDays,
    );
    final finalScore = _confidence.effectiveScore(
      rawScore: decayedScore,
      source: source,
      daysSinceUpdate: daysSinceLast,
      consistency01: consistency01,
      completeness01: completeness01,
    );

    if (finalScore <= 0) return null;

    final status = _statusFromNumericScore(finalScore);
    final trend = trendFromScaledHistory(history);
    final total = history.length;
    final latestValue = history.first.value;
    final averageValue =
        history.map((e) => e.value).reduce((a, b) => a + b) / total;

    if (onAreaUpdated != null) {
      await onAreaUpdated(areaId);
    }

    final positive = latestValue >= 65;
    final reason = positive ? positiveReason : negativeReason;
    final action = positive ? positiveAction : negativeAction;

    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };

    final staleSentence = daysSinceLast <= 0
        ? 'Último registro: hoje.'
        : daysSinceLast == 1
        ? 'Último registro: ontem.'
        : 'Último registro: há $daysSinceLast dias.';
    final decaySentence = daysSinceLast > staleStartsAfterDays
        ? 'O score entrou em decaimento por falta de atualização.'
        : 'O score ainda está dentro da janela ativa de atualização.';

    return AreaAssessment(
      status: status,
      score: finalScore,
      reason: reason,
      source: source,
      lastUpdatedAt: lastAnsweredAt,
      recommendedAction: action,
      details:
          '$details\n\n'
          'Histórico usado: $total registros nos últimos '
          '${DailyCheckinService.historyDays} dias. Média recente: '
          '${averageValue.toStringAsFixed(0)}/100. Score bruto: '
          '$rawScore/100. Score após decaimento: $decayedScore/100. '
          'Score final com confiança: $finalScore/100. '
          'Consistência: ${(consistency01 * 100).toStringAsFixed(0)}%. '
          'Completude: ${(completeness01 * 100).toStringAsFixed(0)}%. '
          '$trendSentence $staleSentence $decaySentence',
    );
  }

  Future<List<DailyScaledPoint>> readImpactedHistory({
    required String areaId,
    required String itemId,
    required DateTime day,
    required int days,
  }) async {
    final questions = _dailyCheckinService.questionsForTarget(areaId, itemId);
    if (questions.isEmpty) return const [];

    final points = <DailyScaledPoint>[];

    for (var offset = 0; offset < days; offset++) {
      final date = day.subtract(Duration(days: offset));
      double weightedSum = 0;
      double totalWeight = 0;

      for (final question in questions) {
        final stored = await _dailyCheckinService.getAnswer(
          day: date,
          questionId: question.id,
        );
        if (stored == null) continue;

        final normalized = _dailyCheckinService.normalizedProgress01(
          questionId: question.id,
          rawValue: stored,
        );
        final weight = question.impactWeightFor(areaId, itemId);
        if (weight <= 0) continue;

        weightedSum += (normalized * 100.0) * weight;
        totalWeight += weight;
      }

      if (totalWeight <= 0) continue;
      points.add(
        DailyScaledPoint(date: date, value: weightedSum / totalWeight),
      );
    }

    return points;
  }

  Future<List<DailyScaledPoint>> readDailyScaledHistory({
    required DateTime day,
    required List<String> questionIds,
    required int days,
  }) async {
    final points = <DailyScaledPoint>[];

    for (var offset = 0; offset < days; offset++) {
      final date = day.subtract(Duration(days: offset));
      final values = <double>[];

      for (final questionId in questionIds) {
        final stored = await _dailyCheckinService.getAnswer(
          day: date,
          questionId: questionId,
        );
        if (stored == null) continue;

        values.add(
          _dailyCheckinService.normalizedProgress01(
                questionId: questionId,
                rawValue: stored,
              ) *
              100.0,
        );
      }

      if (values.isEmpty) continue;

      final avg = values.reduce((a, b) => a + b) / values.length;
      points.add(DailyScaledPoint(date: date, value: avg));
    }

    return points;
  }

  int weightedScaledHistoryScore(List<DailyScaledPoint> history) {
    if (history.isEmpty) return 0;

    double weightedSum = 0;
    double weightSum = 0;

    for (var index = 0; index < history.length; index++) {
      final point = history[index];
      final weight = 1.0 - (index * 0.045);
      final safeWeight = weight < 0.35 ? 0.35 : weight;

      weightedSum += point.value * safeWeight;
      weightSum += safeWeight;
    }

    var score = weightSum == 0 ? 0 : (weightedSum / weightSum);
    if (history.length < 3) {
      score -= (3 - history.length) * 6;
    }
    return score.round().clamp(0, 100);
  }

  int applyDecayIfNeeded({
    required int score,
    required DateTime lastUpdatedAt,
    required DateTime now,
  }) {
    final daysSinceLast = now.difference(lastUpdatedAt).inDays;
    if (daysSinceLast <= staleStartsAfterDays) {
      return score.clamp(0, 100);
    }

    final overdueDays = daysSinceLast - staleStartsAfterDays;
    final factor = 1.0 - (overdueDays * dailyDecayRate);
    if (factor <= 0) return 0;

    return (score * factor).round().clamp(0, 100);
  }

  String trendFromScaledHistory(List<DailyScaledPoint> history) {
    if (history.length < 4) return 'stable';

    final recent = history.where((p) {
      final gap = DateTime.now().difference(p.date).inDays;
      return gap <= 6;
    }).toList();

    final previous = history.where((p) {
      final gap = DateTime.now().difference(p.date).inDays;
      return gap >= 7 && gap <= 13;
    }).toList();

    if (recent.isEmpty || previous.isEmpty) return 'stable';

    final recentAvg =
        recent.map((e) => e.value).reduce((a, b) => a + b) / recent.length;
    final previousAvg =
        previous.map((e) => e.value).reduce((a, b) => a + b) / previous.length;

    final delta = recentAvg - previousAvg;

    if (delta >= 8) return 'improving';
    if (delta <= -8) return 'worsening';
    return 'stable';
  }

  Future<String?> trendLabelForQuestions(List<String> questionIds) async {
    final history = await readDailyScaledHistory(
      day: DateTime.now(),
      questionIds: questionIds,
      days: DailyCheckinService.historyDays,
    );

    if (history.length < 4) return null;

    final trend = trendFromScaledHistory(history);
    switch (trend) {
      case 'improving':
        return '📈 Melhorando';
      case 'worsening':
        return '📉 Piorando';
      default:
        return '➖ Estável';
    }
  }

  Future<String?> trendLabelForItem(String areaId, String itemId) async {
    final history = await readImpactedHistory(
      areaId: areaId,
      itemId: itemId,
      day: DateTime.now(),
      days: DailyCheckinService.historyDays,
    );

    if (history.length < 4) return null;
    final trend = trendFromScaledHistory(history);
    switch (trend) {
      case 'improving':
        return '📈 Melhorando';
      case 'worsening':
        return '📉 Piorando';
      default:
        return '➖ Estável';
    }
  }

  AreaStatus _statusFromNumericScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }

  _DailyItemCopy _copyFor(String areaId, String itemId) {
    final key = '$areaId.$itemId';
    return _copy[key] ??
        _DailyItemCopy(
          label: 'essa subárea',
          positiveReason: 'Seus sinais recentes dessa subárea estão bons.',
          negativeReason: 'Seus sinais recentes dessa subárea pedem atenção.',
          positiveAction: 'Continue protegendo esse padrão.',
          negativeAction: 'Vale reforçar o básico dessa subárea.',
          details: 'Calculado pelas respostas recentes do check-in diário.',
        );
  }

  static const Map<String, _DailyItemCopy> _copy = {
    'mind_emotion.mood': _DailyItemCopy(
      label: 'humor',
      positiveReason: 'Seu humor recente parece mais equilibrado.',
      negativeReason: 'Seu humor recente mostra oscilação ou queda.',
      positiveAction: 'Continue protegendo o que tem feito bem para você.',
      negativeAction:
          'Vale observar o que tem te drenado e reforçar recuperação.',
      details:
          'Calculado pelas respostas recentes ligadas a humor, apoio, convivência e recuperação.',
    ),
    'mind_emotion.stress': _DailyItemCopy(
      label: 'estresse',
      positiveReason: 'Seu estresse recente parece mais controlado.',
      negativeReason: 'Seu estresse recente está acima do ideal.',
      positiveAction: 'Continue preservando limites e respiros.',
      negativeAction: 'Vale aliviar pressão e simplificar o dia quando der.',
      details:
          'Calculado pelas respostas recentes ligadas a pressão mental, dinheiro e sobrecarga.',
    ),
    'mind_emotion.focus': _DailyItemCopy(
      label: 'foco',
      positiveReason: 'Seu foco recente está em bom nível.',
      negativeReason: 'Seu foco recente ficou abaixo do ideal.',
      positiveAction: 'Continue repetindo as condições que favorecem seu foco.',
      negativeAction: 'Vale reduzir distrações e clarear prioridades.',
      details:
          'Calculado pelas respostas recentes ligadas a clareza mental, distrações e eixo do dia.',
    ),
    'mind_emotion.mental_load': _DailyItemCopy(
      label: 'sobrecarga mental',
      positiveReason: 'Sua carga mental recente parece mais leve e controlada.',
      negativeReason: 'Sua carga mental recente parece pesada.',
      positiveAction: 'Continue preservando pausas, limites e recuperação.',
      negativeAction: 'Vale reduzir peso desnecessário e criar mais respiros.',
      details:
          'Calculado pelas respostas recentes ligadas a pressão, casa, apoio e recuperação.',
    ),
  };
}

class DailyScaledPoint {
  const DailyScaledPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class _DailyItemCopy {
  const _DailyItemCopy({
    required this.label,
    required this.positiveReason,
    required this.negativeReason,
    required this.positiveAction,
    required this.negativeAction,
    required this.details,
  });

  final String label;
  final String positiveReason;
  final String negativeReason;
  final String positiveAction;
  final String negativeAction;
  final String details;
}
