import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';

class AreasBodyHealthEngine {
  AreasBodyHealthEngine({required AreasDailyQuestionsEngine dailyQuestions})
    : _dailyQuestions = dailyQuestions;

  final AreasDailyQuestionsEngine _dailyQuestions;

  Future<AreaAssessment?> computedCheckups(
    String uid, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:last_checkup') ?? '').trim();
    if (raw.isEmpty) {
      return getAssessment('body_health', 'checkups');
    }

    final date = _parseIsoDate(raw);
    if (date == null) {
      return getAssessment('body_health', 'checkups');
    }

    final now = DateTime.now();
    final days = now.difference(date).inDays;
    final monthsApprox = days / 30.4375;

    late final int score;
    late final AreaStatus status;
    late final String reason;
    late final String action;

    if (monthsApprox <= 8.0) {
      score = 92;
      status = AreaStatus.excellent;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Ótimo. Continue mantendo esse cuidado em dia.';
    } else if (monthsApprox <= 12.0) {
      score = 72;
      status = AreaStatus.good;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Bom. Só fique atento para não deixar passar muito mais tempo.';
    } else if (monthsApprox <= 14.4) {
      score = 50;
      status = AreaStatus.medium;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Já vale começar a se organizar para atualizar esse cuidado.';
    } else if (monthsApprox < 24.0) {
      score = 30;
      status = AreaStatus.poor;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Seu check-up está atrasado. Vale priorizar isso.';
    } else {
      score = 10;
      status = AreaStatus.critical;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Faz muito tempo sem check-up. Isso virou prioridade.';
    }

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: AreaDataSource.manual,
      lastUpdatedAt: date,
      recommendedAction: action,
      details:
          'Regra atual do app para check-ups: até 8 meses = ótimo; até 1 ano = bom; até 1,2 anos = médio; até 2 anos = ruim; 2 anos ou mais = crítico.',
    );
  }

  Future<AreaAssessment?> computedSleep({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) {
    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: DateTime.now(),
      questionIds: const ['sleep_ok'],
      positiveReason: 'Seu sono recente parece bom.',
      negativeReason: 'Seu sono recente ficou abaixo do ideal.',
      positiveAction: 'Continue protegendo seu horário de descanso.',
      negativeAction:
          'Vale ajustar horário, ambiente e rotina para dormir melhor.',
      details: 'Baseado nas respostas recentes sobre sono.',
      onAreaUpdated: onAreaUpdated,
    );
  }

  Future<AreaAssessment?> computedMovement({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) {
    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: DateTime.now(),
      questionIds: const ['move'],
      positiveReason: 'Seu nível recente de movimento está bom.',
      negativeReason: 'Seu nível recente de movimento está baixo.',
      positiveAction: 'Ótimo. Continue com regularidade.',
      negativeAction:
          'Vale tentar ao menos uma caminhada, treino leve ou alongamento.',
      details: 'Baseado nas respostas recentes sobre movimento.',
      onAreaUpdated: onAreaUpdated,
    );
  }

  String toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime? _parseIsoDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }
}
