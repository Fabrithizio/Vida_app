// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_body_health_engine.dart
//
// O que faz:
// - Calcula itens dinâmicos da área Corpo & Saúde no Areas
// - Prioriza Health Connect quando houver dado automático útil
// - Usa o módulo Corpo & Saúde como fonte principal sem criar sistemas paralelos
// - Mantém fallback para check-in diário quando faltar dado real
//
// Observações desta revisão:
// - IMC vem direto do fitness (BodyCareService.loadOverview)
// - não apaga a regra antiga de check-ups
// - preserva os fallbacks existentes
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';
import 'package:vida_app/features/health_sync/health_sync_service.dart';

class AreasBodyHealthEngine {
  AreasBodyHealthEngine({
    required AreasDailyQuestionsEngine dailyQuestions,
    BodyCareService? bodyCare,
    SmartHealthSyncService? smartHealth,
  }) : _dailyQuestions = dailyQuestions,
       _bodyCare = bodyCare ?? BodyCareService(),
       _smartHealth = smartHealth ?? SmartHealthSyncService();

  final AreasDailyQuestionsEngine _dailyQuestions;
  final BodyCareService _bodyCare;
  final SmartHealthSyncService _smartHealth;

  Future<AreaAssessment?> computedCheckups(
    String uid, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        (prefs.getString('${uid}:last_checkup') ??
                prefs.getString('$uid:last_checkup') ??
                '')
            .trim();
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
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snapshot = await _smartHealth.readSnapshot(uid);
      final sleepHours = snapshot.sleepHours;
      if (snapshot.isConnected && sleepHours != null && sleepHours > 0) {
        await onAreaUpdated('body_health');
        final score = _scoreSleepHours(sleepHours);
        return AreaAssessment(
          status: _statusFromScore(score),
          score: score,
          reason:
              'Seu sono automático mais recente foi ${sleepHours.toStringAsFixed(1)}h.',
          source: AreaDataSource.automatic,
          lastUpdatedAt: snapshot.lastSyncAt,
          recommendedAction: score >= 80
              ? 'Seu descanso está em boa faixa. Mantenha a constância.'
              : 'Vale proteger mais o horário e a duração do sono.',
          details:
              'Quando existe Health Connect, o sono automático vale mais que autorrelato.',
        );
      }
    }

    final entry = await _bodyCare.loadDay(DateTime.now());
    if (entry.sleep != null) {
      await onAreaUpdated('body_health');
      final score = _scoreFromBodyCareScale(entry.sleep!);
      return AreaAssessment(
        status: _statusFromScore(score),
        score: score,
        reason: 'Seu sono veio do módulo Corpo & Saúde.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: entry.updatedAt,
        recommendedAction: score >= 80
            ? 'Seu sono recente está bem cuidado.'
            : 'Vale ajustar melhor a rotina de descanso.',
        details: 'Sem relógio, o app usa a nota registrada no Corpo & Saúde.',
      );
    }

    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: DateTime.now(),
      questionIds: const ['sleep_quality'],
      positiveReason: 'Seu sono recente parece bom.',
      negativeReason: 'Seu sono recente ficou abaixo do ideal.',
      positiveAction: 'Continue protegendo seu horário de descanso.',
      negativeAction:
          'Vale ajustar horário, ambiente e rotina para dormir melhor.',
      details:
          'Fallback pelo check-in diário quando não houver dado do fitness.',
      onAreaUpdated: onAreaUpdated,
    );
  }

  Future<AreaAssessment?> computedMovement({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final snapshot = await _smartHealth.readSnapshot(uid);
      final exerciseMinutes = snapshot.exerciseMinutes7d;
      if (snapshot.isConnected &&
          exerciseMinutes != null &&
          exerciseMinutes > 0) {
        await onAreaUpdated('body_health');
        final score = _scoreExerciseMinutes7d(exerciseMinutes);
        return AreaAssessment(
          status: _statusFromScore(score),
          score: score,
          reason:
              'Seu movimento automático recente marcou ${exerciseMinutes.toStringAsFixed(0)} min nos últimos 7 dias.',
          source: AreaDataSource.automatic,
          lastUpdatedAt: snapshot.lastSyncAt,
          recommendedAction: score >= 80
              ? 'Seu ritmo de movimento está bom. Continue mantendo.'
              : 'Vale tentar colocar mais caminhada, treino ou movimento útil na semana.',
          details:
              'Quando existe relógio/Health Connect, o movimento automático pesa mais.',
        );
      }
    }

    final overview = await _bodyCare.loadOverview();
    if (overview.weeklyAverageTraining != null) {
      await onAreaUpdated('body_health');
      final score = _scoreFromWeeklyAverageTraining(
        overview.weeklyAverageTraining!,
      );
      return AreaAssessment(
        status: _statusFromScore(score),
        score: score,
        reason:
            'Seu movimento veio da média de treino do módulo Corpo & Saúde.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: score >= 80
            ? 'Seu ritmo corporal está bom.'
            : 'Vale buscar mais constância no movimento.',
        details:
            'Sem relógio, o app usa o treino registrado no fitness como base principal.',
      );
    }

    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: DateTime.now(),
      questionIds: const ['movement_amount', 'body_wellbeing'],
      positiveReason: 'Seu nível recente de movimento está bom.',
      negativeReason: 'Seu nível recente de movimento está baixo.',
      positiveAction: 'Ótimo. Continue com regularidade.',
      negativeAction:
          'Vale tentar ao menos uma caminhada, treino leve ou alongamento.',
      details: 'Fallback pelo check-in diário.',
      onAreaUpdated: onAreaUpdated,
    );
  }

  Future<AreaAssessment?> computedNutrition({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final entry = await _bodyCare.loadDay(DateTime.now());
    if (entry.food != null) {
      await onAreaUpdated('body_health');
      final score = _scoreFromBodyCareScale(entry.food!);
      return AreaAssessment(
        status: _statusFromScore(score),
        score: score,
        reason: 'Sua alimentação veio do módulo Corpo & Saúde.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: entry.updatedAt,
        recommendedAction: score >= 80
            ? 'Boa base alimentar.'
            : 'Vale melhorar a constância da alimentação.',
        details:
            'A alimentação continua valendo, mas com menor confiança que dado automático.',
      );
    }

    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: DateTime.now(),
      questionIds: const ['nutrition'],
      positiveReason: 'Sua alimentação recente parece boa.',
      negativeReason: 'Sua alimentação recente ficou abaixo do ideal.',
      positiveAction: 'Continue protegendo o básico da alimentação.',
      negativeAction: 'Vale reforçar o básico: comida de verdade e constância.',
      details: 'Fallback pelo check-in diário.',
      onAreaUpdated: onAreaUpdated,
    );
  }

  Future<AreaAssessment?> computedHydration({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final entry = await _bodyCare.loadDay(DateTime.now());
    if (entry.water != null) {
      await onAreaUpdated('body_health');
      final score = _scoreFromBodyCareScale(entry.water!);
      return AreaAssessment(
        status: _statusFromScore(score),
        score: score,
        reason: 'Sua hidratação veio do módulo Corpo & Saúde.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: entry.updatedAt,
        recommendedAction: score >= 80
            ? 'Seu cuidado com água está bom.'
            : 'Vale distribuir mais água ao longo do dia.',
        details:
            'A hidratação continua valendo, mas depende do registro do usuário.',
      );
    }

    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'body_health',
      day: DateTime.now(),
      questionIds: const ['hydration'],
      positiveReason: 'Sua hidratação recente parece boa.',
      negativeReason: 'Sua hidratação recente ficou abaixo do ideal.',
      positiveAction: 'Continue protegendo sua água no dia a dia.',
      negativeAction: 'Vale reforçar água ao longo do dia.',
      details: 'Fallback pelo check-in diário.',
      onAreaUpdated: onAreaUpdated,
    );
  }

  Future<AreaAssessment?> computedImc({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final overview = await _bodyCare.loadOverview();
    final bmi = overview.bmi;
    if (bmi == null) {
      return null;
    }

    await onAreaUpdated('body_health');
    final score = _scoreBmi(bmi);
    return AreaAssessment(
      status: _statusFromScore(score),
      score: score,
      reason:
          'Seu IMC atual no fitness é ${bmi.toStringAsFixed(1)} (${overview.bmiLabel}).',
      source: AreaDataSource.mixed,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: score >= 90
          ? 'Seu IMC está na faixa de referência do app.'
          : 'O app vai reduzindo pontos conforme o IMC se afasta da faixa recomendada.',
      details:
          'O Areas puxa o IMC direto do módulo Corpo & Saúde. Não existe sistema separado só para isso.',
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

  int _scoreFromBodyCareScale(int value) {
    switch (value.clamp(0, 4)) {
      case 4:
        return 100;
      case 3:
        return 82;
      case 2:
        return 60;
      case 1:
        return 35;
      default:
        return 12;
    }
  }

  int _scoreFromWeeklyAverageTraining(double value) {
    if (value >= 3.6) return 100;
    if (value >= 2.6) return 82;
    if (value >= 1.6) return 60;
    if (value >= 0.6) return 35;
    return 12;
  }

  int _scoreSleepHours(double hours) {
    if (hours >= 7.0 && hours <= 9.0) return 100;
    if (hours >= 6.0 && hours < 7.0) return 78;
    if (hours > 9.0 && hours <= 10.0) return 82;
    if (hours >= 5.0 && hours < 6.0) return 52;
    return 20;
  }

  int _scoreExerciseMinutes7d(double minutes) {
    if (minutes >= 150) return 100;
    if (minutes >= 120) return 88;
    if (minutes >= 90) return 72;
    if (minutes >= 45) return 50;
    if (minutes > 0) return 28;
    return 0;
  }

  int _scoreBmi(double bmi) {
    const minIdeal = 18.5;
    const maxIdeal = 24.99;

    if (bmi >= minIdeal && bmi <= maxIdeal) return 100;

    if (bmi < minIdeal) {
      final diff = minIdeal - bmi;
      if (diff >= 8) return 0;
      return (100 - (diff / 8 * 100)).round().clamp(0, 100);
    }

    final diff = bmi - maxIdeal;
    if (diff >= 15) return 0;
    return (100 - (diff / 15 * 100)).round().clamp(0, 100);
  }

  AreaStatus _statusFromScore(int score) {
    if (score >= 85) return AreaStatus.excellent;
    if (score >= 70) return AreaStatus.good;
    if (score >= 50) return AreaStatus.medium;
    if (score >= 25) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}
