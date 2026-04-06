import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';

class AreasDailyQuestionsEngine {
  AreasDailyQuestionsEngine({DailyCheckinService? dailyCheckinService})
    : _dailyCheckinService = dailyCheckinService ?? DailyCheckinService();

  final DailyCheckinService _dailyCheckinService;

  Future<AreaAssessment?> computedDailyQuestionItem(
    String areaId,
    String itemId, {
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    final today = DateTime.now();

    if (areaId == 'body_health' && itemId == 'energy') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['energy_ok', 'sleep_ok'],
        positiveReason: 'Sua energia recente está em um nível bom.',
        negativeReason: 'Sua energia recente está abaixo do ideal.',
        positiveAction: 'Tente manter o que está ajudando sua energia.',
        negativeAction:
            'Vale observar sono, alimentação, descanso e ritmo do dia.',
        details:
            'Estimado a partir das respostas recentes sobre energia e sono.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'body_health' && itemId == 'movement') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
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

    if (areaId == 'body_health' && itemId == 'nutrition') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['nutrition_ok', 'hydration_ok'],
        positiveReason: 'Seu cuidado recente com alimentação está bom.',
        negativeReason: 'Seu cuidado recente com alimentação precisa melhorar.',
        positiveAction: 'Continue reforçando bons hábitos.',
        negativeAction:
            'Tente melhorar a qualidade das refeições e da hidratação.',
        details:
            'Baseado nas respostas recentes sobre alimentação e hidratação.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'body_health' && itemId == 'hydration') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['hydration_ok'],
        positiveReason: 'Sua hidratação recente está em um bom nível.',
        negativeReason: 'Sua hidratação recente ficou abaixo do ideal.',
        positiveAction:
            'Continue protegendo esse cuidado básico ao longo do dia.',
        negativeAction:
            'Vale aumentar a constância da hidratação ao longo do dia.',
        details:
            'Baseado nas respostas recentes sobre hidratação no check-in diário.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'mood') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['mood_ok', 'mental_recovery'],
        positiveReason: 'Seu humor recente parece mais equilibrado.',
        negativeReason: 'Seu humor recente mostra oscilação ou queda.',
        positiveAction:
            'Mantenha os hábitos que estão ajudando seu equilíbrio.',
        negativeAction:
            'Observe gatilhos e proteja melhor seus momentos de recuperação.',
        details:
            'Baseado nas respostas recentes sobre humor e recuperação mental.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'stress') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['stress_ok', 'mental_recovery'],
        positiveReason: 'Seu estresse recente parece bem controlado.',
        negativeReason: 'Seu estresse recente está acima do ideal.',
        positiveAction: 'Continue protegendo seu equilíbrio.',
        negativeAction: 'Vale reduzir pressão, rever carga e criar pausas.',
        details:
            'Baseado nas respostas recentes sobre estresse e recuperação mental.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'focus') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['focus', 'study_quality'],
        positiveReason: 'Seu foco recente está em um bom nível.',
        negativeReason: 'Seu foco recente ficou abaixo do ideal.',
        positiveAction: 'Repita as condições que favoreceram esse foco.',
        negativeAction: 'Vale simplificar a rotina e reduzir distrações.',
        details:
            'Baseado nas respostas recentes sobre foco e qualidade de estudo.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'mental_load') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['stress_ok', 'mental_recovery'],
        positiveReason: 'Sua carga mental recente parece mais controlada.',
        negativeReason: 'Sua carga mental recente parece pesada.',
        positiveAction: 'Continue preservando pausas e limites.',
        negativeAction:
            'Vale aliviar demandas e criar mais respiros ao longo do dia.',
        details:
            'Estimado a partir das respostas recentes sobre estresse e recuperação mental.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'work_vocation' && itemId == 'routine') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['routine_ok', 'day_planning'],
        positiveReason: 'Sua rotina recente está mais organizada.',
        negativeReason: 'Sua rotina recente está desorganizada.',
        positiveAction: 'Continue repetindo esse padrão.',
        negativeAction:
            'Tente definir menos prioridades e organizar melhor o básico.',
        details:
            'Baseado nas respostas recentes sobre rotina e execução do planejamento.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'work_vocation' && itemId == 'consistency') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['routine_ok', 'day_planning'],
        positiveReason: 'Sua consistência recente está boa.',
        negativeReason: 'Sua consistência recente caiu.',
        positiveAction: 'Continue aparecendo e executando o básico.',
        negativeAction: 'Reduza atritos e retome o ritmo aos poucos.',
        details: 'Baseado nas respostas recentes sobre constância da rotina.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'work_vocation' && itemId == 'output') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['day_planning', 'focus', 'routine_ok'],
        positiveReason: 'Sua sensação recente de entrega e avanço está boa.',
        negativeReason:
            'Sua sensação recente de entrega ficou abaixo do ideal.',
        positiveAction: 'Continue protegendo foco e execução do que importa.',
        negativeAction:
            'Vale reduzir dispersão e priorizar menos coisas por vez.',
        details:
            'Estimado a partir das respostas recentes sobre planejamento, foco e ritmo da rotina.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'work_vocation' && itemId == 'balance') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['routine_ok', 'stress_ok', 'mental_recovery'],
        positiveReason:
            'Seu equilíbrio recente entre pressão e recuperação está bom.',
        negativeReason:
            'Seu equilíbrio recente entre pressão e recuperação ficou frágil.',
        positiveAction:
            'Continue protegendo pausas, limites e um ritmo sustentável.',
        negativeAction:
            'Vale aliviar pressão e reorganizar a rotina antes de piorar.',
        details:
            'Estimado pelas respostas recentes sobre rotina, estresse e recuperação mental.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'study') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['study_ok', 'study_quality'],
        positiveReason: 'Seu estudo recente está em um bom ritmo.',
        negativeReason: 'Seu estudo recente está abaixo do ideal.',
        positiveAction: 'Continue fortalecendo essa constância.',
        negativeAction: 'Tente encaixar sessões curtas com mais qualidade.',
        details: 'Baseado nas respostas recentes sobre estudo.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'courses') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['study_ok', 'study_quality', 'routine_ok'],
        positiveReason: 'Seu progresso recente em trilhas e cursos parece bom.',
        negativeReason:
            'Seu progresso recente em trilhas e cursos parece lento.',
        positiveAction:
            'Continue acumulando avanço frequente, mesmo que em blocos curtos.',
        negativeAction:
            'Vale retomar uma trilha principal e reduzir dispersão.',
        details:
            'Estimado a partir da constância de estudo, da qualidade percebida e do ritmo da rotina.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'reading') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['study_quality', 'focus'],
        positiveReason:
            'Seu contato recente com conteúdo de qualidade parece bom.',
        negativeReason:
            'Seu contato recente com conteúdo de qualidade ficou abaixo do ideal.',
        positiveAction:
            'Continue criando momentos de leitura ou estudo com mais presença.',
        negativeAction:
            'Vale reservar blocos curtos para leitura com menos distração.',
        details:
            'Estimado pelos sinais recentes de foco e qualidade do estudo, como aproximação de leitura útil.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'skills') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['study_quality', 'focus', 'routine_ok'],
        positiveReason:
            'Seu desenvolvimento recente de habilidades está em bom ritmo.',
        negativeReason:
            'Seu desenvolvimento recente de habilidades está abaixo do ideal.',
        positiveAction: 'Continue praticando o que gera evolução real.',
        negativeAction: 'Vale simplificar o foco e repetir mais o que importa.',
        details:
            'Estimado a partir da qualidade do estudo, do foco e da consistência da rotina.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'review_practice') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['study_ok', 'study_quality', 'focus'],
        positiveReason:
            'Sua aplicação prática recente do que aprende parece boa.',
        negativeReason:
            'Sua aplicação prática recente do que aprende está fraca.',
        positiveAction:
            'Continue revisando e praticando em blocos curtos e frequentes.',
        negativeAction:
            'Vale revisar menos conteúdo e praticar mais o essencial.',
        details:
            'Estimado pela combinação entre constância, qualidade do estudo e foco recente.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'relations_community' && itemId == 'family') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['social_ok', 'social_presence', 'mood_ok'],
        positiveReason:
            'Seu vínculo recente com a família parece mais presente.',
        negativeReason:
            'Seu vínculo recente com a família parece mais distante.',
        positiveAction:
            'Continue cuidando do contato e da presença nas relações importantes.',
        negativeAction:
            'Vale retomar um contato simples e direto com alguém da família.',
        details:
            'Estimado pelos sinais recentes de presença social, contato e estado emocional.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'relations_community' && itemId == 'friends') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['social_ok', 'social_presence', 'mood_ok'],
        positiveReason: 'Sua presença recente com amizades parece boa.',
        negativeReason:
            'Sua presença recente com amizades parece abaixo do ideal.',
        positiveAction: 'Continue protegendo amizades que te fazem bem.',
        negativeAction:
            'Vale puxar conversa ou retomar contato com alguém importante.',
        details:
            'Estimado pelos sinais recentes de conexão social, presença e estado emocional.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'relations_community' && itemId == 'partner') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['social_ok', 'social_presence', 'mood_ok'],
        positiveReason:
            'Seu vínculo afetivo recente parece mais presente e estável.',
        negativeReason:
            'Seu vínculo afetivo recente parece mais distante ou frágil.',
        positiveAction:
            'Continue protegendo presença, diálogo e cuidado no relacionamento.',
        negativeAction:
            'Vale retomar presença, conversa honesta e pequenos gestos de cuidado.',
        details:
            'Estimado de forma leve pelos sinais recentes de conexão social, presença e estado emocional.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'relations_community' && itemId == 'social_contact') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['social_ok', 'social_presence'],
        positiveReason: 'Sua conexão social recente está boa.',
        negativeReason: 'Sua conexão social recente ficou abaixo do ideal.',
        positiveAction: 'Continue cuidando dessas conexões.',
        negativeAction: 'Vale retomar contato com alguém importante.',
        details:
            'Baseado nas respostas recentes sobre presença e conexão social.',
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (areaId == 'digital_tech' && itemId == 'distraction') {
      return assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['focus', 'digital_balance'],
        positiveReason:
            'As distrações digitais recentes parecem mais controladas.',
        negativeReason:
            'As distrações digitais recentes parecem estar atrapalhando.',
        positiveAction: 'Continue protegendo seu foco.',
        negativeAction:
            'Vale reduzir notificações e limitar janelas de distração.',
        details:
            'Estimado a partir das respostas recentes sobre foco e controle digital.',
        estimated: true,
        onAreaUpdated: onAreaUpdated,
      );
    }

    return null;
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

    final score = weightedScaledHistoryScore(history);
    final status = _statusFromNumericScore(score);
    final trend = trendFromScaledHistory(history);
    final lastAnsweredAt = history.first.date;
    final daysSinceLast = day.difference(lastAnsweredAt).inDays;
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
        ? 'Você registrou essa subárea hoje.'
        : daysSinceLast == 1
        ? 'Último registro foi ontem.'
        : 'Último registro foi há $daysSinceLast dias.';

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: estimated
          ? AreaDataSource.estimated
          : AreaDataSource.dailyQuestions,
      lastUpdatedAt: lastAnsweredAt,
      recommendedAction: action,
      details:
          '$details\n\nHistórico usado: $total registros nos últimos ${DailyCheckinService.historyDays} dias. Média recente: ${averageValue.toStringAsFixed(0)}/100. $trendSentence $staleSentence',
    );
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

        values.add((stored / DailyCheckinService.maxAnswerValue) * 100.0);
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

    final lastGap = DateTime.now().difference(history.first.date).inDays;
    if (lastGap > 3) {
      final penalty = ((lastGap - 3) * 4).clamp(0, 24);
      score -= penalty.toDouble();
    }

    if (history.length < 3) {
      score -= (3 - history.length) * 6;
    }

    return score.round().clamp(0, 100);
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

  AreaStatus _statusFromNumericScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}

class DailyScaledPoint {
  const DailyScaledPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}
