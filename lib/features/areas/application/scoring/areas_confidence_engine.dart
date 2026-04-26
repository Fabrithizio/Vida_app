// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_confidence_engine.dart
//
// O que faz:
// - Centraliza o cálculo de confiabilidade do score
// - Define peso por origem, recência, consistência e completude
// - Evita que cada engine espalhe regras diferentes pelo projeto
//
// Revisão desta versão:
// - pesos de fonte recalibrados para o app real
// - resposta manual estruturada não é mais punida demais
// - onboarding continua sendo base fraca
// - check-in diário continua forte, mas abaixo de automático e misto
// ============================================================================

import 'dart:math' as math;
import 'package:vida_app/data/models/area_data_source.dart';

class ConfidenceBreakdown {
  const ConfidenceBreakdown({
    required this.rawScore,
    required this.sourceWeight,
    required this.recencyWeight,
    required this.consistencyWeight,
    required this.completenessWeight,
    required this.finalScore,
  });

  final int rawScore;
  final double sourceWeight;
  final double recencyWeight;
  final double consistencyWeight;
  final double completenessWeight;
  final int finalScore;
}

class AreasConfidenceEngine {
  const AreasConfidenceEngine();

  double sourceWeight(AreaDataSource source) {
    switch (source) {
      case AreaDataSource.automatic:
        return 1.00;
      case AreaDataSource.mixed:
        return 0.94;
      case AreaDataSource.estimated:
        return 0.82;
      case AreaDataSource.dailyQuestions:
        return 0.78;
      case AreaDataSource.manual:
        return 0.74;
      case AreaDataSource.onboarding:
        return 0.58;
      case AreaDataSource.unknown:
        return 0.62;
    }
  }

  double recencyWeightFromDays(int daysSinceUpdate) {
    if (daysSinceUpdate <= 0) return 1.00;
    if (daysSinceUpdate <= 3) return 0.98;
    if (daysSinceUpdate <= 7) return 0.95;
    if (daysSinceUpdate <= 14) return 0.89;
    if (daysSinceUpdate <= 21) return 0.80;
    if (daysSinceUpdate <= 30) return 0.68;
    if (daysSinceUpdate <= 45) return 0.56;
    return 0.45;
  }

  double normalize01(double? value, {double fallback = 1.0}) {
    if (value == null || value.isNaN || value.isInfinite) return fallback;
    return value.clamp(0.0, 1.0);
  }

  int effectiveScore({
    required int rawScore,
    required AreaDataSource source,
    required int daysSinceUpdate,
    double? consistency01,
    double? completeness01,
  }) {
    final result = breakdown(
      rawScore: rawScore,
      source: source,
      daysSinceUpdate: daysSinceUpdate,
      consistency01: consistency01,
      completeness01: completeness01,
    );
    return result.finalScore;
  }

  ConfidenceBreakdown breakdown({
    required int rawScore,
    required AreaDataSource source,
    required int daysSinceUpdate,
    double? consistency01,
    double? completeness01,
  }) {
    final safeRaw = rawScore.clamp(0, 100);
    final sourceFactor = sourceWeight(source);
    final recencyFactor = recencyWeightFromDays(daysSinceUpdate);
    final consistencyFactor = normalize01(consistency01, fallback: 1.0);
    final completenessFactor = normalize01(completeness01, fallback: 1.0);

    final finalScore =
        (safeRaw *
                sourceFactor *
                recencyFactor *
                consistencyFactor *
                completenessFactor)
            .round()
            .clamp(0, 100);

    return ConfidenceBreakdown(
      rawScore: safeRaw,
      sourceWeight: sourceFactor,
      recencyWeight: recencyFactor,
      consistencyWeight: consistencyFactor,
      completenessWeight: completenessFactor,
      finalScore: finalScore,
    );
  }

  int blendWeightedScores(Map<int, double> weightedScores) {
    if (weightedScores.isEmpty) return 0;

    double totalWeight = 0;
    double weightedSum = 0;

    weightedScores.forEach((score, weight) {
      if (weight <= 0) return;
      weightedSum += score.clamp(0, 100) * weight;
      totalWeight += weight;
    });

    if (totalWeight <= 0) return 0;
    return (weightedSum / totalWeight).round().clamp(0, 100);
  }

  double consistencyFromHistory(List<int> recentScores) {
    if (recentScores.length < 2) return 1.0;

    final valid = recentScores.map((e) => e.clamp(0, 100).toDouble()).toList();
    final avg = valid.reduce((a, b) => a + b) / valid.length;

    double variance = 0;
    for (final score in valid) {
      variance += math.pow(score - avg, 2).toDouble();
    }

    variance = variance / valid.length;
    final normalizedVolatility = (math.sqrt(variance) / 50).clamp(0.0, 1.0);
    return (1 - normalizedVolatility).clamp(0.50, 1.0);
  }

  double completenessFromCounts({
    required int filledCount,
    required int expectedCount,
  }) {
    if (expectedCount <= 0) return 1.0;
    return (filledCount / expectedCount).clamp(0.0, 1.0);
  }
}
