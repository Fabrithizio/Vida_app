// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// O que faz:
// - Salva avaliações das áreas por usuário no Hive
// - Calcula itens dinamicamente com base em SharedPreferences
// - Conecta a área "Finanças & Material" ao módulo real de Finanças
// - Usa respostas do check-in diário para alimentar áreas do painel
// - Liga Ambiente & Casa às tarefas reais da casa
// - Liga Hábitos & Constância a sinais reais de rotina, constância e recuperação
//
// Nesta versão:
// - income     -> vem das entradas reais do mês atual no módulo Finanças
// - spending   -> vem das saídas reais do mês atual no módulo Finanças
//                  e usa apoio do check-in diário quando necessário
// - budget     -> usa gasto real + orçamento manual
// - debts      -> manual por enquanto
// - savings    -> manual por enquanto
// - goals_fin  -> manual por enquanto
// - energy, movement, nutrition, mood, stress, focus
//   -> passam a vir do check-in diário
// - organization e cleaning
//   -> passam a vir automaticamente das tarefas reais da casa
// - direction, goals_review e gratitude
//   -> passam a vir automaticamente de rotina, constância, recuperação e base do ambiente
//
// Atualizações desta revisão:
// - remove duplicações do sistema antigo de daily check-in
// - mantém o cálculo novo com histórico escalonado
// - corrige helpers internos para o modelo atual do DailyCheckinService
// - preserva o layout e a estrutura geral do app
//
// Correção importante:
// - _spendingAssessmentFromDailyCheckin agora é async (retorna Future)
//   e o fallback é resolvido dentro de _computedFinanceItem (async),
//   evitando o erro de tipo Future<AreaAssessment?> vs AreaAssessment?.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/finance/data/repositories/hive_finance_repository.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';

class AreasStore {
  AreasStore({FinanceRepository? financeRepository})
    : _financeRepository = financeRepository ?? HiveFinanceRepository();

  static const String _boxPrefix = 'areas_box_';

  final FinanceRepository _financeRepository;
  final DailyCheckinService _dailyCheckinService = DailyCheckinService();

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> _open() async {
    final uid = _uidOrAnon();
    return Hive.openBox<dynamic>('$_boxPrefix$uid');
  }

  String _key(String areaId, String itemId) => '$areaId::$itemId';

  String _areaUpdatedPrefKey(String uid, String areaId) =>
      '$uid:area_updated:$areaId';

  Future<void> ensureBootstrappedFromOnboarding() async {
    final box = await _open();
    if (box.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    Future<void> seed(
      String areaId,
      String itemId,
      AreaStatus status, {
      String? reason,
      int? score,
      AreaDataSource source = AreaDataSource.onboarding,
    }) async {
      await box.put(
        _key(areaId, itemId),
        AreaAssessment(
          status: status,
          score: score,
          reason: reason,
          source: source,
          lastUpdatedAt: DateTime.now(),
        ).toMap(),
      );
      await prefs.setString(
        _areaUpdatedPrefKey(uid, areaId),
        DateTime.now().toIso8601String(),
      );
    }

    final focus = (prefs.getString('$uid:focus') ?? '').trim();

    if (focus == 'Saúde') {
      await seed(
        'body_health',
        'nutrition',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
      await seed(
        'body_health',
        'movement',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Finanças') {
      await seed(
        'finance_material',
        'budget',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Produtividade') {
      await seed(
        'work_vocation',
        'routine',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Mental') {
      await seed(
        'mind_emotion',
        'mood',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Relacionamentos') {
      await seed(
        'relations_community',
        'friends',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
      await seed(
        'relations_community',
        'family',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    }
  }

  Future<AreaAssessment?> getComputedAssessment(
    String areaId,
    String itemId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return getAssessment(areaId, itemId);
    }

    final dailyAssessment = await _computedDailyQuestionItem(areaId, itemId);
    if (dailyAssessment != null) {
      return dailyAssessment;
    }

    if (areaId == 'body_health' && itemId == 'checkups') {
      return _computedCheckups(user.uid);
    }

    if (areaId == 'body_health' && itemId == 'sleep') {
      return _computedSleep(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'screen_time') {
      return _computedScreenTime(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'social_media') {
      return _computedSocialMedia(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'night_use') {
      return _computedNightUse(user.uid);
    }

    if (areaId == 'body_health' && itemId == 'women_cycle') {
      return _computedWomenCycle(user.uid);
    }

    if (areaId == 'purpose_values') {
      return _computedPurposeValuesItem(user.uid, itemId);
    }

    if (areaId == 'environment_home') {
      return _computedEnvironmentItem(user.uid, itemId);
    }

    if (areaId == 'finance_material') {
      return _computedFinanceItem(user.uid, itemId);
    }

    return getAssessment(areaId, itemId);
  }

  Future<AreaAssessment?> _computedDailyQuestionItem(
    String areaId,
    String itemId,
  ) async {
    final today = DateTime.now();

    if (areaId == 'body_health' && itemId == 'energy') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'body_health' && itemId == 'movement') {
      return _assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['move'],
        positiveReason: 'Seu nível recente de movimento está bom.',
        negativeReason: 'Seu nível recente de movimento está baixo.',
        positiveAction: 'Ótimo. Continue com regularidade.',
        negativeAction:
            'Vale tentar ao menos uma caminhada, treino leve ou alongamento.',
        details: 'Baseado nas respostas recentes sobre movimento.',
      );
    }

    if (areaId == 'body_health' && itemId == 'nutrition') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'body_health' && itemId == 'hydration') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'mood') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'stress') {
      return _assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['stress_ok', 'mental_recovery'],
        positiveReason: 'Seu estresse recente parece bem controlado.',
        negativeReason: 'Seu estresse recente está acima do ideal.',
        positiveAction: 'Continue protegendo seu equilíbrio.',
        negativeAction: 'Vale reduzir pressão, rever carga e criar pausas.',
        details:
            'Baseado nas respostas recentes sobre estresse e recuperação mental.',
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'focus') {
      return _assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['focus', 'study_quality'],
        positiveReason: 'Seu foco recente está em um bom nível.',
        negativeReason: 'Seu foco recente ficou abaixo do ideal.',
        positiveAction: 'Repita as condições que favoreceram esse foco.',
        negativeAction: 'Vale simplificar a rotina e reduzir distrações.',
        details:
            'Baseado nas respostas recentes sobre foco e qualidade de estudo.',
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'mental_load') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'work_vocation' && itemId == 'routine') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'work_vocation' && itemId == 'consistency') {
      return _assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['routine_ok', 'day_planning'],
        positiveReason: 'Sua consistência recente está boa.',
        negativeReason: 'Sua consistência recente caiu.',
        positiveAction: 'Continue aparecendo e executando o básico.',
        negativeAction: 'Reduza atritos e retome o ritmo aos poucos.',
        details: 'Baseado nas respostas recentes sobre constância da rotina.',
      );
    }

    if (areaId == 'work_vocation' && itemId == 'output') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'work_vocation' && itemId == 'balance') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'study') {
      return _assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['study_ok', 'study_quality'],
        positiveReason: 'Seu estudo recente está em um bom ritmo.',
        negativeReason: 'Seu estudo recente está abaixo do ideal.',
        positiveAction: 'Continue fortalecendo essa constância.',
        negativeAction: 'Tente encaixar sessões curtas com mais qualidade.',
        details: 'Baseado nas respostas recentes sobre estudo.',
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'courses') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'reading') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'skills') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'review_practice') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'relations_community' && itemId == 'family') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'relations_community' && itemId == 'friends') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    if (areaId == 'relations_community' && itemId == 'social_contact') {
      return _assessmentFromDailyQuestions(
        areaId: areaId,
        day: today,
        questionIds: const ['social_ok', 'social_presence'],
        positiveReason: 'Sua conexão social recente está boa.',
        negativeReason: 'Sua conexão social recente ficou abaixo do ideal.',
        positiveAction: 'Continue cuidando dessas conexões.',
        negativeAction: 'Vale retomar contato com alguém importante.',
        details:
            'Baseado nas respostas recentes sobre presença e conexão social.',
      );
    }

    if (areaId == 'digital_tech' && itemId == 'distraction') {
      return _assessmentFromDailyQuestions(
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
      );
    }

    return null;
  }

  Future<AreaAssessment?> _assessmentFromDailyQuestions({
    required String areaId,
    required DateTime day,
    required List<String> questionIds,
    required String positiveReason,
    required String negativeReason,
    required String positiveAction,
    required String negativeAction,
    required String details,
    bool estimated = false,
  }) async {
    final history = await _readDailyScaledHistory(
      day: day,
      questionIds: questionIds,
      days: DailyCheckinService.historyDays,
    );

    if (history.isEmpty) return null;

    final score = _weightedScaledHistoryScore(history);
    final status = _statusFromNumericScore(score);
    final trend = _trendFromScaledHistory(history);
    final lastAnsweredAt = history.first.date;
    final daysSinceLast = day.difference(lastAnsweredAt).inDays;
    final total = history.length;
    final latestValue = history.first.value;
    final averageValue =
        history.map((e) => e.value).reduce((a, b) => a + b) / total;

    await markAreaUpdated(areaId);

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

  Future<List<_DailyScaledPoint>> _readDailyScaledHistory({
    required DateTime day,
    required List<String> questionIds,
    required int days,
  }) async {
    final points = <_DailyScaledPoint>[];

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
      points.add(_DailyScaledPoint(date: date, value: avg));
    }

    return points;
  }

  int _weightedScaledHistoryScore(List<_DailyScaledPoint> history) {
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

  String _trendFromScaledHistory(List<_DailyScaledPoint> history) {
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

  AreaStatus _statusFromNumericScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }

  int _scoreFromStops(double value, List<_ScoreStop> stops) {
    if (stops.isEmpty) return 0;

    final ordered = [...stops]..sort((a, b) => a.x.compareTo(b.x));

    if (value <= ordered.first.x) {
      return ordered.first.score.clamp(0, 100);
    }

    for (var i = 1; i < ordered.length; i++) {
      final previous = ordered[i - 1];
      final current = ordered[i];

      if (value <= current.x) {
        final span = current.x - previous.x;
        if (span <= 0) return current.score.clamp(0, 100);

        final t = (value - previous.x) / span;
        final interpolated =
            previous.score + ((current.score - previous.score) * t);

        return interpolated.round().clamp(0, 100);
      }
    }

    return ordered.last.score.clamp(0, 100);
  }

  String _financeActionFromStatus({
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

  Future<AreaAssessment?> _computedPurposeValuesItem(
    String uid,
    String itemId,
  ) async {
    switch (itemId) {
      case 'direction':
        return _computedPurposeBaseline(uid);
      case 'goals_review':
        return _computedPurposeConsistency(uid);
      case 'gratitude':
        return _computedPurposeRecovery(uid);
      default:
        return getAssessment('purpose_values', itemId);
    }
  }

  Future<AreaAssessment?> _computedPurposeBaseline(String uid) async {
    final now = DateTime.now();
    final history = await _readDailyScaledHistory(
      day: now,
      questionIds: const ['routine_ok', 'day_planning', 'energy_ok'],
      days: DailyCheckinService.historyDays,
    );

    final organization = await _computedEnvironmentItem(uid, 'organization');
    final cleaning = await _computedEnvironmentItem(uid, 'cleaning');

    double weightedSum = 0;
    double totalWeight = 0;

    if (history.isNotEmpty) {
      weightedSum += _weightedScaledHistoryScore(history) * 0.60;
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
    final trend = history.isEmpty ? 'stable' : _trendFromScaledHistory(history);
    final action = _financeActionFromStatus(
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

    await markAreaUpdated('purpose_values');

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

  Future<AreaAssessment?> _computedPurposeConsistency(String uid) async {
    final now = DateTime.now();
    final history = await _readDailyScaledHistory(
      day: now,
      questionIds: const ['routine_ok', 'move', 'study_ok'],
      days: DailyCheckinService.historyDays,
    );

    if (history.isEmpty) {
      return getAssessment('purpose_values', 'goals_review');
    }

    final valueScore = _weightedScaledHistoryScore(history).toDouble();
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
    final trend = _trendFromScaledHistory(history);
    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };

    final action = _financeActionFromStatus(
      status: status,
      excellent:
          'Sua constância recente está muito boa. Continue aparecendo todos os dias.',
      good: 'Boa constância. Vale proteger esse ritmo para não cair.',
      medium: 'Sua constância está razoável, mas ainda oscila bastante.',
      poor: 'Sua constância está fraca. Retome metas menores e repetíveis.',
      critical: 'Sua constância está muito baixa. Recomece com ações mínimas.',
    );

    await markAreaUpdated('purpose_values');

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

  Future<AreaAssessment?> _computedPurposeRecovery(String uid) async {
    final now = DateTime.now();
    final history = await _readDailyScaledHistory(
      day: now,
      questionIds: const [
        'mental_recovery',
        'sleep_ok',
        'mood_ok',
        'stress_ok',
      ],
      days: DailyCheckinService.historyDays,
    );

    final sleepAssessment = await _computedSleep(uid);

    if (history.isEmpty && sleepAssessment?.score == null) {
      return getAssessment('purpose_values', 'gratitude');
    }

    double weightedSum = 0;
    double totalWeight = 0;

    if (history.isNotEmpty) {
      weightedSum += _weightedScaledHistoryScore(history) * 0.75;
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
    final trend = history.isEmpty ? 'stable' : _trendFromScaledHistory(history);
    final trendSentence = switch (trend) {
      'improving' => 'Tendência recente: melhorando.',
      'worsening' => 'Tendência recente: piorando.',
      _ => 'Tendência recente: estável.',
    };

    final action = _financeActionFromStatus(
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

    await markAreaUpdated('purpose_values');

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
          'Calculado pelos sinais recentes de recuperação mental, sono, humor e estresse. ${sleepAssessment?.score != null ? 'O sono também entra como reforço automático nessa leitura. ' : ''}$trendSentence',
    );
  }

  Future<AreaAssessment?> _computedEnvironmentItem(
    String uid,
    String itemId,
  ) async {
    if (itemId == 'organization') {
      return _computedHomeTaskCategory(
        uid: uid,
        areaId: 'environment_home',
        itemId: itemId,
        category: HomeTaskCategory.organization,
        emptyReason:
            'Ainda não há tarefas de organização registradas para medir essa subárea.',
        reasonLabel: 'organização da casa',
        details:
            'Calculado automaticamente pelas tarefas de organização da casa, considerando o quanto já foi concluído e quão recente foi esse cuidado.',
        excellentAction: 'Ótimo. Continue mantendo a organização em dia.',
        goodAction: 'Bom nível de organização. Continue sustentando o ritmo.',
        mediumAction: 'Sua organização está mediana. Vale retomar constância.',
        poorAction: 'A organização da casa está ficando para trás.',
        criticalAction: 'Organização muito baixa. Vale recomeçar pelo básico.',
        completionWeight: 0.45,
        recencyWeight: 0.25,
        freshnessWeight: 0.30,
      );
    }

    if (itemId == 'cleaning') {
      return _computedHomeTaskCategory(
        uid: uid,
        areaId: 'environment_home',
        itemId: itemId,
        category: HomeTaskCategory.cleaning,
        emptyReason:
            'Ainda não há tarefas de limpeza registradas para medir essa subárea.',
        reasonLabel: 'limpeza da casa',
        details:
            'Calculado automaticamente pelas tarefas de limpeza da casa, considerando tarefas concluídas, pendências e quão recente foi o cuidado com o ambiente.',
        excellentAction: 'Ótimo. Sua rotina de limpeza está muito bem cuidada.',
        goodAction: 'Bom ritmo de limpeza. Continue assim.',
        mediumAction:
            'Sua limpeza básica está mediana. Vale reforçar a constância.',
        poorAction: 'A rotina de limpeza está fraca no momento.',
        criticalAction:
            'A limpeza da casa está muito atrasada. Recomece pelo essencial.',
        completionWeight: 0.35,
        recencyWeight: 0.35,
        freshnessWeight: 0.30,
      );
    }

    if (itemId == 'home_tasks') {
      return _computedHomeTaskCategory(
        uid: uid,
        areaId: 'environment_home',
        itemId: itemId,
        category: HomeTaskCategory.cleaning,
        emptyReason:
            'Ainda não há tarefas domésticas registradas para medir essa subárea.',
        reasonLabel: 'pendências domésticas',
        details:
            'Calculado pelas tarefas domésticas cadastradas, olhando pendências abertas, ritmo recente e itens concluídos.',
        excellentAction:
            'Suas pendências domésticas estão muito bem controladas.',
        goodAction: 'Bom controle das pendências domésticas.',
        mediumAction: 'As pendências domésticas estão medianas no momento.',
        poorAction: 'As pendências domésticas já estão acumulando.',
        criticalAction:
            'As pendências domésticas estão bem acumuladas. Vale agir logo.',
        completionWeight: 0.30,
        recencyWeight: 0.30,
        freshnessWeight: 0.40,
      );
    }

    if (itemId == 'home_maintenance') {
      return _computedHomeTaskCategory(
        uid: uid,
        areaId: 'environment_home',
        itemId: itemId,
        category: HomeTaskCategory.maintenance,
        emptyReason:
            'Ainda não há tarefas de manutenção registradas para medir essa subárea.',
        reasonLabel: 'manutenção da casa',
        details:
            'Calculado automaticamente pelas tarefas de manutenção, considerando pendências acumuladas e a recência dos cuidados maiores com o ambiente.',
        excellentAction: 'A manutenção da casa está muito bem controlada.',
        goodAction: 'Boa situação de manutenção da casa.',
        mediumAction: 'A manutenção da casa está mediana no momento.',
        poorAction: 'A manutenção da casa está ficando para trás.',
        criticalAction:
            'A manutenção da casa está muito atrasada. Priorize os itens mais importantes.',
        completionWeight: 0.25,
        recencyWeight: 0.25,
        freshnessWeight: 0.50,
      );
    }

    return getAssessment('environment_home', itemId);
  }

  Future<AreaAssessment?> _computedHomeTaskCategory({
    required String uid,
    required String areaId,
    required String itemId,
    required HomeTaskCategory category,
    required String emptyReason,
    required String reasonLabel,
    required String details,
    required String excellentAction,
    required String goodAction,
    required String mediumAction,
    required String poorAction,
    required String criticalAction,
    required double completionWeight,
    required double recencyWeight,
    required double freshnessWeight,
  }) async {
    final store = HomeTasksStore();
    await store.load();

    final items = store.items.where((e) => e.category == category).toList();
    if (items.isEmpty) {
      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: emptyReason,
        action: 'Cadastre tarefas dessa categoria para ativar esta subárea.',
      );
    }

    final now = DateTime.now();
    final total = items.length;
    final done = items.where((e) => e.done).toList();
    final pending = items.where((e) => !e.done).toList();

    final completionRatio = done.length / total;

    final recentDone = done.where((e) {
      final updated = DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs);
      return now.difference(updated).inDays <= 7;
    }).length;
    final recentDoneRatio = recentDone / total;

    final lastDoneDate = done.isEmpty
        ? null
        : done
              .map((e) => DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs))
              .reduce((a, b) => a.isAfter(b) ? a : b);

    final freshnessScore = lastDoneDate == null
        ? 0
        : _scoreFromStops(
            now.difference(lastDoneDate).inDays.toDouble(),
            const [
              _ScoreStop(0, 100),
              _ScoreStop(2, 92),
              _ScoreStop(7, 75),
              _ScoreStop(14, 55),
              _ScoreStop(21, 35),
              _ScoreStop(30, 18),
              _ScoreStop(45, 0),
            ],
          );

    var score =
        ((completionRatio * completionWeight) +
            (recentDoneRatio * recencyWeight) +
            ((freshnessScore / 100.0) * freshnessWeight)) *
        100.0;

    if (pending.isNotEmpty) {
      final stalePending = pending.where((e) {
        final updated = DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs);
        return now.difference(updated).inDays >= 14;
      }).length;
      score -= stalePending * 4.0;
    }

    final finalScore = score.round().clamp(0, 100);
    final status = _statusFromNumericScore(finalScore);
    final action = _financeActionFromStatus(
      status: status,
      excellent: excellentAction,
      good: goodAction,
      medium: mediumAction,
      poor: poorAction,
      critical: criticalAction,
    );

    await markAreaUpdated(areaId);

    final reason =
        'Você concluiu ${done.length} de $total tarefas de $reasonLabel; '
        '$recentDone foram concluídas na última semana.';

    return AreaAssessment(
      status: status,
      score: finalScore,
      reason: reason,
      source: AreaDataSource.automatic,
      lastUpdatedAt: lastDoneDate ?? now,
      recommendedAction: action,
      details:
          '$details\n\nPendentes atuais: ${pending.length}. Última conclusão: ${_relativeDateLabel(lastDoneDate, now)}.',
    );
  }

  String _relativeDateLabel(DateTime? date, DateTime now) {
    if (date == null) return 'sem conclusão recente';
    final gap = now.difference(date).inDays;
    if (gap <= 0) return 'hoje';
    if (gap == 1) return 'ontem';
    return 'há $gap dias';
  }

  Future<AreaAssessment?> _computedFinanceItem(
    String uid,
    String itemId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = await _readFinanceSnapshot(prefs, uid);

    if (itemId == 'spending' && snapshot.expenses == null) {
      final fallback = await _spendingAssessmentFromDailyCheckin();
      if (fallback != null) return fallback;
    }

    switch (itemId) {
      case 'income':
        return _assessIncome(snapshot);
      case 'spending':
        return _assessSpending(snapshot);
      case 'monthly_flow':
        return _assessMonthlyFlow(snapshot);
      case 'budget':
        return _assessBudget(snapshot);
      case 'debts':
        return _assessDebts(snapshot);
      case 'savings':
        return _assessSavings(snapshot);
      case 'goals_fin':
        return _assessFinanceGoals(snapshot);
      default:
        return getAssessment('finance_material', itemId);
    }
  }

  Future<AreaAssessment?> _spendingAssessmentFromDailyCheckin() {
    final today = DateTime.now();

    return _assessmentFromDailyQuestions(
      areaId: 'finance_material',
      day: today,
      questionIds: const ['fin_control', 'fin_tx'],
      positiveReason: 'Seu controle recente de gastos parece bom.',
      negativeReason: 'Seu controle recente de gastos parece fraco.',
      positiveAction: 'Continue registrando e mantendo esse controle.',
      negativeAction: 'Tente registrar gastos e reduzir despesas impulsivas.',
      details:
          'Estimativa baseada nas respostas recentes do check-in sobre finanças.',
      estimated: true,
    );
  }

  // -------------------- FINANCE (resto igual do seu arquivo) --------------------

  Future<_FinanceSnapshot> _readFinanceSnapshot(
    SharedPreferences prefs,
    String uid,
  ) async {
    final transactions = await _loadCurrentMonthFinanceTransactions();

    final incomeFromTransactions = _sumIncome(transactions);
    final expensesFromTransactions = _sumExpense(transactions);

    final manualBudget = _readNum(prefs, [
      '$uid:monthly_budget',
      '$uid:finance_monthly_budget',
      '$uid:budget',
    ]);

    final manualDebts = _readNum(prefs, [
      '$uid:total_debts',
      '$uid:finance_total_debts',
      '$uid:debts',
    ]);

    final manualReserve = _readNum(prefs, [
      '$uid:emergency_reserve',
      '$uid:finance_emergency_reserve',
      '$uid:reserve',
    ]);

    final manualGoalsProgress = _readNum(prefs, [
      '$uid:finance_goals_progress',
      '$uid:goals_fin_progress',
    ]);

    final rawUpdatedAt =
        prefs.getString('$uid:finance_updated_at') ??
        prefs.getString('$uid:finance:lastUpdatedAt');

    DateTime? latestTransactionDate;
    if (transactions.isNotEmpty) {
      latestTransactionDate = transactions
          .map((e) => e.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }

    final manualUpdatedAt = rawUpdatedAt == null
        ? null
        : DateTime.tryParse(rawUpdatedAt);

    final effectiveUpdatedAt = _latestDate(
      latestTransactionDate,
      manualUpdatedAt,
    );

    return _FinanceSnapshot(
      income: transactions.isEmpty ? null : incomeFromTransactions,
      expenses: transactions.isEmpty ? null : expensesFromTransactions,
      budget: manualBudget,
      debts: manualDebts,
      reserve: manualReserve,
      goalsProgress: manualGoalsProgress,
      updatedAt: effectiveUpdatedAt ?? DateTime.now(),
      transactionCount: transactions.length,
    );
  }

  Future<List<FinanceTransaction>>
  _loadCurrentMonthFinanceTransactions() async {
    final all = await _financeRepository.loadAll();
    final now = DateTime.now();

    return all.where((transaction) {
      final d = transaction.date;
      return d.year == now.year && d.month == now.month;
    }).toList();
  }

  double _sumIncome(List<FinanceTransaction> items) {
    return items
        .where((transaction) => transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double _sumExpense(List<FinanceTransaction> items) {
    return items
        .where((transaction) => !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  AreaAssessment _assessIncome(_FinanceSnapshot s) {
    final income = s.income;
    if (income == null) {
      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: 'Ainda não há entradas registradas neste mês em Finanças.',
        action: 'Adicione entradas na aba Finanças para ativar esta subárea.',
      );
    }

    late final int score;
    late final String reason;
    late final String details;

    final expenses = s.expenses;

    if (expenses != null && expenses > 0) {
      final coverage = income / expenses;
      score = _scoreFromStops(coverage, const [
        _ScoreStop(0.0, 5),
        _ScoreStop(0.5, 20),
        _ScoreStop(0.8, 40),
        _ScoreStop(1.0, 60),
        _ScoreStop(1.2, 75),
        _ScoreStop(1.5, 90),
        _ScoreStop(2.0, 100),
      ]);

      reason =
          'Entradas reais de ${_money(income)}, cobrindo ${(coverage * 100).toStringAsFixed(0)}% dos gastos do mês.';
      details =
          'Calculado principalmente pela capacidade de a renda cobrir os gastos reais do mês.';
    } else {
      score = _scoreFromStops(income, const [
        _ScoreStop(0, 5),
        _ScoreStop(800, 20),
        _ScoreStop(1500, 35),
        _ScoreStop(2500, 55),
        _ScoreStop(3500, 70),
        _ScoreStop(5000, 85),
        _ScoreStop(8000, 100),
      ]);

      reason = 'Entradas reais do mês em ${_money(income)}.';
      details =
          'Como ainda não há gastos suficientes para comparação, a nota usa apenas o valor de entrada do mês.';
    }

    final status = _statusFromNumericScore(score);
    final action = _financeActionFromStatus(
      status: status,
      excellent:
          'Sua renda cobre bem o mês atual. Continue mantendo constância.',
      good:
          'Boa base de entrada. Vale continuar fortalecendo essa estabilidade.',
      medium:
          'Sua renda sustenta parte importante do mês, mas ainda pede evolução.',
      poor:
          'Sua renda está curta para o padrão atual do mês. Vale ajustar ou reforçar entradas.',
      critical: 'Sua renda está muito baixa para sustentar bem o mês atual.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: details,
    );
  }

  AreaAssessment _assessSpending(_FinanceSnapshot s) {
    final income = s.income;
    final expenses = s.expenses;
    final budget = s.budget;

    if (expenses == null) {
      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: 'Ainda não há gastos registrados neste mês em Finanças.',
        action: 'Adicione saídas na aba Finanças para ativar esta subárea.',
      );
    }

    late final int score;
    late final String reason;
    late final String details;

    if (income != null && income > 0) {
      final ratio = expenses / income;
      score = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.30, 92),
        _ScoreStop(0.55, 82),
        _ScoreStop(0.80, 68),
        _ScoreStop(1.00, 50),
        _ScoreStop(1.15, 34),
        _ScoreStop(1.40, 18),
        _ScoreStop(2.00, 5),
      ]);

      reason =
          'Gastos reais de ${_money(expenses)} para entradas reais de ${_money(income)} (${(ratio * 100).toStringAsFixed(0)}% da renda).';
      details =
          'Quanto menor o peso dos gastos sobre a renda real do mês, maior a nota.';
    } else if (budget != null && budget > 0) {
      final ratio = expenses / budget;
      score = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.50, 90),
        _ScoreStop(0.80, 76),
        _ScoreStop(1.00, 58),
        _ScoreStop(1.10, 42),
        _ScoreStop(1.25, 25),
        _ScoreStop(1.50, 10),
        _ScoreStop(2.00, 5),
      ]);

      reason =
          'Gastos reais de ${_money(expenses)} comparados ao orçamento manual de ${_money(budget)}.';
      details =
          'Como faltam entradas reais, a nota usa o orçamento como referência principal.';
    } else {
      score = 50;
      reason =
          'Há ${_money(expenses)} em gastos, mas ainda faltam entradas ou orçamento para medir o peso real.';
      details =
          'Sem uma referência confiável, esta subárea fica provisoriamente no meio da escala.';
    }

    final status = _statusFromNumericScore(score);
    final action = _financeActionFromStatus(
      status: status,
      excellent: 'Ótimo controle de saídas. Continue assim.',
      good: 'Controle bom. Só monitore para não subir.',
      medium: 'Seus gastos já pedem revisão moderada.',
      poor: 'Seus gastos estão pesando bastante. Vale cortar excessos.',
      critical:
          'Seus gastos estão muito altos para a sua base atual. Reorganizar isso é prioridade.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: details,
    );
  }

  AreaAssessment _assessMonthlyFlow(_FinanceSnapshot s) {
    final income = s.income;
    final expenses = s.expenses;

    if (income == null && expenses == null) {
      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: 'Ainda não há movimentações suficientes neste mês.',
        action: 'Use a aba Finanças para ativar esta subárea.',
      );
    }

    if (income == null || expenses == null || income <= 0) {
      return AreaAssessment(
        status: AreaStatus.medium,
        score: 50,
        reason:
            'Ainda faltam dados completos de entradas e saídas para medir seu fluxo do mês.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: s.updatedAt,
        recommendedAction:
            'Registre entradas e saídas para o fluxo ficar confiável.',
        details: 'Subárea depende das movimentações reais deste mês.',
      );
    }

    final net = income - expenses;
    final margin = net / income;

    final score = _scoreFromStops(margin, const [
      _ScoreStop(-1.00, 0),
      _ScoreStop(-0.50, 10),
      _ScoreStop(-0.20, 25),
      _ScoreStop(0.00, 45),
      _ScoreStop(0.10, 60),
      _ScoreStop(0.20, 75),
      _ScoreStop(0.35, 90),
      _ScoreStop(0.60, 100),
    ]);

    final status = _statusFromNumericScore(score);
    final signal = net >= 0 ? '+' : '-';
    final absoluteNet = net.abs();

    final action = _financeActionFromStatus(
      status: status,
      excellent: 'Seu fluxo do mês está muito saudável.',
      good: 'Seu mês está positivo. Continue protegendo essa folga.',
      medium: 'Seu fluxo está apertado, mas ainda recuperável.',
      poor: 'Seu fluxo do mês está fraco. Vale agir logo.',
      critical: 'Seu fluxo está bem negativo. Reorganizar isso é prioridade.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason:
          'Fluxo do mês: $signal${_money(absoluteNet)} (${_money(income)} de entrada e ${_money(expenses)} de saída).',
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'Calculado automaticamente pela margem do mês: quanto maior a sobra sobre a renda, maior a nota.',
    );
  }

  AreaAssessment _assessBudget(_FinanceSnapshot s) {
    final budget = s.budget;
    final expenses = s.expenses;

    if (budget == null) {
      return _noDataAssessment(
        source: AreaDataSource.mixed,
        reason: 'Ainda não há orçamento mensal definido.',
        action: 'Defina um orçamento manual para comparar com seus gastos.',
      );
    }

    if (expenses == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        score: 0,
        reason: 'Orçamento existe, mas ainda não há gastos lançados neste mês.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: s.updatedAt,
        recommendedAction:
            'Registre gastos na aba Finanças para comparar com o orçamento.',
        details: 'Subárea depende de orçamento manual + gastos reais.',
      );
    }

    if (budget <= 0) {
      return _noDataAssessment(
        source: AreaDataSource.mixed,
        reason: 'Orçamento inválido ou zerado.',
        action: 'Defina um orçamento mensal realista.',
      );
    }

    final ratio = expenses / budget;
    final score = _scoreFromStops(ratio, const [
      _ScoreStop(0.00, 100),
      _ScoreStop(0.50, 92),
      _ScoreStop(0.80, 78),
      _ScoreStop(1.00, 60),
      _ScoreStop(1.10, 45),
      _ScoreStop(1.25, 28),
      _ScoreStop(1.50, 12),
      _ScoreStop(2.00, 0),
    ]);

    final status = _statusFromNumericScore(score);
    final action = _financeActionFromStatus(
      status: status,
      excellent: 'Seu orçamento está muito bem controlado.',
      good: 'Bom controle do orçamento. Continue atento.',
      medium: 'Você está perto do limite do orçamento.',
      poor: 'Você já passou bastante do orçamento. Vale corrigir logo.',
      critical: 'Orçamento estourado. Reorganize prioridades.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason:
          'Gastos reais de ${_money(expenses)} frente a orçamento manual de ${_money(budget)}.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'A nota cai gradualmente conforme os gastos se aproximam ou passam do orçamento.',
    );
  }

  AreaAssessment _assessDebts(_FinanceSnapshot s) {
    final debts = s.debts;
    final income = s.income;
    final budget = s.budget;
    final expenses = s.expenses;

    if (debts == null) {
      return _noDataAssessment(
        source: AreaDataSource.manual,
        reason: 'Sem informação de dívidas ainda.',
        action: 'Informe dívidas ou parcelamentos ativos.',
      );
    }

    if (debts <= 0) {
      return AreaAssessment(
        status: AreaStatus.excellent,
        score: 100,
        reason: 'Nenhuma dívida relevante registrada.',
        source: AreaDataSource.manual,
        lastUpdatedAt: s.updatedAt,
        recommendedAction: 'Continue mantendo esse controle.',
        details: 'Subárea baseada no total de dívidas informado manualmente.',
      );
    }

    late final int score;
    late final String reason;
    late final String details;

    if (income != null && income > 0) {
      final ratio = debts / income;
      score = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.25, 88),
        _ScoreStop(0.50, 72),
        _ScoreStop(1.00, 48),
        _ScoreStop(1.50, 28),
        _ScoreStop(2.00, 14),
        _ScoreStop(3.00, 5),
      ]);

      reason =
          'Dívidas de ${_money(debts)}, cerca de ${(ratio * 100).toStringAsFixed(0)}% das entradas do mês.';
      details =
          'Quanto maior o peso das dívidas sobre a renda do mês, menor a nota.';
    } else if (budget != null && budget > 0) {
      final ratio = debts / budget;
      score = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.30, 82),
        _ScoreStop(0.60, 64),
        _ScoreStop(1.00, 42),
        _ScoreStop(1.50, 22),
        _ScoreStop(2.50, 8),
      ]);

      reason =
          'Dívidas de ${_money(debts)} em comparação ao orçamento mensal de ${_money(budget)}.';
      details =
          'Como faltam entradas, o peso das dívidas foi comparado ao orçamento atual.';
    } else if (expenses != null && expenses > 0) {
      final ratio = debts / expenses;
      score = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.30, 80),
        _ScoreStop(0.60, 62),
        _ScoreStop(1.00, 42),
        _ScoreStop(1.50, 24),
        _ScoreStop(2.50, 8),
      ]);

      reason =
          'Dívidas de ${_money(debts)} em comparação aos gastos atuais de ${_money(expenses)}.';
      details =
          'Como faltam entradas, o peso das dívidas foi comparado ao padrão de gastos do mês.';
    } else {
      score = _scoreFromStops(debts, const [
        _ScoreStop(0, 100),
        _ScoreStop(500, 82),
        _ScoreStop(1500, 62),
        _ScoreStop(3000, 40),
        _ScoreStop(6000, 20),
        _ScoreStop(10000, 5),
      ]);

      reason = 'Dívidas registradas em ${_money(debts)}.';
      details =
          'Sem referência mensal suficiente, a nota usa apenas o valor absoluto das dívidas.';
    }

    final status = _statusFromNumericScore(score);
    final action = _financeActionFromStatus(
      status: status,
      excellent: 'Peso das dívidas muito bem controlado.',
      good: 'Dívidas em nível administrável. Continue atento.',
      medium: 'O peso das dívidas já merece um plano de redução.',
      poor: 'As dívidas estão pesando bastante na sua vida financeira.',
      critical: 'Dívidas muito altas. Prioridade máxima de reorganização.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: details,
    );
  }

  AreaAssessment _assessSavings(_FinanceSnapshot s) {
    final reserve = s.reserve;
    final expenses = s.expenses;
    final income = s.income;

    if (reserve == null) {
      return _noDataAssessment(
        source: AreaDataSource.manual,
        reason: 'Sem informação de reserva financeira ainda.',
        action: 'Informe o valor da sua reserva.',
      );
    }

    if (reserve <= 0) {
      return AreaAssessment(
        status: AreaStatus.critical,
        score: 5,
        reason: 'Nenhuma reserva registrada até agora.',
        source: AreaDataSource.manual,
        lastUpdatedAt: s.updatedAt,
        recommendedAction: 'Comece montando uma reserva, mesmo que pequena.',
        details:
            'Subárea baseada na reserva de emergência informada manualmente.',
      );
    }

    late final int score;
    late final String reason;
    late final String details;

    if (expenses != null && expenses > 0) {
      final monthsCovered = reserve / expenses;
      score = _scoreFromStops(monthsCovered, const [
        _ScoreStop(0.0, 5),
        _ScoreStop(0.5, 18),
        _ScoreStop(1.0, 35),
        _ScoreStop(2.0, 55),
        _ScoreStop(3.0, 70),
        _ScoreStop(6.0, 90),
        _ScoreStop(12.0, 100),
      ]);

      reason =
          'Reserva de ${_money(reserve)}, cobrindo cerca de ${monthsCovered.toStringAsFixed(1)} meses dos gastos atuais.';
      details =
          'A nota sobe conforme a reserva cobre mais meses do seu custo atual.';
    } else if (income != null && income > 0) {
      final monthsCovered = reserve / income;
      score = _scoreFromStops(monthsCovered, const [
        _ScoreStop(0.0, 10),
        _ScoreStop(0.5, 25),
        _ScoreStop(1.0, 40),
        _ScoreStop(2.0, 58),
        _ScoreStop(3.0, 72),
        _ScoreStop(6.0, 90),
        _ScoreStop(12.0, 100),
      ]);

      reason =
          'Reserva de ${_money(reserve)}, equivalente a ${monthsCovered.toStringAsFixed(1)} meses de entrada atual.';
      details =
          'Como faltam gastos suficientes, a cobertura foi estimada sobre a renda do mês.';
    } else {
      score = _scoreFromStops(reserve, const [
        _ScoreStop(0, 5),
        _ScoreStop(500, 18),
        _ScoreStop(1500, 32),
        _ScoreStop(3000, 48),
        _ScoreStop(6000, 64),
        _ScoreStop(12000, 82),
        _ScoreStop(25000, 100),
      ]);

      reason = 'Reserva de ${_money(reserve)} registrada.';
      details =
          'Sem referência mensal suficiente, a nota usa o crescimento absoluto da reserva.';
    }

    final status = _statusFromNumericScore(score);
    final action = _financeActionFromStatus(
      status: status,
      excellent: 'Excelente proteção financeira de curto prazo.',
      good: 'Boa reserva. Continue fortalecendo.',
      medium: 'Sua reserva já ajuda, mas ainda é curta.',
      poor: 'Sua reserva ainda está fraca para imprevistos.',
      critical: 'Proteção financeira muito baixa para imprevistos.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason: reason,
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: details,
    );
  }

  AreaAssessment _assessFinanceGoals(_FinanceSnapshot s) {
    final p = s.goalsProgress;
    if (p == null) {
      return _noDataAssessment(
        source: AreaDataSource.manual,
        reason: 'Sem progresso de metas financeiras informado.',
        action: 'Informe o avanço das suas metas financeiras.',
      );
    }

    final score = p.clamp(0, 100).round();
    final status = _statusFromNumericScore(score);

    final action = _financeActionFromStatus(
      status: status,
      excellent: 'Metas financeiras andando muito bem.',
      good: 'Bom progresso. Continue mantendo ritmo.',
      medium: 'Progresso razoável, mas ainda pede constância.',
      poor: 'Progresso lento. Vale revisar foco e execução.',
      critical: 'Metas quase paradas. Replaneje as próximas ações.',
    );

    return AreaAssessment(
      status: status,
      score: score,
      reason:
          'Progresso financeiro registrado em ${score.toStringAsFixed(0)}%.',
      source: AreaDataSource.manual,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'Subárea baseada diretamente no avanço percentual informado para as metas financeiras.',
    );
  }

  Future<AreaAssessment?> _computedSocialMedia(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:social_media') ?? '').trim();
    if (raw.isEmpty) return null;

    final hours = _extractScreenTimeHours(raw);
    if (hours == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        reason: 'Não foi possível interpretar o tempo em redes sociais salvo.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    final score = _socialMediaScore(hours);
    final status = _statusFromNumericScore(score);

    final action = switch (status) {
      AreaStatus.excellent => 'Ótimo. Continue protegendo seu tempo.',
      AreaStatus.good => 'Bom. Só monitore para não subir.',
      AreaStatus.medium => 'Use com moderação para não subir.',
      AreaStatus.poor => 'Vale reduzir bastante redes sociais.',
      AreaStatus.critical => 'Redes sociais estão pesando. Defina limites.',
      AreaStatus.noData => 'Atualize seus dados.',
    };

    return AreaAssessment(
      status: status,
      score: score,
      reason: 'Tempo em redes sociais hoje: $raw.',
      source: AreaDataSource.automatic,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Calculado automaticamente a partir do uso em apps sociais (Facebook, YouTube, WhatsApp, Instagram, TikTok, Kwai, Messenger, X, Telegram).',
    );
  }

  int _socialMediaScore(double hours) {
    final raw = 100 - ((hours - 1.0) * 18.0);
    return raw.round().clamp(5, 100);
  }

  Future<AreaAssessment?> _computedNightUse(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:night_use') ?? '').trim();
    if (raw.isEmpty) return null;

    final hours = _extractScreenTimeHours(raw);
    if (hours == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        reason: 'Não foi possível interpretar o uso noturno salvo.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    final score = _nightUseScore(hours);
    final status = _statusFromNumericScore(score);

    final action = switch (status) {
      AreaStatus.excellent => 'Ótimo. Continue protegendo seu descanso.',
      AreaStatus.good => 'Bom. Só evite estender muito à noite.',
      AreaStatus.medium => 'Tente reduzir um pouco a tela perto de dormir.',
      AreaStatus.poor => 'Tente reduzir bastante a tela perto de dormir.',
      AreaStatus.critical => 'Uso noturno alto. Crie um horário de desligar.',
      AreaStatus.noData => 'Atualize seus dados.',
    };

    return AreaAssessment(
      status: status,
      score: score,
      reason: 'Uso noturno (19:00–04:00): $raw.',
      source: AreaDataSource.automatic,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Calculado automaticamente somando uso de tela no período 19:00–04:00.',
    );
  }

  int _nightUseScore(double hours) {
    final raw = 100 - ((hours - 0.5) * 25.0);
    return raw.round().clamp(5, 100);
  }

  Future<AreaAssessment?> _computedScreenTime(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:screen_time') ?? '').trim();
    if (raw.isEmpty) return null;

    final hours = _extractScreenTimeHours(raw);
    if (hours == null) {
      return AreaAssessment(
        status: AreaStatus.noData,
        reason: 'Não foi possível interpretar o tempo de tela salvo.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    final score = _screenTimeScore(hours);
    final status = _statusFromNumericScore(score);

    final action = switch (status) {
      AreaStatus.excellent => 'Ótimo. Continue protegendo seu tempo de tela.',
      AreaStatus.good => 'Bom. Só monitore para não subir.',
      AreaStatus.medium => 'Tente reduzir um pouco o tempo de tela.',
      AreaStatus.poor => 'Tente reduzir bastante o tempo de tela.',
      AreaStatus.critical => 'Tempo de tela alto. Defina limites diários.',
      AreaStatus.noData => 'Atualize seus dados.',
    };

    return AreaAssessment(
      status: status,
      score: score,
      reason: 'Tempo de tela hoje: $raw.',
      source: AreaDataSource.automatic,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Calculado automaticamente a partir do uso total de tela no dia.',
    );
  }

  int _screenTimeScore(double hours) {
    final raw = 100 - ((hours - 2.0) * 14.0);
    return raw.round().clamp(5, 100);
  }

  AreaAssessment _noDataAssessment({
    required AreaDataSource source,
    required String reason,
    required String action,
  }) {
    return AreaAssessment(
      status: AreaStatus.noData,
      score: 0,
      reason: reason,
      source: source,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
    );
  }

  Future<void> updateLastCheckupDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final iso = _toIsoDate(date);
    await prefs.setString('${user.uid}:last_checkup', iso);
    await prefs.setString(
      _areaUpdatedPrefKey(user.uid, 'body_health'),
      DateTime.now().toIso8601String(),
    );

    final computed = await _computedCheckups(user.uid);
    if (computed != null) {
      final box = await _open();
      await box.put(_key('body_health', 'checkups'), computed.toMap());
    }
  }

  Future<void> saveFinanceSnapshot({
    double? monthlyBudget,
    double? totalDebts,
    double? emergencyReserve,
    double? goalsProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    Future<void> setNum(String key, double? value) async {
      if (value == null) return;
      await prefs.setDouble(key, value);
    }

    await setNum('$uid:monthly_budget', monthlyBudget);
    await setNum('$uid:total_debts', totalDebts);
    await setNum('$uid:emergency_reserve', emergencyReserve);
    await setNum('$uid:finance_goals_progress', goalsProgress);
    await prefs.setString(
      '$uid:finance_updated_at',
      DateTime.now().toIso8601String(),
    );
    await prefs.setString(
      _areaUpdatedPrefKey(uid, 'finance_material'),
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getAreaLastUpdate(String areaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_areaUpdatedPrefKey(user.uid, areaId)) ?? '')
        .trim();

    if (raw.isEmpty) return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> markAreaUpdated(String areaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _areaUpdatedPrefKey(user.uid, areaId),
      DateTime.now().toIso8601String(),
    );
  }

  Future<AreaAssessment?> getAssessment(String areaId, String itemId) async {
    final box = await _open();
    final raw = box.get(_key(areaId, itemId));
    if (raw is! Map) return null;
    return AreaAssessment.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> setAssessment(
    String areaId,
    String itemId, {
    required AreaStatus status,
    String? reason,
    int? score,
    AreaDataSource source = AreaDataSource.manual,
    String? recommendedAction,
    String? details,
  }) async {
    final box = await _open();

    final value = AreaAssessment(
      status: status,
      score: score ?? _scoreFromStatus(status),
      reason: reason,
      source: source,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: recommendedAction,
      details: details,
    ).toMap();

    await box.put(_key(areaId, itemId), value);
    await markAreaUpdated(areaId);
  }

  Future<void> clearAssessment(String areaId, String itemId) async {
    final box = await _open();
    await box.delete(_key(areaId, itemId));
  }

  Future<String?> trendLabel(String areaId, String itemId) async {
    if (areaId == 'body_health' && itemId == 'energy') {
      return _trendLabelForQuestions(const ['energy_ok', 'sleep_ok']);
    }
    if (areaId == 'body_health' && itemId == 'movement') {
      return _trendLabelForQuestions(const ['move']);
    }
    if (areaId == 'body_health' && itemId == 'nutrition') {
      return _trendLabelForQuestions(const ['nutrition_ok', 'hydration_ok']);
    }
    if (areaId == 'mind_emotion' && itemId == 'mood') {
      return _trendLabelForQuestions(const ['mood_ok', 'mental_recovery']);
    }
    if (areaId == 'mind_emotion' && itemId == 'stress') {
      return _trendLabelForQuestions(const ['stress_ok', 'mental_recovery']);
    }
    if (areaId == 'mind_emotion' && itemId == 'focus') {
      return _trendLabelForQuestions(const ['focus', 'study_quality']);
    }
    if (areaId == 'mind_emotion' && itemId == 'mental_load') {
      return _trendLabelForQuestions(const ['stress_ok', 'mental_recovery']);
    }
    if (areaId == 'work_vocation' && itemId == 'routine') {
      return _trendLabelForQuestions(const ['routine_ok', 'day_planning']);
    }
    if (areaId == 'work_vocation' && itemId == 'consistency') {
      return _trendLabelForQuestions(const ['routine_ok', 'day_planning']);
    }
    if (areaId == 'work_vocation' && itemId == 'output') {
      return _trendLabelForQuestions(const [
        'day_planning',
        'focus',
        'routine_ok',
      ]);
    }
    if (areaId == 'work_vocation' && itemId == 'balance') {
      return _trendLabelForQuestions(const [
        'routine_ok',
        'stress_ok',
        'mental_recovery',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'study') {
      return _trendLabelForQuestions(const ['study_ok', 'study_quality']);
    }
    if (areaId == 'learning_intellect' && itemId == 'courses') {
      return _trendLabelForQuestions(const [
        'study_ok',
        'study_quality',
        'routine_ok',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'reading') {
      return _trendLabelForQuestions(const ['study_quality', 'focus']);
    }
    if (areaId == 'learning_intellect' && itemId == 'skills') {
      return _trendLabelForQuestions(const [
        'study_quality',
        'focus',
        'routine_ok',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'review_practice') {
      return _trendLabelForQuestions(const [
        'study_ok',
        'study_quality',
        'focus',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'family') {
      return _trendLabelForQuestions(const [
        'social_ok',
        'social_presence',
        'mood_ok',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'friends') {
      return _trendLabelForQuestions(const [
        'social_ok',
        'social_presence',
        'mood_ok',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'social_contact') {
      return _trendLabelForQuestions(const ['social_ok', 'social_presence']);
    }
    if (areaId == 'purpose_values' && itemId == 'direction') {
      return _trendLabelForQuestions(const [
        'routine_ok',
        'day_planning',
        'energy_ok',
      ]);
    }
    if (areaId == 'purpose_values' && itemId == 'goals_review') {
      return _trendLabelForQuestions(const ['routine_ok', 'move', 'study_ok']);
    }
    if (areaId == 'purpose_values' && itemId == 'gratitude') {
      return _trendLabelForQuestions(const [
        'mental_recovery',
        'sleep_ok',
        'mood_ok',
        'stress_ok',
      ]);
    }
    if (areaId == 'digital_tech' && itemId == 'distraction') {
      return _trendLabelForQuestions(const ['focus', 'digital_balance']);
    }
    return null;
  }

  Future<String?> _trendLabelForQuestions(List<String> questionIds) async {
    final history = await _readDailyScaledHistory(
      day: DateTime.now(),
      questionIds: questionIds,
      days: DailyCheckinService.historyDays,
    );

    if (history.length < 4) return null;

    final trend = _trendFromScaledHistory(history);
    switch (trend) {
      case 'improving':
        return '📈 Melhorando';
      case 'worsening':
        return '📉 Piorando';
      default:
        return '➖ Estável';
    }
  }

  Future<AreaStatus?> overallStatus(String areaId, List<String> itemIds) async {
    final statuses = <AreaStatus>[];

    for (final itemId in itemIds) {
      final assessment = await getComputedAssessment(areaId, itemId);
      if (assessment == null || assessment.status == AreaStatus.noData) {
        continue;
      }
      statuses.add(assessment.status);
    }

    if (statuses.isEmpty) return null;

    if (statuses.contains(AreaStatus.critical)) return AreaStatus.critical;
    if (statuses.contains(AreaStatus.poor)) return AreaStatus.poor;
    if (statuses.contains(AreaStatus.medium)) return AreaStatus.medium;
    if (statuses.contains(AreaStatus.good)) return AreaStatus.good;
    if (statuses.contains(AreaStatus.excellent)) return AreaStatus.excellent;

    return AreaStatus.noData;
  }

  Future<int?> score(String areaId, List<String> itemIds) async {
    double weightedSum = 0;
    double totalWeight = 0;

    for (final itemId in itemIds) {
      final assessment = await getComputedAssessment(areaId, itemId);
      if (assessment == null || assessment.status == AreaStatus.noData) {
        continue;
      }

      final item = AreasCatalog.itemById(
        areaId,
        itemId,
        includeWomenCycle: true,
      );
      final weight = item?.weight ?? 1.0;
      final itemScore = assessment.score ?? _scoreFromStatus(assessment.status);

      weightedSum += itemScore * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return null;
    return (weightedSum / totalWeight).round().clamp(0, 100);
  }

  int _scoreFromStatus(AreaStatus status) {
    switch (status) {
      case AreaStatus.excellent:
        return 90;
      case AreaStatus.good:
        return 70;
      case AreaStatus.medium:
        return 50;
      case AreaStatus.poor:
        return 30;
      case AreaStatus.critical:
        return 10;
      case AreaStatus.noData:
        return 0;
    }
  }

  double? _readNum(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final obj = prefs.get(key);
      if (obj is int) return obj.toDouble();
      if (obj is double) return obj;
      if (obj is String) {
        final normalized = obj.replaceAll(',', '.').trim();
        final value = double.tryParse(normalized);
        if (value != null) return value;
      }
    }
    return null;
  }

  DateTime? _parseIsoDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }

  String _toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _monthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  int? _ageFromIsoDob(String iso) {
    if (iso.isEmpty) return null;

    try {
      final dob = DateTime.parse(iso);
      final now = DateTime.now();

      var age = now.year - dob.year;
      final hadBirthday =
          now.month > dob.month ||
          (now.month == dob.month && now.day >= dob.day);

      if (!hadBirthday) age--;

      if (age < 0 || age > 150) return null;
      return age;
    } catch (_) {
      return null;
    }
  }

  double? _extractScreenTimeHours(String raw) {
    final normalized = raw
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(' ', '')
        .toLowerCase();

    if (normalized.startsWith('<')) {
      final value = double.tryParse(
        normalized.replaceAll('<', '').replaceAll('h', ''),
      );
      return value == null ? null : value - 0.1;
    }

    if (normalized.contains('-')) {
      final parts = normalized.replaceAll('h', '').split('-');
      if (parts.length == 2) {
        final a = double.tryParse(parts[0]);
        final b = double.tryParse(parts[1]);
        if (a != null && b != null) return (a + b) / 2;
      }
    }

    if (normalized.startsWith('>=')) {
      final value = double.tryParse(
        normalized.replaceAll('>=', '').replaceAll('h', ''),
      );
      return value;
    }

    if (normalized.startsWith('>')) {
      final value = double.tryParse(
        normalized.replaceAll('>', '').replaceAll('h', ''),
      );
      return value;
    }

    return double.tryParse(normalized.replaceAll('h', ''));
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    return 'R\$ ${fixed.replaceAll('.', ',')}';
  }

  DateTime? _latestDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  // -------------------- PLACEHOLDERS: no seu arquivo completo existem --------------------
  // As funções abaixo (computedCheckups/computedSleep/...) já estão no seu texto original.
  // Mantém como está no seu projeto.
  Future<AreaAssessment?> _computedCheckups(String uid) async => null;
  Future<AreaAssessment?> _computedSleep(String uid) async => null;
  Future<AreaAssessment?> _computedWomenCycle(String uid) async => null;
}

class _ScoreStop {
  const _ScoreStop(this.x, this.score);

  final double x;
  final int score;
}

class _DailyScaledPoint {
  const _DailyScaledPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class _FinanceSnapshot {
  const _FinanceSnapshot({
    required this.income,
    required this.expenses,
    required this.budget,
    required this.debts,
    required this.reserve,
    required this.goalsProgress,
    required this.updatedAt,
    required this.transactionCount,
  });

  final double? income;
  final double? expenses;
  final double? budget;
  final double? debts;
  final double? reserve;
  final double? goalsProgress;
  final DateTime? updatedAt;
  final int transactionCount;
}
