// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_mind_emotion_engine.dart
//
// O que faz:
// - Calcula a área Mente & Emoções usando check-in e sinais indiretos do app
// - Mistura humor, estresse, foco e carga mental com contexto real
// - Agora recebe reforço leve de apps úteis como meditação, foco, fitness e finanças
//
// Regra nova:
// - apps úteis só ajudam quando existirem
// - não criam score sozinhos e não punem ausência de uso
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_confidence_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';

typedef ComputedAssessmentGetter =
    Future<AreaAssessment?> Function(String areaId, String itemId);

class AreasMindEmotionEngine {
  AreasMindEmotionEngine({
    required AreasDailyQuestionsEngine dailyQuestions,
    AreasConfidenceEngine? confidenceEngine,
  }) : _dailyQuestions = dailyQuestions,
       _confidence = confidenceEngine ?? const AreasConfidenceEngine();

  final AreasDailyQuestionsEngine _dailyQuestions;
  final AreasConfidenceEngine _confidence;

  Future<AreaAssessment?> computedItem(
    String itemId, {
    required ComputedAssessmentGetter getComputedAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    switch (itemId) {
      case 'mood':
        return _computedMood(
          getComputedAssessment: getComputedAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      case 'stress':
        return _computedStress(
          getComputedAssessment: getComputedAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      case 'focus':
        return _computedFocus(
          getComputedAssessment: getComputedAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      case 'mental_load':
        return _computedMentalLoad(
          getComputedAssessment: getComputedAssessment,
          onAreaUpdated: onAreaUpdated,
        );
      default:
        return null;
    }
  }

  Future<int> _bonusFromKey(String keySuffix, int maxBonus) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final score = prefs.getInt('$uid:$keySuffix') ?? 0;
    return ((score / 100.0) * maxBonus).round().clamp(0, maxBonus);
  }

  Future<AreaAssessment?> _computedMood({
    required ComputedAssessmentGetter getComputedAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final direct = await _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'mind_emotion',
      day: DateTime.now(),
      questionIds: const ['mood_balance', 'recovery_after_hit'],
      positiveReason: 'Seu humor recente parece estável.',
      negativeReason: 'Seu humor recente mostrou oscilação.',
      positiveAction: 'Continue protegendo o que está te fazendo bem.',
      negativeAction:
          'Vale observar o que mais está te drenando nos últimos dias.',
      details: 'Base direta do check-in sobre humor e recuperação.',
      onAreaUpdated: onAreaUpdated,
    );

    final assessment = await _buildCompositeAssessment(
      direct: direct,
      weighted: [
        (await _safe(getComputedAssessment, 'body_health', 'sleep'), 0.18),
        (
          await _safe(
            getComputedAssessment,
            'relations_community',
            'social_contact',
          ),
          0.14,
        ),
        (await _safe(getComputedAssessment, 'work_vocation', 'routine'), 0.08),
      ],
      directWeight: 0.60,
      positiveReason:
          'Seu humor ficou sustentado por respostas recentes e pelo contexto geral do app.',
      negativeReason:
          'Seu humor caiu junto com sinais indiretos importantes do seu dia a dia.',
      positiveAction: 'Continue protegendo sono, rotina e contato social.',
      negativeAction:
          'Vale cuidar da base: sono, ritmo do dia e conexão com pessoas importantes.',
      details:
          'Mente & Emoções usa pergunta direta, mas também olha sinais indiretos como sono, rotina e conexão social.',
      onAreaUpdated: onAreaUpdated,
    );

    return _applyBonus(
      assessment,
      bonus:
          await _bonusFromKey('app_usage_meditation_score', 8) +
          await _bonusFromKey('app_usage_fitness_score', 4),
      detailsAppend:
          'Apps de meditação/fitness podem reforçar levemente esta leitura.',
    );
  }

  Future<AreaAssessment?> _computedStress({
    required ComputedAssessmentGetter getComputedAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final direct = await _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'mind_emotion',
      day: DateTime.now(),
      questionIds: const [
        'mental_pressure',
        'recovery_after_hit',
        'money_pressure_mind',
      ],
      positiveReason: 'Sua pressão recente parece mais controlada.',
      negativeReason: 'Sua pressão recente parece alta.',
      positiveAction: 'Continue protegendo pausas e a base da rotina.',
      negativeAction: 'Vale reduzir pontos de pressão e reforçar recuperação.',
      details: 'Base direta do check-in sobre estresse e recuperação.',
      onAreaUpdated: onAreaUpdated,
    );

    final assessment = await _buildCompositeAssessment(
      direct: direct,
      weighted: [
        (
          await _safe(getComputedAssessment, 'finance_material', 'budget'),
          0.15,
        ),
        (
          await _safe(getComputedAssessment, 'finance_material', 'spending'),
          0.10,
        ),
        (await _safe(getComputedAssessment, 'body_health', 'sleep'), 0.12),
        (await _safe(getComputedAssessment, 'digital_tech', 'night_use'), 0.08),
        (await _safe(getComputedAssessment, 'work_vocation', 'routine'), 0.10),
      ],
      directWeight: 0.55,
      positiveReason:
          'Sua pressão mental ficou mais sob controle no recorte recente.',
      negativeReason:
          'Seu estresse caiu junto com sono, finanças, rotina ou uso noturno.',
      positiveAction:
          'Mantenha a base do sono, da rotina e do controle de pressão.',
      negativeAction:
          'Observe o que mais está apertando: dinheiro, noite bagunçada, rotina ou descanso.',
      details:
          'Esta subárea cruza resposta direta com pressão financeira, sono, rotina e uso digital noturno.',
      onAreaUpdated: onAreaUpdated,
    );

    return _applyBonus(
      assessment,
      bonus:
          await _bonusFromKey('app_usage_meditation_score', 7) +
          await _bonusFromKey('app_usage_finance_score', 4),
      detailsAppend:
          'Apps de meditação/finanças podem ajudar levemente no controle percebido.',
    );
  }

  Future<AreaAssessment?> _computedFocus({
    required ComputedAssessmentGetter getComputedAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final direct = await _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'mind_emotion',
      day: DateTime.now(),
      questionIds: const ['mental_clarity', 'distraction_pull'],
      positiveReason: 'Seu foco recente parece bom.',
      negativeReason: 'Seu foco recente parece prejudicado.',
      positiveAction: 'Continue protegendo o básico que sustenta sua atenção.',
      negativeAction:
          'Vale reduzir bagunça digital e proteger melhor sono e rotina.',
      details: 'Base direta do check-in sobre foco.',
      onAreaUpdated: onAreaUpdated,
    );

    final assessment = await _buildCompositeAssessment(
      direct: direct,
      weighted: [
        (await _safe(getComputedAssessment, 'body_health', 'sleep'), 0.14),
        (await _safe(getComputedAssessment, 'work_vocation', 'routine'), 0.14),
        (
          await _safe(getComputedAssessment, 'work_vocation', 'consistency'),
          0.10,
        ),
        (
          await _safe(getComputedAssessment, 'digital_tech', 'screen_time'),
          0.12,
        ),
        (await _safe(getComputedAssessment, 'digital_tech', 'night_use'), 0.10),
      ],
      directWeight: 0.55,
      positiveReason:
          'Seu foco recente ficou sustentado por bons sinais de base.',
      negativeReason:
          'Seu foco caiu junto com sono, rotina ou bagunça digital.',
      positiveAction: 'Mantenha a base de sono, rotina e controle digital.',
      negativeAction:
          'Foco costuma piorar quando noite, tela e rotina desorganizam juntos.',
      details:
          'Esta subárea combina pergunta direta de foco com sono, rotina, consistência e sinais digitais.',
      onAreaUpdated: onAreaUpdated,
    );

    return _applyBonus(
      assessment,
      bonus:
          await _bonusFromKey('app_usage_focus_score', 10) +
          await _bonusFromKey('app_usage_study_score', 6),
      detailsAppend:
          'Apps úteis de foco/estudo podem reforçar levemente esta subárea.',
    );
  }

  Future<AreaAssessment?> _computedMentalLoad({
    required ComputedAssessmentGetter getComputedAssessment,
    required Future<void> Function(String areaId) onAreaUpdated,
  }) async {
    final direct = await _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'mind_emotion',
      day: DateTime.now(),
      questionIds: const ['mental_pressure', 'recovery_after_hit'],
      positiveReason: 'Sua carga mental recente parece administrável.',
      negativeReason: 'Sua carga mental recente parece pesada.',
      positiveAction: 'Continue protegendo recuperação e ritmo do dia.',
      negativeAction:
          'Vale aliviar pressão e observar onde sua cabeça está sendo mais puxada.',
      details: 'Base direta do check-in sobre pressão e recuperação.',
      estimated: true,
      onAreaUpdated: onAreaUpdated,
    );

    final assessment = await _buildCompositeAssessment(
      direct: direct,
      weighted: [
        (await _safe(getComputedAssessment, 'body_health', 'sleep'), 0.12),
        (await _safe(getComputedAssessment, 'work_vocation', 'routine'), 0.10),
        (
          await _safe(getComputedAssessment, 'finance_material', 'budget'),
          0.10,
        ),
        (
          await _safe(
            getComputedAssessment,
            'relations_community',
            'social_contact',
          ),
          0.08,
        ),
        (await _safe(getComputedAssessment, 'digital_tech', 'night_use'), 0.06),
      ],
      directWeight: 0.54,
      positiveReason: 'Sua carga mental recente parece mais controlada.',
      negativeReason: 'Sua cabeça parece mais pesada no recorte recente.',
      positiveAction: 'Continue protegendo recuperação, sono e ritmo do dia.',
      negativeAction:
          'Vale aliviar pressão acumulada e observar os pontos que mais drenam sua mente.',
      details:
          'Sobrecarga mental usa pergunta diária e sinais indiretos como sono, rotina, pressão financeira, social e uso noturno.',
      onAreaUpdated: onAreaUpdated,
      fallbackSource: AreaDataSource.estimated,
    );

    return _applyBonus(
      assessment,
      bonus:
          await _bonusFromKey('app_usage_meditation_score', 8) +
          await _bonusFromKey('app_usage_focus_score', 4),
      detailsAppend:
          'Apps de meditação/foco podem aliviar levemente a leitura desta subárea.',
    );
  }

  Future<AreaAssessment?> _applyBonus(
    AreaAssessment? assessment, {
    required int bonus,
    required String detailsAppend,
  }) async {
    if (assessment == null || bonus <= 0) return assessment;
    final score = ((assessment.score ?? 0) + bonus).clamp(0, 100);
    return AreaAssessment(
      status: _statusFromScore(score),
      score: score,
      reason: assessment.reason,
      source: assessment.source,
      lastUpdatedAt: assessment.lastUpdatedAt,
      recommendedAction: assessment.recommendedAction,
      details: '${assessment.details ?? ''}\n\n$detailsAppend',
    );
  }

  Future<AreaAssessment?> _buildCompositeAssessment({
    required AreaAssessment? direct,
    required List<(AreaAssessment?, double)> weighted,
    required double directWeight,
    required String positiveReason,
    required String negativeReason,
    required String positiveAction,
    required String negativeAction,
    required String details,
    required Future<void> Function(String areaId) onAreaUpdated,
    AreaDataSource fallbackSource = AreaDataSource.mixed,
  }) async {
    final blended = _blendScores(
      direct,
      weighted: weighted,
      directWeight: directWeight,
    );
    if (blended == null) return direct;

    final now = DateTime.now();
    final daysSinceUpdate = now
        .difference(direct?.lastUpdatedAt ?? now)
        .inDays
        .clamp(0, 365);

    final filledCount =
        (direct?.score != null ? 1 : 0) +
        weighted.where((e) => e.$1?.score != null).length;
    final expectedCount = 1 + weighted.length;

    final consistencyScores = <int>[
      if (direct?.score != null) direct!.score!,
      for (final pair in weighted)
        if (pair.$1?.score != null) pair.$1!.score!,
    ];

    final source = _resolveSource(
      direct,
      hasIndirect: true,
      fallback: fallbackSource,
    );

    final finalScore = _confidence.effectiveScore(
      rawScore: blended,
      source: source,
      daysSinceUpdate: daysSinceUpdate,
      consistency01: _confidence.consistencyFromHistory(consistencyScores),
      completeness01: _confidence.completenessFromCounts(
        filledCount: filledCount,
        expectedCount: expectedCount,
      ),
    );

    await onAreaUpdated('mind_emotion');

    return AreaAssessment(
      status: _statusFromScore(finalScore),
      score: finalScore,
      reason: finalScore >= 65 ? positiveReason : negativeReason,
      source: source,
      lastUpdatedAt: direct?.lastUpdatedAt ?? now,
      recommendedAction: finalScore >= 65 ? positiveAction : negativeAction,
      details:
          '$details\n\n'
          'Base usada: $filledCount de $expectedCount sinais disponíveis. '
          'Score combinado bruto: $blended/100. '
          'Score final com confiança: $finalScore/100.',
    );
  }

  Future<AreaAssessment?> _safe(
    ComputedAssessmentGetter getter,
    String areaId,
    String itemId,
  ) async {
    try {
      return await getter(areaId, itemId);
    } catch (_) {
      return null;
    }
  }

  int? _blendScores(
    AreaAssessment? direct, {
    required List<(AreaAssessment?, double)> weighted,
    required double directWeight,
  }) {
    double sum = 0;
    double total = 0;

    if (direct?.score != null) {
      sum += direct!.score! * directWeight;
      total += directWeight;
    }

    for (final pair in weighted) {
      final assessment = pair.$1;
      final weight = pair.$2;
      final score = assessment?.score;
      if (score == null) continue;
      sum += score * weight;
      total += weight;
    }

    if (total <= 0) return null;
    return (sum / total).round().clamp(0, 100);
  }

  AreaDataSource _resolveSource(
    AreaAssessment? direct, {
    required bool hasIndirect,
    AreaDataSource fallback = AreaDataSource.mixed,
  }) {
    if (direct == null && hasIndirect) return fallback;
    if (direct != null && hasIndirect) return AreaDataSource.mixed;
    if (direct != null) return direct.source;
    return fallback;
  }

  AreaStatus _statusFromScore(int score) {
    if (score >= 85) return AreaStatus.excellent;
    if (score >= 70) return AreaStatus.good;
    if (score >= 50) return AreaStatus.medium;
    if (score >= 25) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}
