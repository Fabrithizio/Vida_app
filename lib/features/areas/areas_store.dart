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
// - energy, sleep, movement, nutrition e hydration
//   -> passam a vir do check-in diário
// - mood, stress e focus
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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/bootstrap/areas_bootstrap_service.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_device_usage_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_finance_engine.dart';
import 'package:vida_app/features/areas/data/repositories/areas_storage_repository.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/finance/data/repositories/hive_finance_repository.dart';
import 'package:vida_app/features/areas/presentation/areas_catalog.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';

class AreasStore {
  AreasStore({
    FinanceRepository? financeRepository,
    AreasStorageRepository? storage,
    AreasBootstrapService? bootstrap,
    AreasDailyQuestionsEngine? dailyQuestions,
    AreasDeviceUsageEngine? deviceUsage,
    AreasFinanceEngine? financeEngine,
  }) : this._internal(
         financeRepository: financeRepository ?? HiveFinanceRepository(),
         storage: storage ?? AreasStorageRepository(),
         bootstrap: bootstrap,
         dailyQuestions:
             dailyQuestions ??
             AreasDailyQuestionsEngine(
               dailyCheckinService: DailyCheckinService(),
             ),
         deviceUsage: deviceUsage ?? AreasDeviceUsageEngine(),
         financeEngine: financeEngine,
       );

  AreasStore._internal({
    required FinanceRepository financeRepository,
    required AreasStorageRepository storage,
    AreasBootstrapService? bootstrap,
    required AreasDailyQuestionsEngine dailyQuestions,
    required AreasDeviceUsageEngine deviceUsage,
    AreasFinanceEngine? financeEngine,
  }) : _storage = storage,
       _bootstrap = bootstrap ?? AreasBootstrapService(storage: storage),
       _dailyQuestions = dailyQuestions,
       _deviceUsage = deviceUsage,
       _financeEngine =
           financeEngine ??
           AreasFinanceEngine(
             financeRepository: financeRepository,
             dailyQuestions: dailyQuestions,
           );

  final AreasStorageRepository _storage;
  final AreasBootstrapService _bootstrap;
  final AreasDailyQuestionsEngine _dailyQuestions;
  final AreasDeviceUsageEngine _deviceUsage;
  final AreasFinanceEngine _financeEngine;

  Future<void> ensureBootstrappedFromOnboarding() {
    return _bootstrap.ensureBootstrappedFromOnboarding();
  }

  Future<AreaAssessment?> getComputedAssessment(
    String areaId,
    String itemId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return getAssessment(areaId, itemId);
    }

    if (areaId == 'body_health' && itemId == 'movement') {
      final movementAssessment = await _computedMovementHybrid(user.uid);
      if (movementAssessment != null) {
        return movementAssessment;
      }
    }

    final dailyAssessment = await _dailyQuestions.computedDailyQuestionItem(
      areaId,
      itemId,
      onAreaUpdated: markAreaUpdated,
    );
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
      return _deviceUsage.computedScreenTime(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'social_media') {
      return _deviceUsage.computedSocialMedia(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'night_use') {
      return _deviceUsage.computedNightUse(user.uid);
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
      final assessment = await _financeEngine.computedFinanceItem(
        user.uid,
        itemId,
        onAreaUpdated: markAreaUpdated,
      );
      return assessment ?? getAssessment('finance_material', itemId);
    }

    return getAssessment(areaId, itemId);
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
    final history = await _dailyQuestions.readDailyScaledHistory(
      day: now,
      questionIds: const ['routine_ok', 'day_planning', 'energy_ok'],
      days: DailyCheckinService.historyDays,
    );

    final organization = await _computedEnvironmentItem(uid, 'organization');
    final cleaning = await _computedEnvironmentItem(uid, 'cleaning');

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

    final sleepAssessment = await _computedSleep(uid);

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
          'Calculado pelos sinais recentes de recuperação mental, sono, humor e estresse. ${sleepAssessment?.score != null ? 'O sono também entra como reforço nessa leitura. ' : ''}$trendSentence',
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

  Future<AreaAssessment?> _computedMovementHybrid(String uid) async {
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
      onAreaUpdated: markAreaUpdated,
    );
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
      _storage.areaUpdatedPrefKey(user.uid, 'body_health'),
      DateTime.now().toIso8601String(),
    );

    final computed = await _computedCheckups(user.uid);
    if (computed != null) {
      final box = await _storage.open();
      await box.put(
        _storage.itemKey('body_health', 'checkups'),
        computed.toMap(),
      );
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
      _storage.areaUpdatedPrefKey(uid, 'finance_material'),
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getAreaLastUpdate(String areaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw =
        (prefs.getString(_storage.areaUpdatedPrefKey(user.uid, areaId)) ?? '')
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
      _storage.areaUpdatedPrefKey(user.uid, areaId),
      DateTime.now().toIso8601String(),
    );
  }

  Future<AreaAssessment?> getAssessment(String areaId, String itemId) async {
    final box = await _storage.open();
    final raw = box.get(_storage.itemKey(areaId, itemId));
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
    final box = await _storage.open();

    final value = AreaAssessment(
      status: status,
      score: score ?? _scoreFromStatus(status),
      reason: reason,
      source: source,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: recommendedAction,
      details: details,
    ).toMap();

    await box.put(_storage.itemKey(areaId, itemId), value);
    await markAreaUpdated(areaId);
  }

  Future<void> clearAssessment(String areaId, String itemId) async {
    final box = await _storage.open();
    await box.delete(_storage.itemKey(areaId, itemId));
  }

  Future<String?> trendLabel(String areaId, String itemId) async {
    if (areaId == 'body_health' && itemId == 'energy') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'energy_ok',
        'sleep_ok',
      ]);
    }
    if (areaId == 'body_health' && itemId == 'movement') {
      return _dailyQuestions.trendLabelForQuestions(const ['move']);
    }
    if (areaId == 'body_health' && itemId == 'nutrition') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'nutrition_ok',
        'hydration_ok',
      ]);
    }
    if (areaId == 'mind_emotion' && itemId == 'mood') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'mood_ok',
        'mental_recovery',
      ]);
    }
    if (areaId == 'mind_emotion' && itemId == 'stress') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'stress_ok',
        'mental_recovery',
      ]);
    }
    if (areaId == 'mind_emotion' && itemId == 'focus') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'focus',
        'study_quality',
      ]);
    }
    if (areaId == 'mind_emotion' && itemId == 'mental_load') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'stress_ok',
        'mental_recovery',
      ]);
    }
    if (areaId == 'work_vocation' && itemId == 'routine') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'routine_ok',
        'day_planning',
      ]);
    }
    if (areaId == 'work_vocation' && itemId == 'consistency') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'routine_ok',
        'day_planning',
      ]);
    }
    if (areaId == 'work_vocation' && itemId == 'output') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'day_planning',
        'focus',
        'routine_ok',
      ]);
    }
    if (areaId == 'work_vocation' && itemId == 'balance') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'routine_ok',
        'stress_ok',
        'mental_recovery',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'study') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'study_ok',
        'study_quality',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'courses') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'study_ok',
        'study_quality',
        'routine_ok',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'reading') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'study_quality',
        'focus',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'skills') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'study_quality',
        'focus',
        'routine_ok',
      ]);
    }
    if (areaId == 'learning_intellect' && itemId == 'review_practice') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'study_ok',
        'study_quality',
        'focus',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'family') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'social_ok',
        'social_presence',
        'mood_ok',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'friends') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'social_ok',
        'social_presence',
        'mood_ok',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'partner') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'social_ok',
        'social_presence',
        'mood_ok',
      ]);
    }
    if (areaId == 'relations_community' && itemId == 'social_contact') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'social_ok',
        'social_presence',
      ]);
    }
    if (areaId == 'purpose_values' && itemId == 'direction') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'routine_ok',
        'day_planning',
        'energy_ok',
      ]);
    }
    if (areaId == 'purpose_values' && itemId == 'goals_review') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'routine_ok',
        'move',
        'study_ok',
      ]);
    }
    if (areaId == 'purpose_values' && itemId == 'gratitude') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'mental_recovery',
        'sleep_ok',
        'mood_ok',
        'stress_ok',
      ]);
    }
    if (areaId == 'digital_tech' && itemId == 'distraction') {
      return _dailyQuestions.trendLabelForQuestions(const [
        'focus',
        'digital_balance',
      ]);
    }
    return null;
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

  DateTime? _latestDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  // -------------------- PLACEHOLDERS: no seu arquivo completo existem --------------------
  // As funções abaixo (computedCheckups/computedSleep/...) já estão no seu texto original.
  // Mantém como está no seu projeto.
  Future<AreaAssessment?> _computedCheckups(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('${uid}:last_checkup') ?? '').trim();
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

  Future<AreaAssessment?> _computedSleep(String uid) async {
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
      onAreaUpdated: markAreaUpdated,
    );
  }

  Future<AreaAssessment?> _computedWomenCycle(String uid) async {
    return getAssessment('body_health', 'women_cycle');
  }
}

class _ScoreStop {
  const _ScoreStop(this.x, this.score);

  final double x;
  final int score;
}
