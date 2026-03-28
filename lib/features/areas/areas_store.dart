// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// O que faz:
// - Salva avaliações das áreas por usuário no Hive
// - Calcula itens dinamicamente com base em SharedPreferences
// - Conecta a área "Finanças & Material" ao módulo real de Finanças
// - Usa respostas do check-in diário para alimentar áreas do painel
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
//
// Atualizações desta revisão:
// - adiciona rastreamento de última atualização por área
// - permite alertas de "área sem atualização"
// - preserva a estrutura grande já existente
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

    if (areaId == 'body_health' && itemId == 'women_cycle') {
      return _computedWomenCycle(user.uid);
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
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'energy_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você relatou boa energia hoje.',
        noReason: 'Você relatou energia abaixo do ideal hoje.',
        yesAction: 'Tente manter esse ritmo e consistência.',
        noAction: 'Vale observar sono, alimentação e descanso.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'body_health' && itemId == 'movement') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'move',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você se movimentou ou treinou hoje.',
        noReason: 'Você não se movimentou hoje.',
        yesAction: 'Ótimo. Continue com regularidade.',
        noAction: 'Vale tentar ao menos uma caminhada ou movimento leve.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'body_health' && itemId == 'nutrition') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'nutrition_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você relatou alimentação razoável hoje.',
        noReason: 'Você relatou alimentação abaixo do ideal hoje.',
        yesAction: 'Continue reforçando bons hábitos.',
        noAction: 'Tente melhorar a qualidade das próximas refeições.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'mood') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'mood_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você relatou humor razoavelmente bom hoje.',
        noReason: 'Você relatou humor mais baixo hoje.',
        yesAction: 'Bom sinal. Tente manter esse equilíbrio.',
        noAction: 'Observe gatilhos e tente aliviar a pressão do dia.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'stress') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'stress_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você relatou estresse sob controle hoje.',
        noReason: 'Você relatou estresse acima do ideal hoje.',
        yesAction: 'Continue protegendo seu equilíbrio.',
        noAction: 'Vale desacelerar e revisar o que está pesando.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'focus') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'focus',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você conseguiu manter foco em algo importante hoje.',
        noReason: 'Você sentiu dificuldade de foco hoje.',
        yesAction: 'Ótimo. Tente repetir esse padrão.',
        noAction: 'Vale reduzir distrações e simplificar a rotina.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'mind_emotion' && itemId == 'mental_load') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'stress_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.critical,
        yesReason: 'Sua sobrecarga mental pareceu controlada hoje.',
        noReason: 'Você relatou sobrecarga mental alta hoje.',
        yesAction: 'Continue protegendo seu descanso mental.',
        noAction: 'Vale diminuir pressão, ajustar demandas e buscar pausas.',
        details:
            'Estimado a partir da resposta de estresse do check-in diário.',
      ).then((assessment) {
        if (assessment == null) return null;
        return assessment.copyWith(
          source: AreaDataSource.estimated,
          details:
              'Estimado a partir da resposta de estresse do check-in diário.',
        );
      });
    }

    if (areaId == 'work_vocation' && itemId == 'routine') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'routine_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Sua rotina principal esteve minimamente organizada hoje.',
        noReason: 'Sua rotina ficou desorganizada hoje.',
        yesAction: 'Continue repetindo esse padrão de consistência.',
        noAction: 'Vale simplificar o dia e definir poucas prioridades.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'work_vocation' && itemId == 'consistency') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'routine_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você mostrou consistência mínima na rotina hoje.',
        noReason: 'Sua consistência caiu hoje.',
        yesAction: 'Bom sinal. Continue aparecendo e executando o básico.',
        noAction: 'Tente reduzir atritos e voltar ao ritmo aos poucos.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'learning_intellect' && itemId == 'study') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'study_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você estudou ou aprendeu algo importante hoje.',
        noReason: 'Hoje faltou avanço em estudo ou aprendizado.',
        yesAction: 'Continue fortalecendo essa constância.',
        noAction: 'Tente encaixar uma sessão curta de estudo.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'relations_community' && itemId == 'social_contact') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'social_ok',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.attention,
        yesReason: 'Você teve uma boa conexão social hoje.',
        noReason: 'Hoje faltou conexão social de qualidade.',
        yesAction: 'Continue cuidando das suas conexões.',
        noAction: 'Vale chamar alguém importante ou retomar contato.',
        details: 'Baseado na resposta do check-in diário.',
      );
    }

    if (areaId == 'digital_tech' && itemId == 'distraction') {
      return _assessmentFromDailyAnswer(
        areaId: areaId,
        day: today,
        questionId: 'focus',
        yesStatus: AreaStatus.good,
        noStatus: AreaStatus.critical,
        yesReason: 'As distrações digitais não parecem ter dominado seu dia.',
        noReason: 'Seu foco caiu e isso sugere distração digital relevante.',
        yesAction: 'Continue protegendo seu foco.',
        noAction: 'Vale reduzir notificações e limitar apps de distração.',
        details: 'Estimado a partir da resposta de foco do check-in diário.',
      ).then((assessment) {
        if (assessment == null) return null;
        return assessment.copyWith(
          source: AreaDataSource.estimated,
          details: 'Estimado a partir da resposta de foco do check-in diário.',
        );
      });
    }

    return null;
  }

  Future<AreaAssessment?> _assessmentFromDailyAnswer({
    required String areaId,
    required DateTime day,
    required String questionId,
    required AreaStatus yesStatus,
    required AreaStatus noStatus,
    required String yesReason,
    required String noReason,
    required String yesAction,
    required String noAction,
    required String details,
  }) async {
    final answer = await _dailyCheckinService.getAnswer(
      day: day,
      questionId: questionId,
    );

    if (answer == null) return null;

    final isYes = answer == 1;
    final status = isYes ? yesStatus : noStatus;

    await markAreaUpdated(areaId);

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason: isYes ? yesReason : noReason,
      source: AreaDataSource.dailyQuestions,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: isYes ? yesAction : noAction,
      details: details,
    );
  }

  Future<AreaAssessment?> _computedCheckups(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = (prefs.getString('$uid:last_checkup') ?? '').trim();
    if (iso.isEmpty) return null;

    final date = _parseIsoDate(iso);
    if (date == null) return null;

    final now = DateTime.now();
    final days = now.difference(date).inDays;
    final months = _monthsBetween(date, now);
    final status = _statusForCheckups(months);

    final String reason;
    final String recommendedAction;

    if (status == AreaStatus.excellent) {
      reason =
          'Seu check-up está em dia. Faz $days dias desde o último registro.';
      recommendedAction = 'Continue mantendo esse cuidado em dia.';
    } else if (status == AreaStatus.good) {
      reason = 'Fique atento às datas. Faz $days dias desde o último check-up.';
      recommendedAction = 'Vale se planejar para não deixar passar.';
    } else {
      reason = 'Já faz $days dias desde o último check-up registrado.';
      recommendedAction = 'Atualize a data ou programe um novo check-up.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason: reason,
      source: AreaDataSource.manual,
      lastUpdatedAt: now,
      recommendedAction: recommendedAction,
      details: 'Último check-up registrado em ${_toIsoDate(date)}.',
    );
  }

  AreaStatus _statusForCheckups(int months) {
    if (months < 6) return AreaStatus.excellent;
    if (months < 12) return AreaStatus.good;
    return AreaStatus.critical;
  }

  Future<AreaAssessment?> _computedSleep(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    final int? hours =
        prefs.getInt('$uid:sleep_hours') ??
        int.tryParse((prefs.getString('$uid:sleep_hours') ?? '').trim());

    if (hours == null) return null;

    late final AreaStatus status;
    late final String reason;
    late final String action;

    if (hours < 5) {
      status = AreaStatus.critical;
      reason = '$hours h por noite. Sono muito abaixo do ideal.';
      action = 'Tente aumentar seu tempo de sono e revisar sua rotina noturna.';
    } else if (hours <= 6) {
      status = AreaStatus.attention;
      reason = '$hours h por noite. Seu sono pede atenção.';
      action = 'Busque mais consistência para chegar perto do ideal.';
    } else if (hours <= 8) {
      status = AreaStatus.excellent;
      reason =
          '$hours h por noite. Faixa excelente para a maioria das pessoas.';
      action = 'Continue mantendo esse padrão.';
    } else {
      status = AreaStatus.good;
      reason = '$hours h por noite. Está bom, mas observe a qualidade do sono.';
      action = 'Mantenha consistência e perceba se acorda bem.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason: reason,
      source: AreaDataSource.dailyQuestions,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details: 'Dado vindo do registro atual de horas de sono.',
    );
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
        source: AreaDataSource.manual,
        lastUpdatedAt: DateTime.now(),
        recommendedAction: 'Atualize esse campo em um formato reconhecido.',
      );
    }

    late final AreaStatus status;
    late final String action;

    if (hours < 2) {
      status = AreaStatus.excellent;
      action = 'Ótimo controle digital. Continue assim.';
    } else if (hours < 4) {
      status = AreaStatus.good;
      action = 'Uso aceitável. Só mantenha atenção se subir.';
    } else if (hours < 6) {
      status = AreaStatus.attention;
      action = 'Vale reduzir um pouco o uso para proteger foco e rotina.';
    } else {
      status = AreaStatus.critical;
      action = 'Tempo de tela alto. Tente criar limites diários.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason: 'Tempo de tela registrado: $raw.',
      source: AreaDataSource.manual,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
      details:
          'Valor interpretado aproximadamente como ${hours.toStringAsFixed(1)} horas.',
    );
  }

  Future<AreaAssessment?> _computedWomenCycle(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = (prefs.getString('$uid:gender') ?? '').trim().toLowerCase();

    final dobIso =
        (prefs.getString('birth_date_$uid') ??
                prefs.getString('$uid:birthDate') ??
                prefs.getString('$uid:birthdate') ??
                prefs.getString('$uid:dateOfBirth') ??
                prefs.getString('$uid:dob') ??
                '')
            .trim();

    final isWoman = gender.contains('mulher') || gender.contains('femin');
    if (!isWoman) return null;

    final age = _ageFromIsoDob(dobIso) ?? 0;
    if (age < 12) return null;

    return AreaAssessment(
      status: AreaStatus.good,
      score: _scoreFromStatus(AreaStatus.good),
      reason: 'Acompanhamento disponível para este perfil.',
      source: AreaDataSource.manual,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: 'Você poderá registrar dados do ciclo aqui.',
      details: 'Item visível para perfil feminino com idade compatível.',
    );
  }

  Future<AreaAssessment?> _computedFinanceItem(
    String uid,
    String itemId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = await _readFinanceSnapshot(prefs, uid);

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

    late final AreaStatus status;
    late final String reason;
    late final String action;

    if (income >= 5000) {
      status = AreaStatus.excellent;
      reason = 'Entradas do mês em ${_money(income)}.';
      action = 'Continue acompanhando a constância da sua renda.';
    } else if (income >= 2500) {
      status = AreaStatus.good;
      reason = 'Entradas do mês em ${_money(income)}.';
      action = 'Boa base de entrada. Continue fortalecendo.';
    } else if (income > 0) {
      status = AreaStatus.attention;
      reason = 'Entradas do mês em ${_money(income)} ainda pedem atenção.';
      action = 'Vale buscar mais previsibilidade ou crescimento de renda.';
    } else {
      status = AreaStatus.critical;
      reason = 'Entradas registradas zeradas neste mês.';
      action = 'Revise os lançamentos ou atualize sua renda.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason: reason,
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: 'Baseado nas entradas reais lançadas na aba Finanças neste mês.',
    );
  }

  AreaAssessment _assessSpending(_FinanceSnapshot s) {
    final income = s.income;
    final expenses = s.expenses;

    if (expenses == null) {
      final dailySpendingFallback = _spendingAssessmentFromDailyCheckin();
      if (dailySpendingFallback != null) {
        return dailySpendingFallback;
      }

      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: 'Ainda não há gastos registrados neste mês em Finanças.',
        action: 'Adicione saídas na aba Finanças para ativar esta subárea.',
      );
    }

    if (income == null || income <= 0) {
      return AreaAssessment(
        status: AreaStatus.attention,
        score: _scoreFromStatus(AreaStatus.attention),
        reason:
            'Há ${_money(expenses)} em gastos, mas faltam entradas para comparar.',
        source: AreaDataSource.automatic,
        lastUpdatedAt: s.updatedAt,
        recommendedAction:
            'Registre suas entradas para medir o peso dos gastos.',
        details: 'Baseado nas saídas reais do mês atual.',
      );
    }

    final ratio = expenses / income;

    late final AreaStatus status;
    late final String action;

    if (ratio <= 0.55) {
      status = AreaStatus.excellent;
      action = 'Ótimo controle de saídas. Continue assim.';
    } else if (ratio <= 0.80) {
      status = AreaStatus.good;
      action = 'Controle bom, mas acompanhe para não subir demais.';
    } else if (ratio <= 1.0) {
      status = AreaStatus.attention;
      action = 'Gastos perto do limite da renda. Vale revisar excessos.';
    } else {
      status = AreaStatus.critical;
      action = 'Seus gastos estão acima da renda. É prioridade reorganizar.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason:
          'Gastos reais de ${_money(expenses)} para entradas reais de ${_money(income)} (${(ratio * 100).toStringAsFixed(0)}% da renda).',
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'Baseado nas movimentações reais deste mês registradas em Finanças.',
    );
  }

  AreaAssessment? _spendingAssessmentFromDailyCheckin() {
    return null;
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

    if (income == null || expenses == null) {
      return AreaAssessment(
        status: AreaStatus.attention,
        score: _scoreFromStatus(AreaStatus.attention),
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

    late final AreaStatus status;
    late final String action;

    if (net >= income * 0.20) {
      status = AreaStatus.excellent;
      action = 'Seu fluxo do mês está bem saudável.';
    } else if (net >= 0) {
      status = AreaStatus.good;
      action = 'Seu mês está positivo, mas com folga menor.';
    } else if (net >= -income * 0.15) {
      status = AreaStatus.attention;
      action = 'Seu fluxo ficou negativo. Vale corrigir antes que piore.';
    } else {
      status = AreaStatus.critical;
      action = 'Saídas bem acima das entradas. Reorganizar isso é prioridade.';
    }

    final signal = net >= 0 ? '+' : '-';
    final absoluteNet = net.abs();

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason:
          'Fluxo do mês: $signal${_money(absoluteNet)} (${_money(income)} de entrada e ${_money(expenses)} de saída).',
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'Calculado automaticamente a partir das movimentações reais do mês.',
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

    late final AreaStatus status;
    late final String action;

    if (ratio <= 0.90) {
      status = AreaStatus.excellent;
      action = 'Seu orçamento está sob controle.';
    } else if (ratio <= 1.0) {
      status = AreaStatus.good;
      action = 'Está no limite, mas ainda controlado.';
    } else if (ratio <= 1.15) {
      status = AreaStatus.attention;
      action = 'Você passou um pouco do orçamento. Vale corrigir logo.';
    } else {
      status = AreaStatus.critical;
      action = 'Orçamento estourado. Reorganize prioridades.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason:
          'Gastos reais de ${_money(expenses)} frente a orçamento manual de ${_money(budget)}.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: 'Combina gastos reais da aba Finanças com orçamento manual.',
    );
  }

  AreaAssessment _assessDebts(_FinanceSnapshot s) {
    final debts = s.debts;
    final income = s.income;

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
        score: _scoreFromStatus(AreaStatus.excellent),
        reason: 'Nenhuma dívida relevante registrada.',
        source: AreaDataSource.manual,
        lastUpdatedAt: s.updatedAt,
        recommendedAction: 'Continue mantendo esse controle.',
        details: 'Subárea baseada no total de dívidas informado manualmente.',
      );
    }

    if (income == null || income <= 0) {
      return AreaAssessment(
        status: AreaStatus.attention,
        score: _scoreFromStatus(AreaStatus.attention),
        reason:
            'Há ${_money(debts)} em dívidas, mas faltam entradas do mês para comparar o peso.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: s.updatedAt,
        recommendedAction:
            'Registre entradas ou atualize a renda para medir melhor essa pressão.',
        details:
            'Combina dívida manual com entradas reais do mês quando disponíveis.',
      );
    }

    final ratio = debts / income;

    late final AreaStatus status;
    late final String action;

    if (ratio <= 0.5) {
      status = AreaStatus.good;
      action = 'Dívidas em nível administrável. Mantenha atenção.';
    } else if (ratio <= 1.5) {
      status = AreaStatus.attention;
      action = 'O peso das dívidas já merece um plano de redução.';
    } else {
      status = AreaStatus.critical;
      action = 'Dívidas muito altas em relação à renda. Prioridade máxima.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason:
          'Dívidas de ${_money(debts)}, cerca de ${(ratio * 100).toStringAsFixed(0)}% das entradas do mês.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: 'Combina dívida manual com entradas reais lançadas em Finanças.',
    );
  }

  AreaAssessment _assessSavings(_FinanceSnapshot s) {
    final reserve = s.reserve;
    final expenses = s.expenses;

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
        score: _scoreFromStatus(AreaStatus.critical),
        reason: 'Nenhuma reserva registrada até agora.',
        source: AreaDataSource.manual,
        lastUpdatedAt: s.updatedAt,
        recommendedAction: 'Comece montando uma reserva, mesmo que pequena.',
        details:
            'Subárea baseada na reserva de emergência informada manualmente.',
      );
    }

    if (expenses == null || expenses <= 0) {
      return AreaAssessment(
        status: AreaStatus.good,
        score: _scoreFromStatus(AreaStatus.good),
        reason: 'Reserva de ${_money(reserve)} registrada.',
        source: AreaDataSource.mixed,
        lastUpdatedAt: s.updatedAt,
        recommendedAction: 'Registre gastos mensais para medir cobertura.',
        details: 'Falta gasto real do mês para calcular meses de proteção.',
      );
    }

    final monthsCovered = reserve / expenses;

    late final AreaStatus status;
    late final String action;

    if (monthsCovered >= 6) {
      status = AreaStatus.excellent;
      action = 'Excelente segurança financeira de curto prazo.';
    } else if (monthsCovered >= 3) {
      status = AreaStatus.good;
      action = 'Boa reserva. Continue fortalecendo.';
    } else if (monthsCovered >= 1) {
      status = AreaStatus.attention;
      action = 'Reserva ainda curta. Vale aumentar aos poucos.';
    } else {
      status = AreaStatus.critical;
      action = 'Proteção financeira muito baixa para imprevistos.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason:
          'Reserva de ${_money(reserve)}, cobrindo cerca de ${monthsCovered.toStringAsFixed(1)} meses dos gastos atuais.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: 'Combina reserva manual com gastos reais do mês.',
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

    final progress = p.clamp(0, 100).toDouble();

    late final AreaStatus status;
    late final String action;

    if (progress >= 80) {
      status = AreaStatus.excellent;
      action = 'Metas financeiras andando muito bem.';
    } else if (progress >= 55) {
      status = AreaStatus.good;
      action = 'Bom progresso. Continue mantendo ritmo.';
    } else if (progress >= 25) {
      status = AreaStatus.attention;
      action = 'Progresso ainda lento. Vale revisar foco.';
    } else {
      status = AreaStatus.critical;
      action = 'Metas quase paradas. Replaneje as próximas ações.';
    }

    return AreaAssessment(
      status: status,
      score: _scoreFromStatus(status),
      reason:
          'Progresso financeiro registrado em ${progress.toStringAsFixed(0)}%.',
      source: AreaDataSource.manual,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: 'Subárea baseada no andamento manual das metas financeiras.',
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
    if (statuses.contains(AreaStatus.attention)) return AreaStatus.attention;
    if (statuses.contains(AreaStatus.good)) return AreaStatus.good;
    if (statuses.contains(AreaStatus.excellent)) return AreaStatus.excellent;

    return AreaStatus.noData;
  }

  Future<int?> score(String areaId, List<String> itemIds) async {
    int sum = 0;
    int count = 0;

    for (final itemId in itemIds) {
      final assessment = await getComputedAssessment(areaId, itemId);
      if (assessment == null || assessment.status == AreaStatus.noData) {
        continue;
      }

      sum += assessment.score ?? _scoreFromStatus(assessment.status);
      count += 1;
    }

    if (count == 0) return null;
    return (sum / count).round().clamp(0, 100);
  }

  int _scoreFromStatus(AreaStatus status) {
    switch (status) {
      case AreaStatus.excellent:
        return 92;
      case AreaStatus.good:
        return 74;
      case AreaStatus.attention:
        return 52;
      case AreaStatus.critical:
        return 28;
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
