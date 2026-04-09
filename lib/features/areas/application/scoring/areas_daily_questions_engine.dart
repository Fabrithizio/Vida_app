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

    final score = weightedScaledHistoryScore(history);
    final status = _statusFromNumericScore(score);
    final trend = trendFromScaledHistory(history);
    final latestValue = history.first.value;
    final averageValue =
        history.map((e) => e.value).reduce((a, b) => a + b) / history.length;
    final lastAnsweredAt = history.first.date;
    final daysSinceLast = DateTime.now().difference(lastAnsweredAt).inDays;

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

    return AreaAssessment(
      status: status,
      score: score,
      reason: positive ? copy.positiveReason : copy.negativeReason,
      source: _isEstimatedTarget(areaId, itemId)
          ? AreaDataSource.estimated
          : AreaDataSource.dailyQuestions,
      lastUpdatedAt: lastAnsweredAt,
      recommendedAction: positive ? copy.positiveAction : copy.negativeAction,
      details:
          '${copy.details}\n\nHistórico usado: ${history.length} registros nos últimos ${DailyCheckinService.historyDays} dias. Média recente: ${averageValue.toStringAsFixed(0)}/100. $trendSentence $staleSentence',
    );
  }

  bool _shouldSkipGenericDaily(String areaId, String itemId) {
    if (areaId == 'finance_material') return true;
    if (areaId == 'environment_home') return true;
    if (areaId == 'purpose_values') return true;
    if (areaId == 'body_health' &&
        (itemId == 'checkups' || itemId == 'women_cycle')) {
      return true;
    }
    if (areaId == 'digital_tech' &&
        (itemId == 'screen_time' ||
            itemId == 'social_media' ||
            itemId == 'night_use')) {
      return true;
    }
    return false;
  }

  bool _isEstimatedTarget(String areaId, String itemId) {
    final key = '$areaId.$itemId';
    return const {
      'mind_emotion.mental_load',
      'work_vocation.output',
      'work_vocation.balance',
      'learning_intellect.courses',
      'learning_intellect.reading',
      'learning_intellect.skills',
      'learning_intellect.review_practice',
      'relations_community.family',
      'relations_community.friends',
      'relations_community.partner',
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
        ? 'Último registro: hoje.'
        : daysSinceLast == 1
        ? 'Último registro: ontem.'
        : 'Último registro: há $daysSinceLast dias.';

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
    'body_health.sleep': _DailyItemCopy(
      label: 'sono',
      positiveReason: 'Seus sinais recentes de sono estão bons.',
      negativeReason: 'Seus sinais recentes de sono estão abaixo do ideal.',
      positiveAction:
          'Continue protegendo seu horário e seu ritual de descanso.',
      negativeAction:
          'Vale melhorar o horário, o ambiente e a constância do descanso.',
      details:
          'Calculado pelas respostas recentes ligadas a sono e recuperação física.',
    ),
    'body_health.energy': _DailyItemCopy(
      label: 'energia',
      positiveReason: 'Seus sinais recentes de energia estão bons.',
      negativeReason: 'Seus sinais recentes de energia estão abaixo do ideal.',
      positiveAction: 'Continue repetindo o que está sustentando sua energia.',
      negativeAction:
          'Vale observar sono, alimentação, hidratação e ritmo do dia.',
      details:
          'Calculado pelas respostas recentes ligadas a sono, energia e corpo.',
    ),
    'body_health.movement': _DailyItemCopy(
      label: 'movimento',
      positiveReason: 'Seu movimento recente está em bom nível.',
      negativeReason: 'Seu movimento recente está abaixo do ideal.',
      positiveAction: 'Ótimo. Vale manter esse ritmo.',
      negativeAction:
          'Tente encaixar caminhada, alongamento ou treino leve com mais constância.',
      details:
          'Calculado pelas respostas recentes ligadas a movimento e disposição corporal.',
    ),
    'body_health.nutrition': _DailyItemCopy(
      label: 'alimentação',
      positiveReason: 'Seu cuidado recente com alimentação está bom.',
      negativeReason: 'Seu cuidado recente com alimentação precisa melhorar.',
      positiveAction:
          'Continue reforçando refeições melhores e mais consistentes.',
      negativeAction: 'Vale simplificar e melhorar o básico das refeições.',
      details:
          'Calculado pelas respostas recentes ligadas a alimentação e hidratação.',
    ),
    'body_health.hydration': _DailyItemCopy(
      label: 'hidratação',
      positiveReason: 'Sua hidratação recente está em bom nível.',
      negativeReason: 'Sua hidratação recente está abaixo do ideal.',
      positiveAction: 'Continue protegendo esse cuidado simples e importante.',
      negativeAction: 'Vale aumentar a constância da água ao longo do dia.',
      details:
          'Calculado pelas respostas recentes ligadas ao cuidado com água.',
    ),
    'mind_emotion.mood': _DailyItemCopy(
      label: 'humor',
      positiveReason: 'Seu humor recente parece mais equilibrado.',
      negativeReason: 'Seu humor recente mostra oscilação ou queda.',
      positiveAction: 'Continue protegendo o que tem feito bem para você.',
      negativeAction:
          'Vale observar o que tem te desgastado e reforçar momentos de recuperação.',
      details:
          'Calculado pelas respostas recentes ligadas a humor, relação consigo e recuperação.',
    ),
    'mind_emotion.stress': _DailyItemCopy(
      label: 'estresse',
      positiveReason: 'Seu estresse recente parece mais controlado.',
      negativeReason: 'Seu estresse recente está acima do ideal.',
      positiveAction: 'Continue preservando seus limites e respiros.',
      negativeAction: 'Vale aliviar pressão e simplificar o dia quando der.',
      details:
          'Calculado pelas respostas recentes ligadas a estresse, carga mental e pressão financeira.',
    ),
    'mind_emotion.focus': _DailyItemCopy(
      label: 'foco',
      positiveReason: 'Seu foco recente está em bom nível.',
      negativeReason: 'Seu foco recente ficou abaixo do ideal.',
      positiveAction: 'Continue repetindo as condições que favorecem seu foco.',
      negativeAction:
          'Vale reduzir distrações e deixar mais claro o que era prioridade.',
      details:
          'Calculado pelas respostas recentes ligadas a foco, distrações e execução.',
    ),
    'mind_emotion.mental_load': _DailyItemCopy(
      label: 'carga mental',
      positiveReason: 'Sua carga mental recente parece mais leve e controlada.',
      negativeReason: 'Sua carga mental recente parece pesada.',
      positiveAction: 'Continue preservando pausas, limites e recuperação.',
      negativeAction: 'Vale reduzir peso desnecessário e criar mais respiros.',
      details:
          'Calculado pelas respostas recentes ligadas a estresse, mente e recuperação.',
    ),
    'work_vocation.routine': _DailyItemCopy(
      label: 'rotina',
      positiveReason: 'Sua rotina recente está mais organizada.',
      negativeReason: 'Sua rotina recente está desorganizada.',
      positiveAction: 'Continue repetindo o básico que está funcionando.',
      negativeAction:
          'Vale definir menos prioridades e organizar melhor o essencial.',
      details:
          'Calculado pelas respostas recentes ligadas a organização, plano e execução.',
    ),
    'work_vocation.consistency': _DailyItemCopy(
      label: 'constância',
      positiveReason: 'Sua constância recente está boa.',
      negativeReason: 'Sua constância recente caiu.',
      positiveAction: 'Continue aparecendo e fazendo o básico.',
      negativeAction: 'Vale reduzir atritos e retomar o ritmo aos poucos.',
      details:
          'Calculado pelas respostas recentes ligadas a organização, plano e procrastinação.',
    ),
    'work_vocation.output': _DailyItemCopy(
      label: 'entrega',
      positiveReason: 'Sua sensação recente de entrega e avanço está boa.',
      negativeReason: 'Sua sensação recente de entrega ficou abaixo do ideal.',
      positiveAction: 'Continue protegendo foco e execução do que importa.',
      negativeAction:
          'Vale reduzir dispersão e priorizar menos coisas por vez.',
      details:
          'Estimado pelos sinais recentes de foco, tarefas importantes, rendimento e distração.',
    ),
    'work_vocation.balance': _DailyItemCopy(
      label: 'equilíbrio',
      positiveReason:
          'Seu equilíbrio recente entre pressão e energia está bom.',
      negativeReason:
          'Seu equilíbrio recente entre pressão e energia ficou frágil.',
      positiveAction: 'Continue protegendo um ritmo sustentável.',
      negativeAction:
          'Vale aliviar pressão e recuperar energia antes de piorar.',
      details:
          'Estimado pelos sinais recentes de estresse, energia, mente e celular.',
    ),
    'learning_intellect.study': _DailyItemCopy(
      label: 'estudo',
      positiveReason: 'Seu estudo recente está em bom ritmo.',
      negativeReason: 'Seu estudo recente está abaixo do ideal.',
      positiveAction: 'Continue fortalecendo essa constância.',
      negativeAction: 'Vale encaixar blocos curtos com mais qualidade.',
      details:
          'Calculado pelas respostas recentes ligadas a aprendizado e atenção ao crescimento.',
    ),
    'learning_intellect.courses': _DailyItemCopy(
      label: 'cursos',
      positiveReason: 'Seu avanço recente em trilhas e cursos parece bom.',
      negativeReason: 'Seu avanço recente em trilhas e cursos parece lento.',
      positiveAction: 'Continue acumulando progresso, mesmo em blocos curtos.',
      negativeAction: 'Vale retomar uma trilha principal e reduzir dispersão.',
      details: 'Estimado pelos sinais recentes de estudo e pequenos avanços.',
    ),
    'learning_intellect.reading': _DailyItemCopy(
      label: 'leitura',
      positiveReason: 'Seu contato recente com conteúdo útil parece bom.',
      negativeReason:
          'Seu contato recente com conteúdo útil ficou abaixo do ideal.',
      positiveAction:
          'Continue criando momentos curtos de leitura com presença.',
      negativeAction: 'Vale separar um bloco curto para ler algo de valor.',
      details: 'Estimado pelos sinais recentes de uso da mente, foco e estudo.',
    ),
    'learning_intellect.skills': _DailyItemCopy(
      label: 'habilidades',
      positiveReason:
          'Seu desenvolvimento recente de habilidades está em bom ritmo.',
      negativeReason:
          'Seu desenvolvimento recente de habilidades está abaixo do ideal.',
      positiveAction: 'Continue praticando o que gera evolução real.',
      negativeAction: 'Vale simplificar o foco e repetir mais o que importa.',
      details:
          'Estimado pelos sinais recentes de crescimento, estudo e uso da mente.',
    ),
    'learning_intellect.review_practice': _DailyItemCopy(
      label: 'revisão e prática',
      positiveReason:
          'Sua aplicação prática recente do que aprende parece boa.',
      negativeReason:
          'Sua aplicação prática recente do que aprende está fraca.',
      positiveAction: 'Continue revisando e praticando com frequência.',
      negativeAction: 'Vale revisar menos coisa e praticar mais o essencial.',
      details:
          'Estimado pelos sinais recentes de crescimento e pequenos avanços.',
    ),
    'relations_community.family': _DailyItemCopy(
      label: 'família',
      positiveReason: 'Seu vínculo recente com a família parece mais presente.',
      negativeReason: 'Seu vínculo recente com a família parece mais distante.',
      positiveAction: 'Continue cuidando do contato e da presença.',
      negativeAction:
          'Vale retomar um contato simples e direto com alguém importante.',
      details:
          'Estimado pelos sinais recentes de conexão, presença e apoio nas relações.',
    ),
    'relations_community.friends': _DailyItemCopy(
      label: 'amizades',
      positiveReason: 'Sua presença recente com amizades parece boa.',
      negativeReason:
          'Sua presença recente com amizades parece abaixo do ideal.',
      positiveAction: 'Continue protegendo amizades que te fazem bem.',
      negativeAction:
          'Vale puxar conversa ou retomar contato com alguém importante.',
      details:
          'Estimado pelos sinais recentes de conexão, presença e apoio nas relações.',
    ),
    'relations_community.partner': _DailyItemCopy(
      label: 'relacionamento',
      positiveReason:
          'Seu vínculo afetivo recente parece mais presente e estável.',
      negativeReason:
          'Seu vínculo afetivo recente parece mais distante ou frágil.',
      positiveAction:
          'Continue protegendo presença, diálogo e pequenos cuidados.',
      negativeAction:
          'Vale retomar presença, conversa honesta e gestos simples de cuidado.',
      details:
          'Estimado pelos sinais recentes de conexão, convivência e apoio nas relações.',
    ),
    'relations_community.social_contact': _DailyItemCopy(
      label: 'contato social',
      positiveReason: 'Sua conexão social recente está boa.',
      negativeReason: 'Sua conexão social recente ficou abaixo do ideal.',
      positiveAction: 'Continue cuidando dessas conexões.',
      negativeAction: 'Vale retomar contato com alguém importante.',
      details:
          'Calculado pelas respostas recentes ligadas a conexão, presença e apoio social.',
    ),
    'digital_tech.distraction': _DailyItemCopy(
      label: 'distrações digitais',
      positiveReason:
          'As distrações digitais recentes parecem mais controladas.',
      negativeReason:
          'As distrações digitais recentes parecem estar atrapalhando.',
      positiveAction: 'Continue protegendo seu foco no digital.',
      negativeAction:
          'Vale reduzir notificações e limitar janelas de distração.',
      details:
          'Calculado pelas respostas recentes ligadas a celular, foco e distrações.',
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
