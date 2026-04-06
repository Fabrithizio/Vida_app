import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_environment_engine.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';

class AreasPurposeEngine {
  AreasPurposeEngine({
    required AreasDailyQuestionsEngine dailyQuestions,
    required AreasEnvironmentEngine environment,
  }) : _dailyQuestions = dailyQuestions,
       _environment = environment;

  final AreasDailyQuestionsEngine _dailyQuestions;
  final AreasEnvironmentEngine _environment;

  Future<AreaAssessment?> computedPurposeValuesItem(
    String itemId, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    switch (itemId) {
      case 'direction':
        return _computedPurposeBaseline(
          getAssessment: getAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      case 'goals_review':
        return _computedPurposeConsistency(
          getAssessment: getAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      case 'gratitude':
        return _computedPurposeRecovery(
          getAssessment: getAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      default:
        return getAssessment('purpose_values', itemId);
    }
  }

  Future<AreaAssessment?> _computedPurposeBaseline({
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final now = DateTime.now();
    final history = await _dailyQuestions.readDailyScaledHistory(
      day: now,
      questionIds: const ['routine_ok', 'day_planning', 'energy_ok'],
      days: DailyCheckinService.historyDays,
    );

    final organization = await _environment.computedEnvironmentItem(
      'environment_home',
      'organization',
      getAssessment: getAssessment,
      onAreaUpdated: onAreaUpdated,
    );
    final cleaning = await _environment.computedEnvironmentItem(
      'environment_home',
      'cleaning',
      getAssessment: getAssessment,
      onAreaUpdated: onAreaUpdated,
    );

    double weightedSum = 0;
    double totalWeight = 0;

    if (history.isNotEmpty) {
      weightedSum += _dailyQuestions.weightedScaledHistoryScore(history) * 0.60;
      totalWeight += 0.60;
    }
    if (organization?.score != null) {
      weightedSum += organization!.score! * 0.25;
      totalWeight += 0.25;
    }
    if (cleaning?.score != null) {
      weightedSum += cleaning!.score! * 0.15;
      totalWeight += 0.15;
    }

    if (totalWeight == 0) {
      return getAssessment('purpose_values', 'direction');
    }

    final score = (weightedSum / totalWeight).round().clamp(0, 100);
    final status = _statusFromNumericScore(score);
    final trend = history.isEmpty
        ? 'stable'
        : _dailyQuestions.trendFromScaledHistory(history);
    final action = _actionFromStatus(
      status: status,
      excellent:
          'Sua base do dia a dia está firme. Continue repetindo o básico.',
      good: 'Sua base está boa. Vale manter o ritmo do essencial.',
      medium: 'Sua base está mediana. Reforçar o básico já ajuda bastante.',
      poor:
          'Sua base do dia a dia está frágil no momento. Simplifique e retome o essencial.',
      critical:
          'Sua base da rotina está muito instável. Recomece pelo mínimo viável.',
    );

    final latestDate = history.isNotEmpty
        ? history.first.date
        : _latestDate(organization?.lastUpdatedAt, cleaning?.lastUpdatedAt);
    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };

    final reason = switch (status) {
      AreaStatus.excellent =>
        'Sua base recente de rotina e ambiente está muito bem sustentada.',
      AreaStatus.good =>
        'Sua base recente está boa, com sinais consistentes de funcionamento.',
      AreaStatus.medium => 'Sua base recente funciona, mas ainda oscila.',
      AreaStatus.poor => 'Sua base recente está fraca e irregular.',
      AreaStatus.critical => 'Sua base recente está muito instável.',
      AreaStatus.noData => 'Ainda faltam dados para essa subárea.',
    };

    await onAreaUpdated('purpose_values');

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: AreaDataSource.mixed,
      lastUpdatedAt: latestDate ?? now,
      recommendedAction: action,
      details:
          'Calculado pela base da rotina recente (rotina, planejamento e energia) junto com os sinais automáticos de organização e limpeza do ambiente. $trendSentence',
    );
  }

  Future<AreaAssessment?> _computedPurposeConsistency({
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final now = DateTime.now();
    final history = await _dailyQuestions.readDailyScaledHistory(
      day: now,
      questionIds: const ['routine_ok', 'move', 'study_ok'],
      days: DailyCheckinService.historyDays,
    );

    if (history.isEmpty) {
      return getAssessment('purpose_values', 'goals_review');
    }

    final valueScore = _dailyQuestions
        .weightedScaledHistoryScore(history)
        .toDouble();
    final activeDays14 = history.length.clamp(
      0,
      DailyCheckinService.historyDays,
    );
    final recentActiveDays7 = history
        .where((p) => now.difference(p.date).inDays <= 6)
        .length
        .clamp(0, 7);

    final frequency14 =
        (activeDays14 / DailyCheckinService.historyDays) * 100.0;
    final frequency7 = (recentActiveDays7 / 7.0) * 100.0;

    var score =
        ((valueScore * 0.45) + (frequency14 * 0.35) + (frequency7 * 0.20))
            .round();

    final lastGap = now.difference(history.first.date).inDays;
    if (lastGap > 2) {
      score -= ((lastGap - 2) * 4).clamp(0, 20);
    }

    final finalScore = score.clamp(0, 100);
    final status = _statusFromNumericScore(finalScore);
    final trend = _dailyQuestions.trendFromScaledHistory(history);
    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };

    final action = _actionFromStatus(
      status: status,
      excellent:
          'Sua constância recente está muito boa. Continue aparecendo todos os dias.',
      good: 'Boa constância. Vale proteger esse ritmo para não cair.',
      medium: 'Sua constância está razoável, mas ainda oscila bastante.',
      poor: 'Sua constância está fraca. Retome metas menores e repetíveis.',
      critical: 'Sua constância está muito baixa. Recomece com ações mínimas.',
    );

    await onAreaUpdated('purpose_values');

    return AreaAssessment(
      status: status,
      score: finalScore,
      reason:
          'Você gerou sinais de rotina/estudo/movimento em $activeDays14 dos últimos ${DailyCheckinService.historyDays} dias; $recentActiveDays7 desses dias foram nesta última semana.',
      source: AreaDataSource.estimated,
      lastUpdatedAt: history.first.date,
      recommendedAction: action,
      details:
          'Calculado pela qualidade recente desses sinais e, principalmente, pela frequência com que eles aparecem ao longo dos últimos ${DailyCheckinService.historyDays} dias. $trendSentence',
    );
  }

  Future<AreaAssessment?> _computedPurposeRecovery({
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final now = DateTime.now();
    final history = await _dailyQuestions.readDailyScaledHistory(
      day: now,
      questionIds: const [
        'mental_recovery',
        'sleep_ok',
        'mood_ok',
        'stress_ok',
      ],
      days: DailyCheckinService.historyDays,
    );

    final sleepAssessment = await _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: now,
      questionIds: const ['sleep_ok'],
      positiveReason: 'Seu sono recente parece bom.',
      negativeReason: 'Seu sono recente ficou abaixo do ideal.',
      positiveAction: 'Continue protegendo seu horário de descanso.',
      negativeAction:
          'Vale ajustar horário, ambiente e rotina para dormir melhor.',
      details: 'Baseado nas respostas recentes sobre sono.',
      onAreaUpdated: onAreaUpdated,
    );

    if (history.isEmpty && sleepAssessment?.score == null) {
      return getAssessment('purpose_values', 'gratitude');
    }

    double weightedSum = 0;
    double totalWeight = 0;

    if (history.isNotEmpty) {
      weightedSum += _dailyQuestions.weightedScaledHistoryScore(history) * 0.75;
      totalWeight += 0.75;
    }
    if (sleepAssessment?.score != null) {
      weightedSum += sleepAssessment!.score! * 0.25;
      totalWeight += 0.25;
    }

    final score = totalWeight == 0
        ? 0
        : (weightedSum / totalWeight).round().clamp(0, 100);
    final status = _statusFromNumericScore(score);
    final trend = history.isEmpty
        ? 'stable'
        : _dailyQuestions.trendFromScaledHistory(history);
    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };

    final action = _actionFromStatus(
      status: status,
      excellent:
          'Sua recuperação está muito boa. Continue protegendo pausas e descanso.',
      good: 'Boa recuperação recente. Vale manter esses cuidados.',
      medium: 'Sua recuperação está mediana. Reforce pausas e descanso.',
      poor: 'Sua recuperação está baixa. Diminua pressão e recupere o básico.',
      critical:
          'Sua recuperação está muito fraca. Priorize descanso e redução de carga.',
    );

    final latestDate = history.isNotEmpty
        ? history.first.date
        : sleepAssessment?.lastUpdatedAt;

    await onAreaUpdated('purpose_values');

    return AreaAssessment(
      status: status,
      score: score,
      reason: switch (status) {
        AreaStatus.excellent =>
          'Você está conseguindo recuperar energia e equilíbrio com boa consistência.',
        AreaStatus.good => 'Sua recuperação recente está em bom nível.',
        AreaStatus.medium =>
          'Sua recuperação recente está razoável, mas oscila.',
        AreaStatus.poor => 'Sua recuperação recente está abaixo do ideal.',
        AreaStatus.critical => 'Sua recuperação recente está muito baixa.',
        AreaStatus.noData => 'Ainda faltam dados para essa subárea.',
      },
      source: sleepAssessment?.score != null
          ? AreaDataSource.mixed
          : AreaDataSource.estimated,
      lastUpdatedAt: latestDate ?? now,
      recommendedAction: action,
      details:
          'Calculado pelos sinais recentes de recuperação mental, sono, humor e estresse. ${sleepAssessment?.score != null ? 'O sono também entra como reforço nessa leitura. ' : ''}$trendSentence',
    );
  }

  String _actionFromStatus({
    required AreaStatus status,
    required String excellent,
    required String good,
    required String medium,
    required String poor,
    required String critical,
  }) {
    switch (status) {
      case AreaStatus.excellent:
        return excellent;
      case AreaStatus.good:
        return good;
      case AreaStatus.medium:
        return medium;
      case AreaStatus.poor:
        return poor;
      case AreaStatus.critical:
        return critical;
      case AreaStatus.noData:
        return 'Atualize os dados dessa subárea.';
    }
  }

  AreaStatus _statusFromNumericScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }

  DateTime? _latestDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
