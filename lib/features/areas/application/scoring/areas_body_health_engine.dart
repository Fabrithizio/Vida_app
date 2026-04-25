// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_body_health_engine.dart
//
// O que faz:
// - Calcula itens da área Corpo & Saúde usando Corpo & Saúde + Health Connect
// - Mantém check-ups, sono, movimento, hidratação, alimentação e IMC
// - Calcula energia por sinais reais, sem depender do check-in diário
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
    final raw = (prefs.getString('$uid:last_checkup') ?? '').trim();
    if (raw.isEmpty) return getAssessment('body_health', 'checkups');
    final date = _parseIsoDate(raw);
    if (date == null) return getAssessment('body_health', 'checkups');

    final now = DateTime.now();
    final days = now.difference(date).inDays;
    final monthsApprox = days / 30.4375;

    late final int score;
    late final AreaStatus status;
    late final String action;

    if (monthsApprox <= 8.0) {
      score = 92;
      status = AreaStatus.excellent;
      action = 'Ótimo. Continue mantendo esse cuidado em dia.';
    } else if (monthsApprox <= 12.0) {
      score = 72;
      status = AreaStatus.good;
      action = 'Bom. Só fique atento para não deixar passar muito mais tempo.';
    } else if (monthsApprox <= 14.4) {
      score = 50;
      status = AreaStatus.medium;
      action = 'Já vale começar a se organizar para atualizar esse cuidado.';
    } else if (monthsApprox < 24.0) {
      score = 30;
      status = AreaStatus.poor;
      action = 'Seu check-up está atrasado. Vale priorizar isso.';
    } else {
      score = 10;
      status = AreaStatus.critical;
      action = 'Faz muito tempo sem check-up. Isso virou prioridade.';
    }

    return AreaAssessment(
      status: status,
      score: score,
      reason:
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.',
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
        final score = _scoreSleepHours(sleepHours.toDouble());
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
    return null;
  }

  Future<AreaAssessment?> computedMovement({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    double? baseScore;
    double? steps;
    DateTime? lastUpdatedAt;
    AreaDataSource source = AreaDataSource.mixed;

    if (uid != null) {
      final snapshot = await _smartHealth.readSnapshot(uid);
      final exerciseMinutes = snapshot.exerciseMinutes7d;
      final rawSteps = snapshot.stepsToday;
      if (rawSteps != null) {
        steps = rawSteps.toDouble();
      }

      if (snapshot.isConnected &&
          exerciseMinutes != null &&
          exerciseMinutes > 0) {
        baseScore = _scoreExerciseMinutes7d(
          exerciseMinutes.toDouble(),
        ).toDouble();
        lastUpdatedAt = snapshot.lastSyncAt;
        source = AreaDataSource.automatic;
      }
    }

    if (baseScore == null) {
      final overview = await _bodyCare.loadOverview();
      if (overview.weeklyAverageTraining != null) {
        baseScore = _scoreFromBodyCareScale(
          overview.weeklyAverageTraining!.round().clamp(0, 4),
        ).toDouble();
        lastUpdatedAt = DateTime.now();
        source = AreaDataSource.mixed;
      }
    }

    if (baseScore == null) return null;

    final stepBonusFactor = _stepBonusFactor(steps);
    final finalScore = (baseScore + ((100 - baseScore) * stepBonusFactor))
        .round()
        .clamp(0, 100);

    await onAreaUpdated('body_health');
    return AreaAssessment(
      status: _statusFromScore(finalScore),
      score: finalScore,
      reason: steps != null && steps > 0
          ? 'Seu movimento juntou treino/atividade com ${steps.toStringAsFixed(0)} passos no dia.'
          : 'Seu movimento veio do treino e da atividade registrada.',
      source: source,
      lastUpdatedAt: lastUpdatedAt,
      recommendedAction: finalScore >= 80
          ? 'Seu ritmo de movimento está bom. Continue mantendo.'
          : 'Vale buscar mais constância no movimento útil da semana.',
      details:
          'Movimento usa treino do fitness ou atividade automática. Quando existem passos do relógio, eles podem melhorar a nota em até 80% da distância que faltava até 100, sem punir quem não tem relógio.',
    );
  }

  Future<AreaAssessment?> computedEnergy({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = uid == null ? null : await _smartHealth.readSnapshot(uid);

    double? sleepScore;
    double? movementScore;
    double? stepsScore;
    DateTime? lastUpdatedAt;
    AreaDataSource source = AreaDataSource.mixed;

    if (snapshot != null && snapshot.isConnected) {
      if (snapshot.sleepHours != null && snapshot.sleepHours! > 0) {
        sleepScore = _scoreSleepHours(
          snapshot.sleepHours!.toDouble(),
        ).toDouble();
        lastUpdatedAt = snapshot.lastSyncAt;
        source = AreaDataSource.automatic;
      }
      if (snapshot.exerciseMinutes7d != null &&
          snapshot.exerciseMinutes7d! > 0) {
        movementScore = _scoreExerciseMinutes7d(
          snapshot.exerciseMinutes7d!.toDouble(),
        ).toDouble();
        lastUpdatedAt = snapshot.lastSyncAt;
        source = AreaDataSource.automatic;
      }
      if (snapshot.stepsToday != null && snapshot.stepsToday! > 0) {
        stepsScore = _scoreSteps(snapshot.stepsToday!.toDouble()).toDouble();
        lastUpdatedAt = snapshot.lastSyncAt;
        source = AreaDataSource.automatic;
      }
    }

    final entry = await _bodyCare.loadDay(DateTime.now());
    final overview = await _bodyCare.loadOverview();

    if (sleepScore == null && entry.sleep != null) {
      sleepScore = _scoreFromBodyCareScale(entry.sleep!).toDouble();
      lastUpdatedAt = entry.updatedAt;
    }
    if (movementScore == null && overview.weeklyAverageTraining != null) {
      movementScore = _scoreFromBodyCareScale(
        overview.weeklyAverageTraining!.round().clamp(0, 4),
      ).toDouble();
      lastUpdatedAt ??= DateTime.now();
    }

    final parts = <double>[];
    double totalWeight = 0;

    if (sleepScore != null) {
      parts.add(sleepScore * 0.55);
      totalWeight += 0.55;
    }
    if (movementScore != null) {
      parts.add(movementScore * 0.30);
      totalWeight += 0.30;
    }
    if (stepsScore != null) {
      parts.add(stepsScore * 0.15);
      totalWeight += 0.15;
    }

    if (totalWeight <= 0) return null;

    final score = (parts.reduce((a, b) => a + b) / totalWeight).round().clamp(
      0,
      100,
    );

    await onAreaUpdated('body_health');
    return AreaAssessment(
      status: _statusFromScore(score),
      score: score,
      reason:
          'Sua energia está sendo lida por sinais reais de sono, movimento e passos quando existirem.',
      source: source,
      lastUpdatedAt: lastUpdatedAt,
      recommendedAction: score >= 80
          ? 'Seu corpo está respondendo bem ao seu ritmo recente.'
          : 'Vale proteger mais o descanso e o movimento útil da rotina.',
      details:
          'Energia não depende mais do check-in diário. O app cruza sono, treino/atividade e passos do relógio quando existirem.',
    );
  }

  Future<AreaAssessment?> computedNutrition({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final entry = await _bodyCare.loadDay(DateTime.now());
    if (entry.food == null) return null;

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

  Future<AreaAssessment?> computedHydration({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final entry = await _bodyCare.loadDay(DateTime.now());
    if (entry.water == null) return null;

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

  Future<AreaAssessment?> computedImc({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final overview = await _bodyCare.loadOverview();
    final bmi = overview.bmi;
    if (bmi == null) return null;

    await onAreaUpdated('body_health');
    final score = _scoreBmi(bmi.toDouble());
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

  String toIsoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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

  int _scoreSteps(double steps) {
    if (steps >= 8000) return 100;
    if (steps >= 7000) return 92;
    if (steps >= 5000) return 75;
    if (steps >= 3000) return 50;
    if (steps > 0) return 25;
    return 0;
  }

  double _stepBonusFactor(double? steps) {
    if (steps == null || steps <= 0) return 0;
    if (steps >= 8000) return 0.80;
    if (steps >= 7000) return 0.70;
    if (steps >= 5000) return 0.45;
    if (steps >= 3000) return 0.25;
    return 0.10;
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
