// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_body_health_engine.dart
//
// O que faz:
// - Calcula a área Corpo & Saúde com base em Health Connect e Body Care
// - Mantém sono, movimento, energia, alimentação, hidratação, IMC e check-ups
// - Agora recebe reforço leve de apps úteis como fitness e meditação
//
// Regra nova:
// - apps úteis só dão bônus leve em sono, movimento e energia
// - ausência de uso não reduz score
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_confidence_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';
import 'package:vida_app/features/health_sync/health_sync_service.dart';

class AreasBodyHealthEngine {
  AreasBodyHealthEngine({
    required AreasDailyQuestionsEngine dailyQuestions,
    BodyCareService? bodyCare,
    SmartHealthSyncService? smartHealth,
    AreasConfidenceEngine? confidenceEngine,
  }) : _bodyCare = bodyCare ?? BodyCareService(),
       _smartHealth = smartHealth ?? SmartHealthSyncService(),
       _confidence = confidenceEngine ?? const AreasConfidenceEngine();

  final BodyCareService _bodyCare;
  final SmartHealthSyncService _smartHealth;
  final AreasConfidenceEngine _confidence;

  Future<int> _bonusFromKey(String keySuffix, int maxBonus) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final score = prefs.getInt('$uid:$keySuffix') ?? 0;
    return ((score / 100.0) * maxBonus).round().clamp(0, maxBonus);
  }

  AreaAssessment _applyBonus(
    AreaAssessment assessment,
    int bonus,
    String detailsAppend,
  ) {
    if (bonus <= 0) return assessment;
    final score = ((assessment.score ?? 0) + bonus).clamp(0, 100);
    return AreaAssessment(
      status: _statusFromScore(score),
      score: score,
      reason: assessment.reason,
      source: assessment.source,
      lastUpdatedAt: assessment.lastUpdatedAt,
      recommendedAction: assessment.recommendedAction,
      details: '${assessment.details ?? ''} $detailsAppend',
    );
  }

  Future<AreaAssessment?> computedCheckups(
    String uid, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = ((prefs.getString('$uid:last_checkup') ?? '').trim());
    if (raw.isEmpty) return getAssessment('body_health', 'checkups');
    final date = _parseIsoDate(raw);
    if (date == null) return getAssessment('body_health', 'checkups');

    final now = DateTime.now();
    final days = now.difference(date).inDays;
    final monthsApprox = days / 30.4375;

    late final int rawScore;
    late final String action;
    late final String reason;

    if (monthsApprox <= 8.0) {
      rawScore = 92;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Ótimo. Continue mantendo esse cuidado em dia.';
    } else if (monthsApprox <= 12.0) {
      rawScore = 72;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Bom. Só fique atento para não deixar passar muito mais tempo.';
    } else if (monthsApprox <= 14.4) {
      rawScore = 50;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Já vale começar a se organizar para atualizar esse cuidado.';
    } else if (monthsApprox < 24.0) {
      rawScore = 30;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Seu check-up está atrasado. Vale priorizar isso.';
    } else {
      rawScore = 10;
      reason =
          'Seu último check-up foi há cerca de ${monthsApprox.toStringAsFixed(1)} meses.';
      action = 'Faz muito tempo sem check-up. Isso virou prioridade.';
    }

    final finalScore = _confidence.effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.manual,
      daysSinceUpdate: days,
      consistency01: 1.0,
      completeness01: 1.0,
    );

    return AreaAssessment(
      status: _statusFromScore(finalScore),
      score: finalScore,
      reason: reason,
      source: AreaDataSource.manual,
      lastUpdatedAt: date,
      recommendedAction: action,
      details:
          'Regra atual do app para check-ups: até 8 meses = ótimo; até 1 ano = bom; até 1,2 anos = médio; até 2 anos = ruim; 2 anos ou mais = crítico. Score final ajustado pela confiança da fonte e pela recência do registro.',
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
        final rawScore = _scoreSleepHours(sleepHours.toDouble());
        final finalScore = _confidence.effectiveScore(
          rawScore: rawScore,
          source: AreaDataSource.automatic,
          daysSinceUpdate: _daysSince(snapshot.lastSyncAt),
          consistency01: 1.0,
          completeness01: 1.0,
        );
        return _applyBonus(
          AreaAssessment(
            status: _statusFromScore(finalScore),
            score: finalScore,
            reason:
                'Seu sono automático mais recente foi ${sleepHours.toStringAsFixed(1)}h.',
            source: AreaDataSource.automatic,
            lastUpdatedAt: snapshot.lastSyncAt,
            recommendedAction: finalScore >= 80
                ? 'Seu descanso está em boa faixa. Mantenha a constância.'
                : 'Vale proteger mais o horário e a duração do sono.',
            details:
                'Quando existe Health Connect, o sono automático vale mais que autorrelato.',
          ),
          await _bonusFromKey('app_usage_meditation_score', 6),
          'Apps de meditação podem reforçar levemente esta leitura.',
        );
      }
    }

    final entry = await _bodyCare.loadDay(DateTime.now());
    if (entry.sleep != null) {
      await onAreaUpdated('body_health');
      final rawScore = _scoreFromBodyCareScale(entry.sleep!);
      final finalScore = _confidence.effectiveScore(
        rawScore: rawScore,
        source: AreaDataSource.mixed,
        daysSinceUpdate: _daysSince(entry.updatedAt),
        consistency01: 1.0,
        completeness01: 1.0,
      );
      return _applyBonus(
        AreaAssessment(
          status: _statusFromScore(finalScore),
          score: finalScore,
          reason: 'Seu sono veio do módulo Corpo & Saúde.',
          source: AreaDataSource.mixed,
          lastUpdatedAt: entry.updatedAt,
          recommendedAction: finalScore >= 80
              ? 'Seu sono recente está bem cuidado.'
              : 'Vale ajustar melhor a rotina de descanso.',
          details: 'Sem relógio, o app usa a nota registrada no Corpo & Saúde.',
        ),
        await _bonusFromKey('app_usage_meditation_score', 6),
        'Apps de meditação podem reforçar levemente esta leitura.',
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
    final rawFinal = (baseScore + ((100 - baseScore) * stepBonusFactor))
        .round()
        .clamp(0, 100);

    await onAreaUpdated('body_health');
    final finalScore = _confidence.effectiveScore(
      rawScore: rawFinal,
      source: source,
      daysSinceUpdate: _daysSince(lastUpdatedAt),
      consistency01: steps == null ? 0.90 : 1.0,
      completeness01: steps == null ? 0.85 : 1.0,
    );

    return _applyBonus(
      AreaAssessment(
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
      ),
      await _bonusFromKey('app_usage_fitness_score', 10),
      'Apps de fitness podem reforçar levemente esta leitura.',
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

    final rawScore = (parts.reduce((a, b) => a + b) / totalWeight)
        .round()
        .clamp(0, 100);

    await onAreaUpdated('body_health');
    final filled = [
      if (sleepScore != null) 1,
      if (movementScore != null) 1,
      if (stepsScore != null) 1,
    ].length;
    final finalScore = _confidence.effectiveScore(
      rawScore: rawScore,
      source: source,
      daysSinceUpdate: _daysSince(lastUpdatedAt),
      consistency01: _confidence.consistencyFromHistory([
        if (sleepScore != null) sleepScore.round(),
        if (movementScore != null) movementScore.round(),
        if (stepsScore != null) stepsScore.round(),
      ]),
      completeness01: _confidence.completenessFromCounts(
        filledCount: filled,
        expectedCount: 3,
      ),
    );

    return _applyBonus(
      AreaAssessment(
        status: _statusFromScore(finalScore),
        score: finalScore,
        reason:
            'Sua energia está sendo lida por sinais reais de sono, movimento e passos quando existirem.',
        source: source,
        lastUpdatedAt: lastUpdatedAt,
        recommendedAction: finalScore >= 80
            ? 'Seu corpo está respondendo bem ao seu ritmo recente.'
            : 'Vale proteger mais o descanso e o movimento útil da rotina.',
        details:
            'Energia não depende mais do check-in diário. O app cruza sono, treino/atividade e passos do relógio quando existirem.',
      ),
      await _bonusFromKey('app_usage_fitness_score', 7) +
          await _bonusFromKey('app_usage_meditation_score', 4),
      'Apps de fitness/meditação podem reforçar levemente esta leitura.',
    );
  }

  Future<AreaAssessment?> computedNutrition({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final recent = await _bodyCare.loadRecentEntries(days: 14);
    final values = recent
        .map((e) => e.value.food)
        .whereType<int>()
        .map((v) => _scoreFromBodyCareScale(v).toDouble())
        .toList();

    if (values.isEmpty) return null;

    final avg = values.reduce((a, b) => a + b) / values.length;
    final lastUpdatedAt = recent
        .map((e) => e.value.updatedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, date) {
          if (latest == null) return date;
          return date.isAfter(latest) ? date : latest;
        });

    final rawScore = avg.round().clamp(0, 100);
    await onAreaUpdated('body_health');

    final finalScore = _confidence.effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.mixed,
      daysSinceUpdate: _daysSince(lastUpdatedAt),
      consistency01: _confidence.consistencyFromHistory(
        values.map((e) => e.round()).toList(),
      ),
      completeness01: _confidence.completenessFromCounts(
        filledCount: values.length,
        expectedCount: 14,
      ),
    );

    return AreaAssessment(
      status: _statusFromScore(finalScore),
      score: finalScore,
      reason:
          'Sua alimentação está usando a média móvel dos últimos ${values.length} registros dentro da janela de 14 dias.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: lastUpdatedAt,
      recommendedAction: finalScore >= 80
          ? 'Boa base alimentar.'
          : 'Vale melhorar a constância da alimentação.',
      details:
          'A pontuação de alimentação usa a média dos últimos 14 dias registrados no módulo Corpo & Saúde, para manter persistência real em vez de sumir no dia seguinte.',
    );
  }

  Future<AreaAssessment?> computedHydration({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final recent = await _bodyCare.loadRecentEntries(days: 14);
    final values = recent
        .map((e) => e.value.water)
        .whereType<int>()
        .map((v) => _scoreFromBodyCareScale(v).toDouble())
        .toList();

    if (values.isEmpty) return null;

    final avg = values.reduce((a, b) => a + b) / values.length;
    final lastUpdatedAt = recent
        .map((e) => e.value.updatedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, date) {
          if (latest == null) return date;
          return date.isAfter(latest) ? date : latest;
        });

    final rawScore = avg.round().clamp(0, 100);
    await onAreaUpdated('body_health');

    final finalScore = _confidence.effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.mixed,
      daysSinceUpdate: _daysSince(lastUpdatedAt),
      consistency01: _confidence.consistencyFromHistory(
        values.map((e) => e.round()).toList(),
      ),
      completeness01: _confidence.completenessFromCounts(
        filledCount: values.length,
        expectedCount: 14,
      ),
    );

    return AreaAssessment(
      status: _statusFromScore(finalScore),
      score: finalScore,
      reason:
          'Sua hidratação está usando a média móvel dos últimos ${values.length} registros dentro da janela de 14 dias.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: lastUpdatedAt,
      recommendedAction: finalScore >= 80
          ? 'Seu cuidado com água está bom.'
          : 'Vale distribuir mais água ao longo do dia.',
      details:
          'A pontuação de hidratação usa a média dos últimos 14 dias registrados no módulo Corpo & Saúde, para manter persistência real e não ficar cinza no dia seguinte.',
    );
  }

  Future<AreaAssessment?> computedImc({
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final overview = await _bodyCare.loadOverview();
    final bmi = overview.bmi;
    if (bmi == null) return null;

    await onAreaUpdated('body_health');
    final rawScore = _scoreBmi(bmi.toDouble());
    final finalScore = _confidence.effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.mixed,
      daysSinceUpdate: 0,
      consistency01: 1.0,
      completeness01: 1.0,
    );
    return AreaAssessment(
      status: _statusFromScore(finalScore),
      score: finalScore,
      reason:
          'Seu IMC atual no fitness é ${bmi.toStringAsFixed(1)} (${overview.bmiLabel}).',
      source: AreaDataSource.mixed,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: finalScore >= 90
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

  int _daysSince(DateTime? date) {
    if (date == null) return 30;
    return DateTime.now().difference(date).inDays.clamp(0, 365);
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
    if (score >= 45) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}
