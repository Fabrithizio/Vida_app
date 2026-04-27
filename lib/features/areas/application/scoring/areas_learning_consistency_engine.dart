// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_learning_consistency_engine.dart
//
// O que faz:
// - Lê o snapshot persistido da constância do Meu Dia
// - Traduz streak, ritmo recente e proteções para a subárea
//   Projetos & Progresso > Constância
// - Evita deixar essa subárea cinza quando o app já tem sinais reais
//
// Lógica desta versão:
// - taxa dos últimos 14 dias pesa mais
// - taxa dos últimos 30 dias estabiliza a leitura
// - sequência atual empurra consistência real
// - dias fortes recentes dão bônus
// - proteções ajudam pouco, sem inflar demais
// ============================================================================

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/timeline/application/day_consistency_service.dart';

class AreasLearningConsistencyEngine {
  AreasLearningConsistencyEngine({DayConsistencyService? dayConsistency})
    : _dayConsistency = dayConsistency;

  final DayConsistencyService? _dayConsistency;

  Future<AreaAssessment> computedConsistency({
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    final snapshot = await _resolveSnapshot();
    final score = _scoreFromSnapshot(snapshot);

    if (onAreaUpdated != null) {
      await onAreaUpdated('learning_intellect');
    }

    return AreaAssessment(
      status: _statusFromScore(score),
      score: score,
      reason: _reason(snapshot),
      source: AreaDataSource.estimated,
      lastUpdatedAt: DateTime.now(),
      recommendedAction:
          'Manter check-in, Corpo em Dia e blocos concluídos no Meu Dia fortalece essa leitura.',
      details: _details(snapshot),
    );
  }

  AreaStatus _statusFromScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }

  Future<DayConsistencySnapshot> _resolveSnapshot() async {
    if (_dayConsistency != null) {
      var snapshot = await _dayConsistency!.readSnapshot();
      if (snapshot != null) return snapshot;

      final summary = await _dayConsistency!.summaryAndPersist();
      snapshot = await _dayConsistency!.readSnapshot();
      if (snapshot != null) return snapshot;

      return DayConsistencySnapshot(
        currentStreak: summary.currentStreak,
        bestStreak: summary.bestStreak,
        availableProtections: summary.availableProtections,
        strongDays14: summary.strongDays14,
        goodDays14: summary.goodDays14,
        activeDays14: summary.activeDays14,
        goodRate14: summary.goodRate14,
        goodRate30: summary.goodRate30,
        updatedAt: DateTime.now(),
      );
    }

    return DayConsistencySnapshot(
      currentStreak: 0,
      bestStreak: 0,
      availableProtections: 0,
      strongDays14: 0,
      goodDays14: 0,
      activeDays14: 0,
      goodRate14: 0,
      goodRate30: 0,
      updatedAt: DateTime.now(),
    );
  }

  int _scoreFromSnapshot(DayConsistencySnapshot snapshot) {
    final streakFactor = (snapshot.currentStreak.clamp(0, 30) / 30.0) * 22.0;
    final bestFactor = (snapshot.bestStreak.clamp(0, 60) / 60.0) * 8.0;
    final rate14Factor = snapshot.goodRate14.clamp(0.0, 1.0) * 36.0;
    final rate30Factor = snapshot.goodRate30.clamp(0.0, 1.0) * 20.0;
    final strongFactor = (snapshot.strongDays14.clamp(0, 7) / 7.0) * 10.0;
    final activeFactor = (snapshot.activeDays14.clamp(0, 14) / 14.0) * 2.0;
    final protectionFactor = snapshot.availableProtections.clamp(0, 2) * 1.0;

    final total =
        streakFactor +
        bestFactor +
        rate14Factor +
        rate30Factor +
        strongFactor +
        activeFactor +
        protectionFactor;

    return total.round().clamp(0, 100);
  }

  String _reason(DayConsistencySnapshot snapshot) {
    if (snapshot.currentStreak >= 21 && snapshot.goodRate14 >= 0.75) {
      return 'Você está num ritmo muito consistente, com sequência forte e boa densidade recente.';
    }
    if (snapshot.currentStreak >= 7 && snapshot.goodRate14 >= 0.50) {
      return 'Sua constância recente está boa e o app já enxerga repetição real de avanço.';
    }
    if (snapshot.goodRate14 >= 0.35 || snapshot.activeDays14 >= 6) {
      return 'Você já está gerando sinais úteis de constância, mas ainda com oscilações.';
    }
    if (snapshot.activeDays14 > 0) {
      return 'O app já vê movimento, mas ainda pouca repetição forte para chamar de constância.';
    }
    return 'Ainda há pouco ritmo recente registrado no Meu Dia para sustentar essa subárea.';
  }

  String _details(DayConsistencySnapshot snapshot) {
    return 'Sequência atual: ${snapshot.currentStreak} dias • '
        'Recorde: ${snapshot.bestStreak} dias • '
        'Proteções: ${snapshot.availableProtections} • '
        'Ritmo 14d: ${(snapshot.goodRate14 * 100).round()}% • '
        'Ritmo 30d: ${(snapshot.goodRate30 * 100).round()}% • '
        'Dias fortes 14d: ${snapshot.strongDays14}.';
  }
}
