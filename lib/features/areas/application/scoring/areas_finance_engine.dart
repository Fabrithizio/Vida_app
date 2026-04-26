// ============================================================================
// FILE: lib/features/areas/application/scoring/areas_finance_engine.dart
//
// O que faz:
// - Calcula a área Finanças & Material usando Finanças real + fallback do check-in
//
// Revisão desta versão:
// - integra AreasConfidenceEngine
// - usa confiança menor para dado manual isolado
// - usa confiança maior para transação real e snapshot recente
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/areas/application/scoring/areas_confidence_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';

class AreasFinanceEngine {
  AreasFinanceEngine({
    required FinanceRepository financeRepository,
    required AreasDailyQuestionsEngine dailyQuestions,
    AreasConfidenceEngine? confidenceEngine,
  }) : _financeRepository = financeRepository,
       _dailyQuestions = dailyQuestions,
       _confidence = confidenceEngine ?? const AreasConfidenceEngine();

  final FinanceRepository _financeRepository;
  final AreasDailyQuestionsEngine _dailyQuestions;
  final AreasConfidenceEngine _confidence;

  Future<AreaAssessment?> computedFinanceItem(
    String uid,
    String itemId, {
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = await _readFinanceSnapshot(prefs, uid);

    if (itemId == 'spending' && snapshot.expenses == null) {
      final fallback = await _spendingAssessmentFromDailyCheckin(
        onAreaUpdated: onAreaUpdated,
      );
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
        return null;
    }
  }

  Future<AreaAssessment?> _spendingAssessmentFromDailyCheckin({
    Future<void> Function(String areaId)? onAreaUpdated,
  }) {
    final today = DateTime.now();

    return _dailyQuestions.assessmentFromDailyQuestions(
      areaId: 'finance_material',
      day: today,
      questionIds: const ['money_pressure_mind'],
      positiveReason: 'Seu controle recente de gastos parece bom.',
      negativeReason: 'Seu cuidado recente com gastos parece fraco.',
      positiveAction: 'Continue registrando e mantendo esse controle.',
      negativeAction: 'Tente registrar gastos e reduzir despesas impulsivas.',
      details:
          'Estimativa baseada nas respostas recentes do check-in sobre finanças.',
      estimated: true,
      onAreaUpdated: onAreaUpdated,
    );
  }

  Future<FinanceSnapshot> _readFinanceSnapshot(
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

    return FinanceSnapshot(
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

  AreaAssessment _assessIncome(FinanceSnapshot s) {
    final income = s.income;
    if (income == null) {
      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: 'Ainda não há entradas registradas neste mês em Finanças.',
        action: 'Adicione entradas na aba Finanças para ativar esta subárea.',
      );
    }

    late final int rawScore;
    late final String reason;
    late final String details;

    final expenses = s.expenses;

    if (expenses != null && expenses > 0) {
      final coverage = income / expenses;
      rawScore = _scoreFromStops(coverage, const [
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
      rawScore = _scoreFromStops(income, const [
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

    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.automatic,
      snapshot: s,
      filledCount: s.transactionCount > 0 ? 1 : 0,
      expectedCount: 1,
    );
    final status = _statusFromNumericScore(finalScore);
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
      score: finalScore,
      reason: reason,
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: '$details Score final ajustado pela confiança da fonte.',
    );
  }

  AreaAssessment _assessSpending(FinanceSnapshot s) {
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

    late final int rawScore;
    late final String reason;
    late final String details;
    late final AreaDataSource source;

    if (income != null && income > 0) {
      final ratio = expenses / income;
      rawScore = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.30, 92),
        _ScoreStop(0.55, 82),
        _ScoreStop(0.80, 68),
        _ScoreStop(1.00, 50),
        _ScoreStop(1.15, 34),
        _ScoreStop(1.40, 18),
        _ScoreStop(2.00, 5),
      ]);
      source = AreaDataSource.automatic;
      reason =
          'Gastos reais de ${_money(expenses)} para entradas reais de ${_money(income)} (${(ratio * 100).toStringAsFixed(0)}% da renda).';
      details =
          'Quanto menor o peso dos gastos sobre a renda real do mês, maior a nota.';
    } else if (budget != null && budget > 0) {
      final ratio = expenses / budget;
      rawScore = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.50, 90),
        _ScoreStop(0.80, 76),
        _ScoreStop(1.00, 58),
        _ScoreStop(1.10, 42),
        _ScoreStop(1.25, 25),
        _ScoreStop(1.50, 10),
        _ScoreStop(2.00, 5),
      ]);
      source = AreaDataSource.mixed;
      reason =
          'Gastos reais de ${_money(expenses)} comparados ao orçamento manual de ${_money(budget)}.';
      details =
          'Como faltam entradas reais, a nota usa o orçamento como referência principal.';
    } else {
      rawScore = 50;
      source = AreaDataSource.estimated;
      reason =
          'Há ${_money(expenses)} em gastos, mas ainda faltam entradas ou orçamento para medir o peso real.';
      details =
          'Sem uma referência confiável, esta subárea fica provisoriamente no meio da escala.';
    }

    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: source,
      snapshot: s,
      filledCount: [
        if (expenses != null) 1,
        if (income != null) 1,
        if (budget != null) 1,
      ].length,
      expectedCount: 3,
    );

    final status = _statusFromNumericScore(finalScore);
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
      score: finalScore,
      reason: reason,
      source: source,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: '$details Score final ajustado pela confiança da fonte.',
    );
  }

  AreaAssessment _assessMonthlyFlow(FinanceSnapshot s) {
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
        score: 40,
        reason:
            'Ainda faltam dados completos de entradas e saídas para medir seu fluxo do mês.',
        source: AreaDataSource.estimated,
        lastUpdatedAt: s.updatedAt,
        recommendedAction:
            'Registre entradas e saídas para o fluxo ficar confiável.',
        details: 'Subárea depende das movimentações reais deste mês.',
      );
    }

    final net = income - expenses;
    final margin = net / income;

    final rawScore = _scoreFromStops(margin, const [
      _ScoreStop(-1.00, 0),
      _ScoreStop(-0.50, 10),
      _ScoreStop(-0.20, 25),
      _ScoreStop(0.00, 45),
      _ScoreStop(0.10, 60),
      _ScoreStop(0.20, 75),
      _ScoreStop(0.35, 90),
      _ScoreStop(0.60, 100),
    ]);

    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.automatic,
      snapshot: s,
      filledCount: 2,
      expectedCount: 2,
    );

    final status = _statusFromNumericScore(finalScore);
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
      score: finalScore,
      reason:
          'Fluxo do mês: $signal${_money(absoluteNet)} (${_money(income)} de entrada e ${_money(expenses)} de saída).',
      source: AreaDataSource.automatic,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'Calculado automaticamente pela margem do mês: quanto maior a sobra sobre a renda, maior a nota.',
    );
  }

  AreaAssessment _assessBudget(FinanceSnapshot s) {
    final budget = s.budget;
    final expenses = s.expenses;

    if (budget == null) {
      return _noDataAssessment(
        source: AreaDataSource.manual,
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
        source: AreaDataSource.manual,
        reason: 'Orçamento inválido ou zerado.',
        action: 'Defina um orçamento mensal realista.',
      );
    }

    final ratio = expenses / budget;
    final rawScore = _scoreFromStops(ratio, const [
      _ScoreStop(0.00, 100),
      _ScoreStop(0.50, 92),
      _ScoreStop(0.80, 78),
      _ScoreStop(1.00, 60),
      _ScoreStop(1.10, 45),
      _ScoreStop(1.25, 28),
      _ScoreStop(1.50, 12),
      _ScoreStop(2.00, 0),
    ]);

    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.mixed,
      snapshot: s,
      filledCount: 2,
      expectedCount: 2,
    );

    final status = _statusFromNumericScore(finalScore);
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
      score: finalScore,
      reason:
          'Gastos reais de ${_money(expenses)} frente a orçamento manual de ${_money(budget)}.',
      source: AreaDataSource.mixed,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'A nota cai gradualmente conforme os gastos se aproximam ou passam do orçamento.',
    );
  }

  AreaAssessment _assessDebts(FinanceSnapshot s) {
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
        score: 96,
        reason: 'Nenhuma dívida relevante registrada.',
        source: AreaDataSource.manual,
        lastUpdatedAt: s.updatedAt,
        recommendedAction: 'Continue mantendo esse controle.',
        details: 'Subárea baseada no total de dívidas informado manualmente.',
      );
    }

    late final int rawScore;
    late final String reason;
    late final String details;
    late final AreaDataSource source;

    if (income != null && income > 0) {
      final ratio = debts / income;
      rawScore = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.25, 88),
        _ScoreStop(0.50, 72),
        _ScoreStop(1.00, 48),
        _ScoreStop(1.50, 28),
        _ScoreStop(2.00, 14),
        _ScoreStop(3.00, 5),
      ]);
      source = AreaDataSource.mixed;
      reason =
          'Dívidas de ${_money(debts)}, cerca de ${(ratio * 100).toStringAsFixed(0)}% das entradas do mês.';
      details =
          'Quanto maior o peso das dívidas sobre a renda do mês, menor a nota.';
    } else if (budget != null && budget > 0) {
      final ratio = debts / budget;
      rawScore = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.30, 82),
        _ScoreStop(0.60, 64),
        _ScoreStop(1.00, 42),
        _ScoreStop(1.50, 22),
        _ScoreStop(2.50, 8),
      ]);
      source = AreaDataSource.mixed;
      reason =
          'Dívidas de ${_money(debts)} em comparação ao orçamento mensal de ${_money(budget)}.';
      details =
          'Como faltam entradas, o peso das dívidas foi comparado ao orçamento atual.';
    } else if (expenses != null && expenses > 0) {
      final ratio = debts / expenses;
      rawScore = _scoreFromStops(ratio, const [
        _ScoreStop(0.00, 100),
        _ScoreStop(0.30, 80),
        _ScoreStop(0.60, 62),
        _ScoreStop(1.00, 42),
        _ScoreStop(1.50, 24),
        _ScoreStop(2.50, 8),
      ]);
      source = AreaDataSource.mixed;
      reason =
          'Dívidas de ${_money(debts)} em comparação aos gastos atuais de ${_money(expenses)}.';
      details =
          'Como faltam entradas, o peso das dívidas foi comparado ao padrão de gastos do mês.';
    } else {
      rawScore = _scoreFromStops(debts, const [
        _ScoreStop(0, 100),
        _ScoreStop(500, 82),
        _ScoreStop(1500, 62),
        _ScoreStop(3000, 40),
        _ScoreStop(6000, 20),
        _ScoreStop(10000, 5),
      ]);
      source = AreaDataSource.manual;
      reason = 'Dívidas registradas em ${_money(debts)}.';
      details =
          'Sem referência mensal suficiente, a nota usa apenas o valor absoluto das dívidas.';
    }

    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: source,
      snapshot: s,
      filledCount: [
        if (debts != null) 1,
        if (income != null || budget != null || expenses != null) 1,
      ].length,
      expectedCount: 2,
    );

    final status = _statusFromNumericScore(finalScore);
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
      score: finalScore,
      reason: reason,
      source: source,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: details,
    );
  }

  AreaAssessment _assessSavings(FinanceSnapshot s) {
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

    late final int rawScore;
    late final String reason;
    late final String details;
    late final AreaDataSource source;

    if (expenses != null && expenses > 0) {
      final monthsCovered = reserve / expenses;
      rawScore = _scoreFromStops(monthsCovered, const [
        _ScoreStop(0.0, 5),
        _ScoreStop(0.5, 18),
        _ScoreStop(1.0, 35),
        _ScoreStop(2.0, 55),
        _ScoreStop(3.0, 70),
        _ScoreStop(6.0, 90),
        _ScoreStop(12.0, 100),
      ]);
      source = AreaDataSource.mixed;
      reason =
          'Reserva de ${_money(reserve)}, cobrindo cerca de ${monthsCovered.toStringAsFixed(1)} meses dos gastos atuais.';
      details =
          'A nota sobe conforme a reserva cobre mais meses do seu custo atual.';
    } else if (income != null && income > 0) {
      final monthsCovered = reserve / income;
      rawScore = _scoreFromStops(monthsCovered, const [
        _ScoreStop(0.0, 10),
        _ScoreStop(0.5, 25),
        _ScoreStop(1.0, 40),
        _ScoreStop(2.0, 58),
        _ScoreStop(3.0, 72),
        _ScoreStop(6.0, 90),
        _ScoreStop(12.0, 100),
      ]);
      source = AreaDataSource.mixed;
      reason =
          'Reserva de ${_money(reserve)}, equivalente a ${monthsCovered.toStringAsFixed(1)} meses de entrada atual.';
      details =
          'Como faltam gastos suficientes, a cobertura foi estimada sobre a renda do mês.';
    } else {
      rawScore = _scoreFromStops(reserve, const [
        _ScoreStop(0, 5),
        _ScoreStop(500, 18),
        _ScoreStop(1500, 32),
        _ScoreStop(3000, 48),
        _ScoreStop(6000, 64),
        _ScoreStop(12000, 82),
        _ScoreStop(25000, 100),
      ]);
      source = AreaDataSource.manual;
      reason = 'Reserva de ${_money(reserve)} registrada.';
      details =
          'Sem referência mensal suficiente, a nota usa o crescimento absoluto da reserva.';
    }

    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: source,
      snapshot: s,
      filledCount: [
        if (reserve != null) 1,
        if (expenses != null || income != null) 1,
      ].length,
      expectedCount: 2,
    );

    final status = _statusFromNumericScore(finalScore);
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
      score: finalScore,
      reason: reason,
      source: source,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details: details,
    );
  }

  AreaAssessment _assessFinanceGoals(FinanceSnapshot s) {
    final p = s.goalsProgress;
    if (p == null) {
      return _noDataAssessment(
        source: AreaDataSource.manual,
        reason: 'Sem progresso de metas financeiras informado.',
        action: 'Informe o avanço das suas metas financeiras.',
      );
    }

    final rawScore = p.clamp(0, 100).round();
    final finalScore = _effectiveScore(
      rawScore: rawScore,
      source: AreaDataSource.manual,
      snapshot: s,
      filledCount: 1,
      expectedCount: 1,
    );
    final status = _statusFromNumericScore(finalScore);

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
      score: finalScore,
      reason:
          'Progresso financeiro registrado em ${rawScore.toStringAsFixed(0)}%.',
      source: AreaDataSource.manual,
      lastUpdatedAt: s.updatedAt,
      recommendedAction: action,
      details:
          'Subárea baseada diretamente no avanço percentual informado para as metas financeiras.',
    );
  }

  int _effectiveScore({
    required int rawScore,
    required AreaDataSource source,
    required FinanceSnapshot snapshot,
    required int filledCount,
    required int expectedCount,
  }) {
    return _confidence.effectiveScore(
      rawScore: rawScore,
      source: source,
      daysSinceUpdate: _daysSince(snapshot.updatedAt),
      consistency01: _consistencyFromSnapshot(snapshot),
      completeness01: _confidence.completenessFromCounts(
        filledCount: filledCount,
        expectedCount: expectedCount,
      ),
    );
  }

  double _consistencyFromSnapshot(FinanceSnapshot snapshot) {
    final scores = <int>[];
    if (snapshot.income != null)
      scores.add(snapshot.income!.clamp(0, 10000).round() % 100);
    if (snapshot.expenses != null)
      scores.add(snapshot.expenses!.clamp(0, 10000).round() % 100);
    if (snapshot.budget != null)
      scores.add(snapshot.budget!.clamp(0, 10000).round() % 100);
    if (scores.length < 2) return 1.0;
    return _confidence.consistencyFromHistory(scores);
  }

  int _daysSince(DateTime? date) {
    if (date == null) return 30;
    return DateTime.now().difference(date).inDays.clamp(0, 365);
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

class FinanceSnapshot {
  const FinanceSnapshot({
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

class _ScoreStop {
  const _ScoreStop(this.x, this.score);

  final double x;
  final int score;
}
