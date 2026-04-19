// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance_tab.dart
//
// Tela principal de Finanças do Vida, agora refatorada.
//
// O que este arquivo faz:
// - Orquestra a home financeira e as 4 áreas internas: Visão, Planejar,
//   Investir e Controle.
// - Mantém a lógica de preferências locais, privacidade e simulações.
// - Delega widgets e modelos para arquivos separados, deixando a manutenção
//   muito mais simples do que antes.
// - Continua compatível com o FinanceStore e com o AddTransactionPage atuais.
// ============================================================================

import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/finance_seed_data.dart';
import '../../data/models/finance_category.dart';
import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_transaction_source.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';
import 'add_transaction_page.dart';
import 'finance/finance_market_service.dart';
import 'finance/finance_planning_catalog.dart';
import 'finance/finance_tab_models.dart';
import 'finance/finance_tab_utils.dart';
import 'finance/finance_tab_widgets.dart';

String _financePeriodLabel(FinancePeriodType period) {
  switch (period) {
    case FinancePeriodType.currentMonth:
      return 'Este mês';
    case FinancePeriodType.previousMonth:
      return 'Mês passado';
    case FinancePeriodType.currentYear:
      return 'Este ano';
    case FinancePeriodType.allTime:
      return 'Tudo';
  }
}

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key, this.store});

  final FinanceStore? store;

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  late final FinanceStore _store;

  bool _loadingPrefs = true;
  bool _hideValues = false;
  int _currentSection = 0;

  int _planningPresetIndex = 0;
  double _monthlyIncomePlan = 0;
  double _planningEssentialPercent = 60;
  double _planningFuturePercent = 30;
  double _planningFreePercent = 10;
  Map<String, double> _plannedByCategory = <String, double>{};
  Set<String> _activePlanningCategoryIds = <String>{};
  bool _planningOwnHome = false;
  bool _planningMealTicket = false;
  bool _planningNoCar = false;
  bool _planningFreeTransit = false;
  bool _planningHasHealthPlan = false;

  double _investedPrincipal = 0;
  double _investedCurrentValue = 0;
  double _monthlyInvestmentContribution = 0;
  double _annualInterestRate = 10;
  double _investmentTarget = 0;

  Map<String, double> _investmentBucketPrincipal = <String, double>{};
  Map<String, double> _investmentBucketCurrent = <String, double>{};
  Map<String, double> _investmentBucketMonthly = <String, double>{};
  Map<String, String> _investmentBucketProfileIds = <String, String>{};
  Map<String, double> _investmentBucketCustomRate = <String, double>{};
  Map<String, double> _investmentBucketGoal = <String, double>{};
  FinanceMarketSnapshot? _marketSnapshot;
  bool _loadingMarket = false;
  String? _marketError;

  String get _prefsPrefix {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    return (uid == null || uid.isEmpty) ? 'anon' : uid;
  }

  List<FinancePlanningPreset> get _planningPresets => const [
    FinancePlanningPreset(
      label: '60/30/10',
      essential: 60,
      future: 30,
      free: 10,
    ),
    FinancePlanningPreset(
      label: '70/20/10',
      essential: 70,
      future: 20,
      free: 10,
    ),
    FinancePlanningPreset(
      label: '50/30/20',
      essential: 50,
      future: 30,
      free: 20,
    ),
    FinancePlanningPreset(
      label: '80/10/10',
      essential: 80,
      future: 10,
      free: 10,
    ),
  ];

  List<FinanceCategory> get _planningCategories => _store.categories
      .where((item) => item.isIncomeCategory != true)
      .cast<FinanceCategory>()
      .toList();

  List<FinanceInvestmentBucketConfig> get _investmentBucketConfigs => const [
    FinanceInvestmentBucketConfig(
      id: 'reserve',
      title: 'Reserva de emergência',
      subtitle: 'Liquidez e proteção',
      icon: Icons.shield_outlined,
      color: Color(0xFF39D0FF),
      riskLevel: 1,
    ),
    FinanceInvestmentBucketConfig(
      id: 'fixed_income',
      title: 'Renda fixa',
      subtitle: 'Mais previsibilidade',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF9CFF3F),
      riskLevel: 2,
    ),
    FinanceInvestmentBucketConfig(
      id: 'variable_income',
      title: 'Renda variável',
      subtitle: 'Crescimento e dividendos',
      icon: Icons.show_chart_rounded,
      color: Color(0xFF6C63FF),
      riskLevel: 4,
    ),
    FinanceInvestmentBucketConfig(
      id: 'self_growth',
      title: 'Você / negócio',
      subtitle: 'Cursos, negócio e evolução',
      icon: Icons.rocket_launch_outlined,
      color: Color(0xFFFFB020),
      riskLevel: 3,
    ),
  ];

  List<FinanceInvestmentProductProfile> get _investmentProfiles => const [
    FinanceInvestmentProductProfile(
      id: 'reserve_cdi_100',
      title: 'Reserva 100% CDI',
      subtitle: 'Liquidez com benchmark CDI.',
      benchmarkType: FinanceInvestmentBenchmarkType.cdi,
      multiplier: 1.0,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.regressiveFixedIncome,
      isVariableIncome: false,
      badge: '100% CDI',
    ),
    FinanceInvestmentProductProfile(
      id: 'nubank_turbo_115',
      title: 'Caixinha Turbo 115% CDI',
      subtitle: 'Modelo de caixinha turbo atrelada ao CDI.',
      benchmarkType: FinanceInvestmentBenchmarkType.cdi,
      multiplier: 1.15,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.regressiveFixedIncome,
      isVariableIncome: false,
      badge: '115% CDI',
    ),
    FinanceInvestmentProductProfile(
      id: 'cdb_110_cdi',
      title: 'CDB 110% CDI',
      subtitle: 'Renda fixa bancária com IR regressivo.',
      benchmarkType: FinanceInvestmentBenchmarkType.cdi,
      multiplier: 1.10,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.regressiveFixedIncome,
      isVariableIncome: false,
      badge: '110% CDI',
    ),
    FinanceInvestmentProductProfile(
      id: 'tesouro_selic',
      title: 'Tesouro Selic',
      subtitle: 'Tende a acompanhar a Selic.',
      benchmarkType: FinanceInvestmentBenchmarkType.selic,
      multiplier: 1.0,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.regressiveFixedIncome,
      isVariableIncome: false,
      badge: 'Selic',
    ),
    FinanceInvestmentProductProfile(
      id: 'tesouro_ipca_6',
      title: 'Tesouro IPCA+',
      subtitle: 'Proteção real acima da inflação.',
      benchmarkType: FinanceInvestmentBenchmarkType.ipca,
      multiplier: 1.0,
      spreadAnnual: 6.0,
      taxRule: FinanceInvestmentTaxRule.regressiveFixedIncome,
      isVariableIncome: false,
      badge: 'IPCA+',
    ),
    FinanceInvestmentProductProfile(
      id: 'prefixado_custom',
      title: 'Prefixado / taxa fixa',
      subtitle: 'Taxa anual contratada.',
      benchmarkType: FinanceInvestmentBenchmarkType.fixed,
      multiplier: 1.0,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.regressiveFixedIncome,
      isVariableIncome: false,
      badge: 'Taxa fixa',
    ),
    FinanceInvestmentProductProfile(
      id: 'acoes_growth',
      title: 'Ações / ETFs',
      subtitle: 'Estimativa própria para renda variável.',
      benchmarkType: FinanceInvestmentBenchmarkType.custom,
      multiplier: 1.0,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.variableIncome15,
      isVariableIncome: true,
      badge: 'Variável',
    ),
    FinanceInvestmentProductProfile(
      id: 'business_custom',
      title: 'Negócio / crescimento próprio',
      subtitle: 'Use taxa própria para crescimento.',
      benchmarkType: FinanceInvestmentBenchmarkType.custom,
      multiplier: 1.0,
      spreadAnnual: 0,
      taxRule: FinanceInvestmentTaxRule.customNone,
      isVariableIncome: true,
      badge: 'Custom',
    ),
  ];

  String _defaultInvestmentProfileIdForBucket(String bucketId) {
    switch (bucketId) {
      case 'reserve':
        return 'nubank_turbo_115';
      case 'fixed_income':
        return 'cdb_110_cdi';
      case 'variable_income':
        return 'acoes_growth';
      case 'self_growth':
        return 'business_custom';
      default:
        return 'reserve_cdi_100';
    }
  }

  FinanceInvestmentProductProfile _profileById(String id) {
    return _investmentProfiles.firstWhere(
      (item) => item.id == id,
      orElse: () => _investmentProfiles.first,
    );
  }

  Set<String> _defaultActivePlanningIds() {
    return FinancePlanningCatalog.defaultActiveIds(_planningCategories).toSet();
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? FinanceStore();
    _boot();
  }

  Future<void> _boot() async {
    if (!_store.hasLoaded && !_store.isLoading) {
      await _store.load();
    }
    await _loadPrefs();
    await _refreshMarketData(silent: true);
  }

  Future<void> _refreshAll() async {
    await _store.load();
    await _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nextPlanned = <String, double>{};

    for (final category in _planningCategories) {
      nextPlanned[category.id] =
          prefs.getDouble('$_prefsPrefix:plan:${category.id}') ?? 0;
    }

    final rawActiveIds = prefs.getStringList(
      '$_prefsPrefix:finance_plan_active_ids',
    );
    final knownIds = _planningCategories.map((item) => item.id).toSet();
    final activeIds = (rawActiveIds == null || rawActiveIds.isEmpty)
        ? _defaultActivePlanningIds()
        : rawActiveIds.where(knownIds.contains).toSet();

    final nextBucketPrincipal = <String, double>{};
    final nextBucketCurrent = <String, double>{};
    final nextBucketMonthly = <String, double>{};
    final nextBucketProfileIds = <String, String>{};
    final nextBucketCustomRate = <String, double>{};
    final nextBucketGoal = <String, double>{};
    for (final bucket in _investmentBucketConfigs) {
      nextBucketPrincipal[bucket.id] =
          prefs.getDouble(
            '$_prefsPrefix:invest_bucket:${bucket.id}:principal',
          ) ??
          0;
      nextBucketCurrent[bucket.id] =
          prefs.getDouble('$_prefsPrefix:invest_bucket:${bucket.id}:current') ??
          0;
      nextBucketMonthly[bucket.id] =
          prefs.getDouble('$_prefsPrefix:invest_bucket:${bucket.id}:monthly') ??
          0;
      nextBucketProfileIds[bucket.id] =
          prefs.getString('$_prefsPrefix:invest_bucket:${bucket.id}:profile') ??
          _defaultInvestmentProfileIdForBucket(bucket.id);
      nextBucketCustomRate[bucket.id] =
          prefs.getDouble(
            '$_prefsPrefix:invest_bucket:${bucket.id}:custom_rate',
          ) ??
          0;
      nextBucketGoal[bucket.id] =
          prefs.getDouble('$_prefsPrefix:invest_bucket:${bucket.id}:goal') ?? 0;
    }

    final hasBucketData =
        nextBucketCurrent.values.any((value) => value > 0.01) ||
        nextBucketPrincipal.values.any((value) => value > 0.01) ||
        nextBucketMonthly.values.any((value) => value > 0.01);

    if (!hasBucketData) {
      nextBucketPrincipal['fixed_income'] =
          prefs.getDouble('$_prefsPrefix:invest_principal') ?? 0;
      nextBucketCurrent['fixed_income'] =
          prefs.getDouble('$_prefsPrefix:invest_current_value') ?? 0;
      nextBucketMonthly['fixed_income'] =
          prefs.getDouble('$_prefsPrefix:invest_monthly_contribution') ?? 0;
    }

    if (!mounted) return;

    setState(() {
      _hideValues = prefs.getBool('$_prefsPrefix:finance_hide_values') ?? false;
      _planningPresetIndex =
          prefs.getInt('$_prefsPrefix:finance_plan_preset') ?? 0;
      _monthlyIncomePlan =
          prefs.getDouble('$_prefsPrefix:finance_income_plan') ?? 0;
      _planningEssentialPercent =
          prefs.getDouble('$_prefsPrefix:finance_plan_essentials_percent') ??
          60;
      _planningFuturePercent =
          prefs.getDouble('$_prefsPrefix:finance_plan_future_percent') ?? 30;
      _planningFreePercent =
          prefs.getDouble('$_prefsPrefix:finance_plan_free_percent') ?? 10;
      _plannedByCategory = nextPlanned;
      _activePlanningCategoryIds = activeIds;
      _planningOwnHome =
          prefs.getBool('$_prefsPrefix:plan_life_own_home') ?? false;
      _planningMealTicket =
          prefs.getBool('$_prefsPrefix:plan_life_meal_ticket') ?? false;
      _planningNoCar = prefs.getBool('$_prefsPrefix:plan_life_no_car') ?? false;
      _planningFreeTransit =
          prefs.getBool('$_prefsPrefix:plan_life_free_transit') ?? false;
      _planningHasHealthPlan =
          prefs.getBool('$_prefsPrefix:plan_life_health_plan') ?? false;
      _investedPrincipal =
          prefs.getDouble('$_prefsPrefix:invest_principal') ?? 0;
      _investedCurrentValue =
          prefs.getDouble('$_prefsPrefix:invest_current_value') ?? 0;
      _monthlyInvestmentContribution =
          prefs.getDouble('$_prefsPrefix:invest_monthly_contribution') ?? 0;
      _annualInterestRate =
          prefs.getDouble('$_prefsPrefix:invest_annual_rate') ?? 10;
      _investmentTarget = prefs.getDouble('$_prefsPrefix:invest_target') ?? 0;
      _investmentBucketPrincipal = nextBucketPrincipal;
      _investmentBucketCurrent = nextBucketCurrent;
      _investmentBucketMonthly = nextBucketMonthly;
      _investmentBucketProfileIds = nextBucketProfileIds;
      _investmentBucketCustomRate = nextBucketCustomRate;
      _investmentBucketGoal = nextBucketGoal;
      _loadingPrefs = false;
    });
  }

  Future<void> _refreshMarketData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loadingMarket = true;
        _marketError = null;
      });
    } else {
      _loadingMarket = true;
      _marketError = null;
    }

    try {
      final snapshot = await FinanceMarketService().loadBrazilSnapshot();
      if (!mounted) return;
      setState(() {
        _marketSnapshot = snapshot;
        _loadingMarket = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _marketError = 'Não foi possível atualizar Selic e IPCA agora.';
        _loadingMarket = false;
      });
    }
  }

  Future<void> _togglePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_hideValues;
    await prefs.setBool('$_prefsPrefix:finance_hide_values', next);
    if (!mounted) return;
    setState(() => _hideValues = next);
  }

  Future<void> _applyAdjustmentTransaction({
    required String title,
    required double amount,
    required bool isIncome,
    required FinanceEntryType entryType,
    required String categoryId,
    String? note,
  }) async {
    if (amount.abs() < 0.009) return;
    final category = FinanceSeedData.getCategoryById(categoryId);
    final tx = FinanceTransaction(
      id: 'tx_adjust_${DateTime.now().microsecondsSinceEpoch}_${title.hashCode}',
      title: title,
      amount: amount,
      date: DateTime.now(),
      category: category,
      entryType: entryType,
      source: FinanceTransactionSource.manual,
      isIncome: isIncome,
      note: note ?? 'Ajuste manual do resumo financeiro',
    );
    await _store.addTransaction(tx);
  }

  Future<void> _openQuickAdjustSheet() async {
    final incomeController = TextEditingController(
      text: moneyField(_store.totalIncome),
    );
    final expenseController = TextEditingController(
      text: moneyField(_store.totalExpense),
    );
    final debitController = TextEditingController(
      text: moneyField(_store.totalDebitExpense),
    );
    final creditController = TextEditingController(
      text: moneyField(_store.totalCreditExpense),
    );
    final balanceController = TextEditingController(
      text: moneyField(_store.balance),
    );
    var applyExpenseAsCredit = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FinanceSheetFrame(
              title: 'Ajustar valores do resumo',
              subtitle:
                  'Quando algo ficar diferente do real, você pode corrigir o período atual sem mexer lançamento por lançamento.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FinanceSoftInfoCard(
                    title: 'Como funciona',
                    text:
                        'O app cria lançamentos de correção do período atual. Saldo usa entrada ou débito de ajuste. Se você mexer em débito e crédito, o campo de saídas totais vira só referência.',
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  FinanceTextField(
                    controller: balanceController,
                    label: 'Saldo disponível',
                    prefixText: 'R\$ ',
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceTextField(
                    controller: incomeController,
                    label: 'Entradas do período',
                    prefixText: 'R\$ ',
                    icon: Icons.call_received_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FinanceTextField(
                    controller: expenseController,
                    label: 'Saídas do período',
                    prefixText: 'R\$ ',
                    icon: Icons.call_made_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FinanceTextField(
                          controller: debitController,
                          label: 'Débito',
                          prefixText: 'R\$ ',
                          icon: Icons.account_balance_wallet_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceTextField(
                          controller: creditController,
                          label: 'Crédito',
                          prefixText: 'R\$ ',
                          icon: Icons.credit_card_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Saída extra em débito'),
                        selected: !applyExpenseAsCredit,
                        onSelected: (_) =>
                            setSheetState(() => applyExpenseAsCredit = false),
                      ),
                      ChoiceChip(
                        label: const Text('Saída extra em crédito'),
                        selected: applyExpenseAsCredit,
                        onSelected: (_) =>
                            setSheetState(() => applyExpenseAsCredit = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final targetIncome = parseMoney(incomeController.text);
                        final targetExpense = parseMoney(
                          expenseController.text,
                        );
                        final targetDebit = parseMoney(debitController.text);
                        final targetCredit = parseMoney(creditController.text);
                        final targetBalance = parseMoney(
                          balanceController.text,
                        );

                        final incomeDelta = targetIncome - _store.totalIncome;
                        final debitDelta =
                            targetDebit - _store.totalDebitExpense;
                        final creditDelta =
                            targetCredit - _store.totalCreditExpense;

                        final changedDebitOrCredit =
                            debitDelta.abs() > 0.009 ||
                            creditDelta.abs() > 0.009;

                        final expenseDelta = changedDebitOrCredit
                            ? 0.0
                            : (targetExpense - _store.totalExpense);

                        if (incomeDelta.abs() < 0.009 &&
                            debitDelta.abs() < 0.009 &&
                            creditDelta.abs() < 0.009 &&
                            expenseDelta.abs() < 0.009 &&
                            (targetBalance - _store.balance).abs() < 0.009) {
                          if (context.mounted) Navigator.of(context).pop();
                          return;
                        }

                        if (incomeDelta.abs() > 0.009) {
                          await _applyAdjustmentTransaction(
                            title: 'Ajuste manual de entradas',
                            amount: incomeDelta,
                            isIncome: true,
                            entryType: FinanceEntryType.transferIn,
                            categoryId: 'other_income',
                          );
                        }

                        if (changedDebitOrCredit) {
                          if (debitDelta.abs() > 0.009) {
                            await _applyAdjustmentTransaction(
                              title: 'Ajuste manual de débito',
                              amount: debitDelta,
                              isIncome: false,
                              entryType: FinanceEntryType.debit,
                              categoryId: 'other_expense',
                            );
                          }
                          if (creditDelta.abs() > 0.009) {
                            await _applyAdjustmentTransaction(
                              title: 'Ajuste manual de crédito',
                              amount: creditDelta,
                              isIncome: false,
                              entryType: FinanceEntryType.credit,
                              categoryId: 'debt_credit_card',
                            );
                          }
                        } else if (expenseDelta.abs() > 0.009) {
                          await _applyAdjustmentTransaction(
                            title: applyExpenseAsCredit
                                ? 'Ajuste manual de saídas (crédito)'
                                : 'Ajuste manual de saídas (débito)',
                            amount: expenseDelta,
                            isIncome: false,
                            entryType: applyExpenseAsCredit
                                ? FinanceEntryType.credit
                                : FinanceEntryType.debit,
                            categoryId: 'other_expense',
                          );
                        }

                        await _store.load();
                        final balanceDelta = targetBalance - _store.balance;
                        if (balanceDelta.abs() > 0.009) {
                          if (balanceDelta > 0) {
                            await _applyAdjustmentTransaction(
                              title: 'Ajuste manual de saldo',
                              amount: balanceDelta,
                              isIncome: true,
                              entryType: FinanceEntryType.transferIn,
                              categoryId: 'other_income',
                            );
                          } else {
                            await _applyAdjustmentTransaction(
                              title: 'Ajuste manual de saldo',
                              amount: balanceDelta.abs(),
                              isIncome: false,
                              entryType: FinanceEntryType.debit,
                              categoryId: 'other_expense',
                            );
                          }
                        }

                        if (!mounted) return;
                        Navigator.of(context).pop();
                        await _refreshAll();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Resumo financeiro ajustado.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Salvar ajustes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAddTransactionPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddTransactionPage(store: _store),
      ),
    );
    await _refreshAll();
  }

  Future<void> _openEditTransactionPage(FinanceTransaction transaction) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AddTransactionPage(store: _store, initialTransaction: transaction),
      ),
    );
    await _refreshAll();
  }

  Future<void> _confirmRemoveTransaction(FinanceTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover lançamento'),
        content: Text('Deseja remover "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _store.removeTransaction(transaction.id);
  }

  Future<void> _openPlanningSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final incomeController = TextEditingController(
      text: _monthlyIncomePlan == 0 ? '' : moneyField(_monthlyIncomePlan),
    );
    final controllers = <String, TextEditingController>{
      for (final category in _planningCategories)
        category.id: TextEditingController(
          text: (_plannedByCategory[category.id] ?? 0) <= 0
              ? ''
              : moneyField(_plannedByCategory[category.id] ?? 0),
        ),
    };

    int localPreset = _planningPresetIndex;
    double essential = _planningEssentialPercent;
    double future = _planningFuturePercent;
    double free = _planningFreePercent;
    var localActiveIds = <String>{
      ...(_activePlanningCategoryIds.isEmpty
          ? _defaultActivePlanningIds()
          : _activePlanningCategoryIds),
    };
    bool ownHome = _planningOwnHome;
    bool mealTicket = _planningMealTicket;
    bool noCar = _planningNoCar;
    bool freeTransit = _planningFreeTransit;
    bool hasHealthPlan = _planningHasHealthPlan;
    bool showAllOptional = false;

    Map<String, double> readCurrentValues() {
      return {
        for (final category in _planningCategories)
          category.id: parseMoney(controllers[category.id]!.text),
      };
    }

    double totalAllocated(Map<String, double> values) {
      return localActiveIds.fold<double>(
        0,
        (sum, id) => sum + (values[id] ?? 0),
      );
    }

    Map<String, double> autoPlan() {
      return _autoDistributePlan(
        income: parseMoney(incomeController.text),
        essentialPercent: essential,
        futurePercent: future,
        freePercent: free,
        activeIds: localActiveIds,
        ownHome: ownHome,
        mealTicket: mealTicket,
        noCar: noCar,
        freeTransit: freeTransit,
        hasHealthPlan: hasHealthPlan,
      );
    }

    void applyAutomatic({bool preserveManual = false}) {
      final suggested = autoPlan();
      final currentValues = readCurrentValues();
      for (final category in _planningCategories) {
        final currentValue = currentValues[category.id] ?? 0;
        final nextValue = preserveManual && currentValue > 0
            ? currentValue
            : (suggested[category.id] ?? 0);
        controllers[category.id]!.text = nextValue <= 0
            ? ''
            : moneyField(nextValue);
      }
    }

    String saveProfileLabel() {
      final labels = <String>[];
      if (ownHome) labels.add('casa própria');
      if (mealTicket) labels.add('vale alimentação');
      if (noCar) labels.add('sem carro');
      if (freeTransit) labels.add('passagem grátis');
      if (hasHealthPlan) labels.add('plano de saúde');
      if (labels.isEmpty) return 'Nenhum atalho aplicado.';
      return labels.join(' • ');
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final income = parseMoney(incomeController.text);
            final currentValues = readCurrentValues();
            final allocated = totalAllocated(currentValues);
            final remaining = math.max(0.0, income - allocated).toDouble();
            final activeCategories = _sortedPlanningCategories(localActiveIds);
            final optionalCategories = _sortedPlanningCategories(
              _planningCategories
                  .map((item) => item.id)
                  .toSet()
                  .difference(localActiveIds),
            );

            Future<void> save() async {
              final parsedIncome = parseMoney(incomeController.text);
              var parsedValues = readCurrentValues();
              double allocatedValue = localActiveIds.fold<double>(
                0,
                (sum, id) => sum + (parsedValues[id] ?? 0),
              );

              if (allocatedValue <= 0.01) {
                parsedValues = autoPlan();
                allocatedValue = localActiveIds.fold<double>(
                  0,
                  (sum, id) => sum + (parsedValues[id] ?? 0),
                );
              }

              if (allocatedValue > parsedIncome + 0.1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Os valores planejados passaram da renda do mês.',
                    ),
                  ),
                );
                return;
              }

              final remainder = parsedIncome - allocatedValue;
              if (remainder > 0.01) {
                final receiverId = _pickRemainderCategory(localActiveIds);
                if (receiverId != null) {
                  parsedValues[receiverId] =
                      (parsedValues[receiverId] ?? 0) + remainder;
                  localActiveIds.add(receiverId);
                }
              }

              await prefs.setDouble(
                '$_prefsPrefix:finance_income_plan',
                parsedIncome,
              );
              await prefs.setInt(
                '$_prefsPrefix:finance_plan_preset',
                localPreset,
              );
              await prefs.setDouble(
                '$_prefsPrefix:finance_plan_essentials_percent',
                essential,
              );
              await prefs.setDouble(
                '$_prefsPrefix:finance_plan_future_percent',
                future,
              );
              await prefs.setDouble(
                '$_prefsPrefix:finance_plan_free_percent',
                free,
              );
              await prefs.setStringList(
                '$_prefsPrefix:finance_plan_active_ids',
                localActiveIds.toList(),
              );
              await prefs.setBool('$_prefsPrefix:plan_life_own_home', ownHome);
              await prefs.setBool(
                '$_prefsPrefix:plan_life_meal_ticket',
                mealTicket,
              );
              await prefs.setBool('$_prefsPrefix:plan_life_no_car', noCar);
              await prefs.setBool(
                '$_prefsPrefix:plan_life_free_transit',
                freeTransit,
              );
              await prefs.setBool(
                '$_prefsPrefix:plan_life_health_plan',
                hasHealthPlan,
              );

              for (final category in _planningCategories) {
                await prefs.setDouble(
                  '$_prefsPrefix:plan:${category.id}',
                  parsedValues[category.id] ?? 0,
                );
              }

              if (!mounted) return;
              Navigator.of(context).pop();
              await _loadPrefs();
            }

            Widget buildLifeChip({
              required bool selected,
              required IconData icon,
              required String label,
              required VoidCallback onTap,
            }) {
              return FilterChip(
                selected: selected,
                onSelected: (_) => onTap(),
                avatar: Icon(icon, size: 18),
                label: Text(label),
              );
            }

            Widget buildCategoryEditor(FinanceCategory category) {
              final bucket = FinancePlanningCatalog.bucketOf(category.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF111A1A),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: category.color.withOpacity(0.18),
                          child: Icon(
                            category.icon,
                            color: category.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                FinancePlanningCatalog.bucketLabel(bucket),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.62),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover do plano',
                          onPressed: () {
                            setSheetState(() {
                              localActiveIds.remove(category.id);
                              controllers[category.id]!.text = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controllers[category.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor planejado',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(category.icon),
                      ),
                    ),
                  ],
                ),
              );
            }

            return FinanceSheetFrame(
              title: 'Planejar o mês',
              subtitle:
                  'O app sugere, mas você adapta ao seu jeito de viver. O que você não usa sai da divisão.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FinanceTextField(
                    controller: incomeController,
                    label: 'Renda do mês',
                    prefixText: 'R\$ ',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Modelos rápidos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(_planningPresets.length, (
                      index,
                    ) {
                      final preset = _planningPresets[index];
                      return ChoiceChip(
                        label: Text(preset.label),
                        selected: localPreset == index,
                        onSelected: (_) {
                          setSheetState(() {
                            localPreset = index;
                            essential = preset.essential;
                            future = preset.future;
                            free = preset.free;
                            applyAutomatic();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FinanceMiniPercentCard(
                          label: 'Essenciais',
                          value: essential,
                          color: const Color(0xFF28C76F),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceMiniPercentCard(
                          label: 'Investir + reserva',
                          value: future,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceMiniPercentCard(
                          label: 'Livre',
                          value: free,
                          color: const Color(0xFFFFB020),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Seu jeito de viver',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildLifeChip(
                        selected: ownHome,
                        icon: Icons.home_work_outlined,
                        label: 'Casa própria',
                        onTap: () => setSheetState(() {
                          ownHome = !ownHome;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: mealTicket,
                        icon: Icons.lunch_dining_outlined,
                        label: 'Vale alimentação',
                        onTap: () => setSheetState(() {
                          mealTicket = !mealTicket;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: noCar,
                        icon: Icons.no_crash_outlined,
                        label: 'Sem carro',
                        onTap: () => setSheetState(() {
                          noCar = !noCar;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: freeTransit,
                        icon: Icons.directions_bus_outlined,
                        label: 'Passagem grátis',
                        onTap: () => setSheetState(() {
                          freeTransit = !freeTransit;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: hasHealthPlan,
                        icon: Icons.health_and_safety_outlined,
                        label: 'Plano de saúde',
                        onTap: () => setSheetState(() {
                          hasHealthPlan = !hasHealthPlan;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FinanceSoftInfoCard(
                    title: 'Perfil aplicado',
                    text: saveProfileLabel(),
                    icon: Icons.auto_awesome_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              setSheetState(() => applyAutomatic()),
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Distribuir automático'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setSheetState(
                            () => applyAutomatic(preserveManual: true),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Redistribuir restante'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const FinanceSoftInfoCard(
                    title: 'Como o saldo restante é tratado',
                    text:
                        'Se você reduzir uma categoria e sobrar dinheiro, o restante vai para reserva/caixinha ao salvar.',
                    icon: Icons.savings_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FinanceValueBadge(
                          label: 'Planejado agora',
                          value: formatCurrency(allocated, hideValues: false),
                          color: const Color(0xFF39D0FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceValueBadge(
                          label: 'Ainda sobrando',
                          value: formatCurrency(remaining, hideValues: false),
                          color: const Color(0xFFFFB020),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Categorias do seu plano',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ative só o que faz sentido para sua vida. O resto fica como opção.',
                    style: TextStyle(color: Colors.white.withOpacity(0.68)),
                  ),
                  const SizedBox(height: 12),
                  ...activeCategories.map(buildCategoryEditor),
                  const SizedBox(height: 6),
                  const Text(
                    'Adicionar mais categorias',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category
                          in (showAllOptional
                              ? optionalCategories
                              : optionalCategories.take(12).toList()))
                        ActionChip(
                          avatar: Icon(
                            category.icon,
                            size: 18,
                            color: category.color,
                          ),
                          label: Text(category.name),
                          onPressed: () {
                            setSheetState(() {
                              localActiveIds.add(category.id);
                              final suggested = autoPlan()[category.id] ?? 0;
                              if (parseMoney(controllers[category.id]!.text) <=
                                  0) {
                                controllers[category.id]!.text = suggested <= 0
                                    ? ''
                                    : moneyField(suggested);
                              }
                            });
                          },
                        ),
                      if (optionalCategories.length > 12)
                        ActionChip(
                          avatar: const Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                          ),
                          label: Text(
                            showAllOptional ? 'Ver menos' : 'Ver mais',
                          ),
                          onPressed: () => setSheetState(() {
                            showAllOptional = !showAllOptional;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Salvar planejamento'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInvestmentSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final rateController = TextEditingController(
      text: _annualInterestRate == 0
          ? ''
          : _annualInterestRate.toStringAsFixed(2),
    );
    final targetController = TextEditingController(
      text: _investmentTarget == 0 ? '' : moneyField(_investmentTarget),
    );
    final principalControllers = <String, TextEditingController>{
      for (final bucket in _investmentBucketConfigs)
        bucket.id: TextEditingController(
          text: (_investmentBucketPrincipal[bucket.id] ?? 0) <= 0
              ? ''
              : moneyField(_investmentBucketPrincipal[bucket.id] ?? 0),
        ),
    };
    final currentControllers = <String, TextEditingController>{
      for (final bucket in _investmentBucketConfigs)
        bucket.id: TextEditingController(
          text: (_investmentBucketCurrent[bucket.id] ?? 0) <= 0
              ? ''
              : moneyField(_investmentBucketCurrent[bucket.id] ?? 0),
        ),
    };
    final monthlyControllers = <String, TextEditingController>{
      for (final bucket in _investmentBucketConfigs)
        bucket.id: TextEditingController(
          text: (_investmentBucketMonthly[bucket.id] ?? 0) <= 0
              ? ''
              : moneyField(_investmentBucketMonthly[bucket.id] ?? 0),
        ),
    };
    final customRateControllers = <String, TextEditingController>{
      for (final bucket in _investmentBucketConfigs)
        bucket.id: TextEditingController(
          text: (_investmentBucketCustomRate[bucket.id] ?? 0) <= 0
              ? ''
              : (_investmentBucketCustomRate[bucket.id] ?? 0).toStringAsFixed(
                  2,
                ),
        ),
    };
    final goalControllers = <String, TextEditingController>{
      for (final bucket in _investmentBucketConfigs)
        bucket.id: TextEditingController(
          text: (_investmentBucketGoal[bucket.id] ?? 0) <= 0
              ? ''
              : moneyField(_investmentBucketGoal[bucket.id] ?? 0),
        ),
    };
    final localProfileIds = <String, String>{
      for (final bucket in _investmentBucketConfigs)
        bucket.id:
            _investmentBucketProfileIds[bucket.id] ??
            _defaultInvestmentProfileIdForBucket(bucket.id),
    };

    final suggestedMonthly = _suggestedInvestmentCapacity()
        .clamp(0.0, double.infinity)
        .toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FinanceSheetFrame(
              title: 'Ajustar investimentos',
              subtitle:
                  'Configure produto, taxa e meta por gaveta para projeções mais confiáveis.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FinanceSoftInfoCard(
                    title: 'Sugestão do mês',
                    text:
                        'Pela sua sobra real do período, hoje o app sugere até ${formatCurrency(suggestedMonthly, hideValues: false)} de aporte.',
                    icon: Icons.auto_graph_rounded,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FinanceTextField(
                          controller: rateController,
                          label: 'Taxa anual base',
                          suffixText: '%',
                          icon: Icons.trending_up_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceTextField(
                          controller: targetController,
                          label: 'Meta total',
                          prefixText: 'R\$ ',
                          icon: Icons.flag_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Gavetas de investimento',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agora cada gaveta pode usar um produto diferente, taxa custom e meta própria.',
                    style: TextStyle(color: Colors.white.withOpacity(0.70)),
                  ),
                  const SizedBox(height: 14),
                  ..._investmentBucketConfigs.map((bucket) {
                    final selectedProfileId = localProfileIds[bucket.id]!;
                    final selectedProfile = _profileById(selectedProfileId);
                    final useCustomRate =
                        selectedProfile.benchmarkType ==
                            FinanceInvestmentBenchmarkType.fixed ||
                        selectedProfile.benchmarkType ==
                            FinanceInvestmentBenchmarkType.custom;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: const Color(0xFF111A1A),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: bucket.color.withOpacity(0.18),
                                child: Icon(
                                  bucket.icon,
                                  color: bucket.color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bucket.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      bucket.subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.64),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedProfileId,
                            decoration: const InputDecoration(
                              labelText: 'Produto / perfil',
                              prefixIcon: Icon(Icons.account_tree_outlined),
                            ),
                            items: _investmentProfiles
                                .map(
                                  (profile) => DropdownMenuItem<String>(
                                    value: profile.id,
                                    child: Text(
                                      '${profile.title} • ${profile.badge}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() {
                                localProfileIds[bucket.id] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FinanceTextField(
                                  controller: principalControllers[bucket.id]!,
                                  label: 'Seu dinheiro',
                                  prefixText: 'R\$ ',
                                  icon: Icons.account_balance_wallet_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FinanceTextField(
                                  controller: currentControllers[bucket.id]!,
                                  label: 'Montante atual',
                                  prefixText: 'R\$ ',
                                  icon: Icons.savings_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FinanceTextField(
                                  controller: monthlyControllers[bucket.id]!,
                                  label: 'Aporte/mês',
                                  prefixText: 'R\$ ',
                                  icon: Icons.calendar_month_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FinanceTextField(
                                  controller: goalControllers[bucket.id]!,
                                  label: 'Meta da gaveta',
                                  prefixText: 'R\$ ',
                                  icon: Icons.flag_circle_outlined,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          if (useCustomRate) ...[
                            const SizedBox(height: 10),
                            FinanceTextField(
                              controller: customRateControllers[bucket.id]!,
                              label: 'Taxa anual custom desta gaveta',
                              suffixText: '%',
                              icon: Icons.percent_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          FinanceSoftInfoCard(
                            title: selectedProfile.title,
                            text:
                                'Benchmark: ${_benchmarkLabelForProfile(selectedProfile)} • ${_taxRuleLabel(selectedProfile.taxRule)}.',
                            icon: Icons.insights_outlined,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 6),
                  const FinanceSoftInfoCard(
                    title: 'Como o app calcula',
                    text:
                        'Bruto usa benchmark/taxa da gaveta. Líquido estima imposto conforme o tipo. Real desconta inflação do período.',
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        double principalSum = 0;
                        double currentSum = 0;
                        double monthlySum = 0;
                        for (final bucket in _investmentBucketConfigs) {
                          final principal = parseMoney(
                            principalControllers[bucket.id]!.text,
                          );
                          final current = parseMoney(
                            currentControllers[bucket.id]!.text,
                          );
                          final monthly = parseMoney(
                            monthlyControllers[bucket.id]!.text,
                          );
                          final customRate = parseDoubleValue(
                            customRateControllers[bucket.id]!.text,
                          );
                          final goal = parseMoney(
                            goalControllers[bucket.id]!.text,
                          );
                          final profileId =
                              localProfileIds[bucket.id] ??
                              _defaultInvestmentProfileIdForBucket(bucket.id);

                          principalSum += principal;
                          currentSum += current;
                          monthlySum += monthly;

                          await prefs.setDouble(
                            '$_prefsPrefix:invest_bucket:${bucket.id}:principal',
                            principal,
                          );
                          await prefs.setDouble(
                            '$_prefsPrefix:invest_bucket:${bucket.id}:current',
                            current,
                          );
                          await prefs.setDouble(
                            '$_prefsPrefix:invest_bucket:${bucket.id}:monthly',
                            monthly,
                          );
                          await prefs.setString(
                            '$_prefsPrefix:invest_bucket:${bucket.id}:profile',
                            profileId,
                          );
                          await prefs.setDouble(
                            '$_prefsPrefix:invest_bucket:${bucket.id}:custom_rate',
                            customRate,
                          );
                          await prefs.setDouble(
                            '$_prefsPrefix:invest_bucket:${bucket.id}:goal',
                            goal,
                          );
                        }
                        await prefs.setDouble(
                          '$_prefsPrefix:invest_principal',
                          principalSum,
                        );
                        await prefs.setDouble(
                          '$_prefsPrefix:invest_current_value',
                          currentSum,
                        );
                        await prefs.setDouble(
                          '$_prefsPrefix:invest_monthly_contribution',
                          monthlySum,
                        );
                        await prefs.setDouble(
                          '$_prefsPrefix:invest_annual_rate',
                          parseDoubleValue(rateController.text),
                        );
                        await prefs.setDouble(
                          '$_prefsPrefix:invest_target',
                          parseMoney(targetController.text),
                        );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        await _loadPrefs();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Salvar investimento'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCategoryDetails(FinanceCategoryTotal item) async {
    final matches =
        _store.expenseTransactions
            .where((tx) => tx.category.id == item.category.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FinanceSheetFrame(
          title: item.category.name,
          subtitle: 'Lançamentos do período selecionado.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FinanceCategorySummaryTile(
                icon: item.category.icon,
                color: item.category.color,
                title: 'Total da categoria',
                subtitle: _financePeriodLabel(_store.selectedPeriod),
                trailing: formatCurrency(item.total, hideValues: _hideValues),
              ),
              const SizedBox(height: 12),
              if (matches.isEmpty)
                const Text('Nenhum lançamento nessa categoria no período.')
              else
                ...matches.map(
                  (tx) => FinanceTransactionTile(
                    transaction: tx,
                    amountLabel: formatCurrency(
                      tx.amount,
                      hideValues: _hideValues,
                    ),
                    dateLabel: formatShortDate(tx.date),
                    onEdit: () => _openEditTransactionPage(tx),
                    onDelete: () => _confirmRemoveTransaction(tx),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, double> _resolvedPlanValues() {
    final activeIds = _activePlanningCategoryIds.isEmpty
        ? _defaultActivePlanningIds()
        : _activePlanningCategoryIds;
    final currentValues = <String, double>{
      for (final category in _planningCategories)
        category.id: activeIds.contains(category.id)
            ? (_plannedByCategory[category.id] ?? 0)
            : 0,
    };
    final total = activeIds.fold<double>(
      0,
      (sum, id) => sum + (currentValues[id] ?? 0),
    );
    if (total <= 0.01) {
      return _autoDistributePlan(
        income: _monthlyIncomePlan,
        essentialPercent: _planningEssentialPercent,
        futurePercent: _planningFuturePercent,
        freePercent: _planningFreePercent,
        activeIds: activeIds,
        ownHome: _planningOwnHome,
        mealTicket: _planningMealTicket,
        noCar: _planningNoCar,
        freeTransit: _planningFreeTransit,
        hasHealthPlan: _planningHasHealthPlan,
      );
    }
    return currentValues;
  }

  List<FinanceCategory> _sortedPlanningCategories(Iterable<String> ids) {
    final idSet = ids.toSet();
    final items = _planningCategories
        .where((item) => idSet.contains(item.id))
        .toList();
    items.sort(FinancePlanningCatalog.compareCategories);
    return items;
  }

  String? _pickRemainderCategory(Set<String> activeIds) {
    const preferredIds = <String>[
      'future_emergency',
      'future_caixinha',
      'future_stocks',
      'other_expense',
    ];
    for (final id in preferredIds) {
      if (_planningCategories.any((category) => category.id == id)) {
        return id;
      }
    }
    if (activeIds.isNotEmpty) {
      final sorted = _sortedPlanningCategories(activeIds);
      return sorted.isEmpty ? null : sorted.first.id;
    }
    final defaults = _defaultActivePlanningIds();
    return defaults.isEmpty ? null : defaults.first;
  }

  Map<String, double> _autoDistributePlan({
    required double income,
    required double essentialPercent,
    required double futurePercent,
    required double freePercent,
    required Set<String> activeIds,
    required bool ownHome,
    required bool mealTicket,
    required bool noCar,
    required bool freeTransit,
    required bool hasHealthPlan,
  }) {
    final safeActiveIds = activeIds.isEmpty
        ? _defaultActivePlanningIds()
        : activeIds;
    final result = <String, double>{
      for (final category in _planningCategories) category.id: 0,
    };

    final essentialTotal = income * (essentialPercent / 100);
    final futureTotal = income * (futurePercent / 100);
    final freeTotal = income * (freePercent / 100);

    void distribute(FinancePlanningBucketKind bucket, double total) {
      final bucketCategories = _planningCategories.where((category) {
        return safeActiveIds.contains(category.id) &&
            FinancePlanningCatalog.bucketOf(category.id) == bucket;
      }).toList();

      final fallback = _planningCategories.where((category) {
        return FinancePlanningCatalog.bucketOf(category.id) == bucket &&
            FinancePlanningCatalog.starterFor(category.id);
      }).toList();

      final targets = bucketCategories.isEmpty ? fallback : bucketCategories;
      if (targets.isEmpty || total <= 0) return;

      final weights = <String, double>{};
      var totalWeight = 0.0;
      for (final category in targets) {
        final baseWeight = FinancePlanningCatalog.baseWeightFor(category.id);
        final profileWeight = FinancePlanningCatalog.profileMultiplier(
          category.id,
          ownHome: ownHome,
          mealTicket: mealTicket,
          noCar: noCar,
          freeTransit: freeTransit,
          hasHealthPlan: hasHealthPlan,
        );
        final weight = math.max(0.0, baseWeight * profileWeight).toDouble();
        if (weight <= 0) continue;
        weights[category.id] = weight;
        totalWeight += weight;
      }

      if (weights.isEmpty || totalWeight <= 0) return;

      var distributed = 0.0;
      final targetIds = weights.keys.toList();
      for (var index = 0; index < targetIds.length; index++) {
        final id = targetIds[index];
        final isLast = index == targetIds.length - 1;
        final value = isLast
            ? (total - distributed)
            : double.parse(
                (total * (weights[id]! / totalWeight)).toStringAsFixed(2),
              );
        result[id] = math.max(0.0, value).toDouble();
        distributed += result[id]!;
      }
    }

    distribute(FinancePlanningBucketKind.essential, essentialTotal);
    distribute(FinancePlanningBucketKind.future, futureTotal);
    distribute(FinancePlanningBucketKind.free, freeTotal);
    return result;
  }

  List<FinancePlanningBucket> _buildPlanningBuckets() {
    final values = _resolvedPlanValues();
    final activeCategories = _sortedPlanningCategories(
      _activePlanningCategoryIds.isEmpty
          ? _defaultActivePlanningIds()
          : _activePlanningCategoryIds,
    );

    final items = <FinancePlanningBucket>[];
    for (final category in activeCategories) {
      final amount = values[category.id] ?? 0;
      if (amount <= 0) continue;
      final bucket = FinancePlanningCatalog.bucketOf(category.id);
      items.add(
        FinancePlanningBucket(
          title: category.name,
          subtitle: FinancePlanningCatalog.bucketLabel(bucket),
          amount: amount,
          color: category.color,
        ),
      );
    }

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  Map<String, double> _buildPlanningSummary() {
    final income = _monthlyIncomePlan;
    final values = _resolvedPlanValues();
    double essential = 0;
    double future = 0;
    double free = 0;

    for (final category in _planningCategories) {
      final amount = values[category.id] ?? 0;
      switch (FinancePlanningCatalog.bucketOf(category.id)) {
        case FinancePlanningBucketKind.essential:
          essential += amount;
          break;
        case FinancePlanningBucketKind.future:
          future += amount;
          break;
        case FinancePlanningBucketKind.free:
          free += amount;
          break;
      }
    }

    return {
      'Renda planejada': income,
      'Essenciais': essential,
      'Investir + reserva': future,
      'Livre': free,
      'Sobra': math.max(0.0, income - (essential + future + free)).toDouble(),
    };
  }

  List<FinanceCategoryTotal> _buildCategoryTotals() {
    final byCategory = <String, FinanceCategoryTotal>{};

    for (final tx in _store.expenseTransactions) {
      final key = tx.category.id;
      final existing = byCategory[key];
      if (existing == null) {
        byCategory[key] = FinanceCategoryTotal(
          category: tx.category,
          total: tx.amount,
        );
      } else {
        byCategory[key] = FinanceCategoryTotal(
          category: existing.category,
          total: existing.total + tx.amount,
        );
      }
    }

    final list = byCategory.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  List<FinanceInvestmentBucketData> _buildInvestmentBuckets() {
    final items = _investmentBucketConfigs.map((bucket) {
      return FinanceInvestmentBucketData(
        config: bucket,
        principal: _investmentBucketPrincipal[bucket.id] ?? 0,
        current: _investmentBucketCurrent[bucket.id] ?? 0,
        monthlyContribution: _investmentBucketMonthly[bucket.id] ?? 0,
        profileId:
            _investmentBucketProfileIds[bucket.id] ??
            _defaultInvestmentProfileIdForBucket(bucket.id),
        customAnnualRate: _investmentBucketCustomRate[bucket.id] ?? 0,
        goalAmount: _investmentBucketGoal[bucket.id] ?? 0,
      );
    }).toList();
    return items;
  }

  double _suggestedInvestmentCapacity() {
    return math.max(0.0, _store.totalIncome - _store.totalExpense).toDouble();
  }

  String _monthLabelShort(DateTime date) {
    const labels = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return labels[date.month - 1];
  }

  List<FinanceInvestmentCapacityPoint> _buildInvestmentCapacityHistory() {
    final now = DateTime.now();
    final points = <FinanceInvestmentCapacityPoint>[];
    for (int offset = 5; offset >= 0; offset--) {
      final base = DateTime(now.year, now.month - offset, 1);
      final income = _store.transactions
          .where(
            (tx) =>
                tx.isIncome &&
                tx.date.year == base.year &&
                tx.date.month == base.month,
          )
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      final expense = _store.transactions
          .where(
            (tx) =>
                !tx.isIncome &&
                tx.date.year == base.year &&
                tx.date.month == base.month,
          )
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      points.add(
        FinanceInvestmentCapacityPoint(
          label: _monthLabelShort(base),
          amount: income - expense,
          isCurrent: offset == 0,
        ),
      );
    }
    return points;
  }

  double _averageMonthlyExpense({int months = 3}) {
    final now = DateTime.now();
    if (_store.transactions.isEmpty) return 0;
    double total = 0;
    for (int offset = 0; offset < months; offset++) {
      final base = DateTime(now.year, now.month - offset, 1);
      total += _store.transactions
          .where(
            (tx) =>
                !tx.isIncome &&
                tx.date.year == base.year &&
                tx.date.month == base.month,
          )
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
    }
    return total / months;
  }

  double _investmentRiskScore(List<FinanceInvestmentBucketData> buckets) {
    final total = buckets.fold<double>(0.0, (sum, item) => sum + item.current);
    if (total <= 0.01) return 0;
    double weighted = 0;
    for (final bucket in buckets) {
      weighted += bucket.current * bucket.config.riskLevel;
    }
    return weighted / total;
  }

  List<FinanceInvestmentHealthItem> _buildInvestmentHealthItems(
    List<FinanceInvestmentBucketData> buckets,
  ) {
    final items = <FinanceInvestmentHealthItem>[];
    final reserve = buckets.firstWhere(
      (item) => item.config.id == 'reserve',
      orElse: () => FinanceInvestmentBucketData(
        config: _investmentBucketConfigs.first,
        principal: 0,
        current: 0,
        monthlyContribution: 0,
        profileId: _defaultInvestmentProfileIdForBucket(
          _investmentBucketConfigs.first.id,
        ),
        customAnnualRate: 0,
        goalAmount: 0,
      ),
    );
    final monthlyBase = math
        .max(
          1.0,
          (_buildPlanningSummary()['Essenciais'] ?? 0) > 0
              ? (_buildPlanningSummary()['Essenciais'] ?? 0)
              : _averageMonthlyExpense(),
        )
        .toDouble();
    final coverageMonths = reserve.current / monthlyBase;
    if (coverageMonths >= 6) {
      items.add(
        const FinanceInvestmentHealthItem(
          title: 'Reserva protegendo bem',
          message:
              'Sua reserva cobre pelo menos 6 meses do seu padrão essencial.',
          color: Color(0xFF28C76F),
          icon: Icons.verified_user_outlined,
        ),
      );
    } else if (coverageMonths >= 3) {
      items.add(
        FinanceInvestmentHealthItem(
          title: 'Reserva em construção',
          message:
              'Sua reserva cobre cerca de ${coverageMonths.toStringAsFixed(1)} meses. Dá para fortalecer mais.',
          color: const Color(0xFFFFB020),
          icon: Icons.shield_outlined,
        ),
      );
    } else {
      items.add(
        FinanceInvestmentHealthItem(
          title: 'Reserva curta',
          message:
              'Hoje sua reserva cobre só ${coverageMonths.toStringAsFixed(1)} meses do essencial.',
          color: const Color(0xFFFF5D73),
          icon: Icons.warning_amber_rounded,
        ),
      );
    }

    final total = buckets.fold<double>(0.0, (sum, item) => sum + item.current);
    final highestShare = total <= 0.01
        ? 0.0
        : buckets
              .map((item) => item.current / total)
              .fold<double>(0.0, (best, value) => value > best ? value : best);
    if (highestShare > 0.70) {
      items.add(
        FinanceInvestmentHealthItem(
          title: 'Carteira concentrada',
          message:
              'Mais de ${(highestShare * 100).toStringAsFixed(0)}% está em uma única gaveta.',
          color: const Color(0xFFFF5D73),
          icon: Icons.pie_chart_outline_rounded,
        ),
      );
    } else {
      items.add(
        const FinanceInvestmentHealthItem(
          title: 'Diversificação ok',
          message:
              'Seu patrimônio já está mais espalhado entre objetivos diferentes.',
          color: Color(0xFF39D0FF),
          icon: Icons.scatter_plot_outlined,
        ),
      );
    }

    final suggested = _suggestedInvestmentCapacity();
    final planned = buckets.fold<double>(
      0.0,
      (sum, item) => sum + item.monthlyContribution,
    );
    if (suggested <= 0.01 && planned > 0.01) {
      items.add(
        const FinanceInvestmentHealthItem(
          title: 'Mês apertado',
          message:
              'Sua sobra real do período está curta para manter esse aporte com folga.',
          color: Color(0xFFFFB020),
          icon: Icons.balance_outlined,
        ),
      );
    } else if (planned <= 0.01 && suggested > 0.01) {
      items.add(
        FinanceInvestmentHealthItem(
          title: 'Dá para começar melhor',
          message:
              'Pela sua sobra real, hoje você conseguiria aportar cerca de ${formatCurrency(suggested, hideValues: false)}.',
          color: const Color(0xFF9CFF3F),
          icon: Icons.auto_graph_rounded,
        ),
      );
    } else if (suggested > planned + 50) {
      items.add(
        FinanceInvestmentHealthItem(
          title: 'Aporte pode crescer',
          message:
              'Sua sobra real do período está acima do aporte configurado.',
          color: const Color(0xFF9CFF3F),
          icon: Icons.trending_up_rounded,
        ),
      );
    } else {
      items.add(
        const FinanceInvestmentHealthItem(
          title: 'Aporte coerente',
          message:
              'O valor investido por mês está perto do que sua vida financeira sustenta.',
          color: Color(0xFF39D0FF),
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    }
    return items;
  }

  double _marketBackedAnnualRate(
    FinanceInvestmentProductProfile profile,
    FinanceInvestmentBucketData bucket,
  ) {
    final market = _marketSnapshot;
    final fallback = bucket.customAnnualRate > 0
        ? bucket.customAnnualRate
        : _annualInterestRate;

    switch (profile.benchmarkType) {
      case FinanceInvestmentBenchmarkType.cdi:
        final cdi = market?.cdiAnnual ?? market?.selicAnnual ?? fallback;
        return (cdi * profile.multiplier) + profile.spreadAnnual;
      case FinanceInvestmentBenchmarkType.selic:
        final selic = market?.selicAnnual ?? fallback;
        return (selic * profile.multiplier) + profile.spreadAnnual;
      case FinanceInvestmentBenchmarkType.ipca:
        final ipca = market?.ipca12Months ?? 0;
        return ipca + profile.spreadAnnual;
      case FinanceInvestmentBenchmarkType.fixed:
        return bucket.customAnnualRate > 0 ? bucket.customAnnualRate : fallback;
      case FinanceInvestmentBenchmarkType.custom:
        return bucket.customAnnualRate > 0 ? bucket.customAnnualRate : fallback;
      case FinanceInvestmentBenchmarkType.savings:
        final selic = market?.selicAnnual ?? fallback;
        return selic <= 8.5 ? selic * 0.7 : 6.17;
    }
  }

  double _scenarioAdjustedAnnualRate(
    FinanceInvestmentProductProfile profile,
    FinanceInvestmentBucketData bucket,
    FinanceInvestmentScenarioType scenario,
  ) {
    final baseRate = _marketBackedAnnualRate(profile, bucket);
    if (scenario == FinanceInvestmentScenarioType.base) return baseRate;

    if (profile.isVariableIncome) {
      if (scenario == FinanceInvestmentScenarioType.conservative) {
        return math.max(0.0, (baseRate * 0.65) - 4).toDouble();
      }
      return ((baseRate * 1.20) + 2).toDouble();
    }

    if (scenario == FinanceInvestmentScenarioType.conservative) {
      return math.max(0.0, (baseRate * 0.90) - 0.6).toDouble();
    }
    return ((baseRate * 1.05) + 0.35).toDouble();
  }

  double _estimateTaxRate(FinanceInvestmentProductProfile profile, int months) {
    switch (profile.taxRule) {
      case FinanceInvestmentTaxRule.regressiveFixedIncome:
        return estimateFixedIncomeTaxRate(months);
      case FinanceInvestmentTaxRule.taxFree:
      case FinanceInvestmentTaxRule.exemptGain:
      case FinanceInvestmentTaxRule.customNone:
        return 0;
      case FinanceInvestmentTaxRule.variableIncome15:
        return 15;
    }
  }

  FinanceInvestmentProjectionScenario _buildProjectionScenario({
    required FinanceInvestmentScenarioType type,
    required String label,
    required int years,
    required double current,
    required double monthlyContribution,
    required double annualRate,
    required double taxRate,
    required double inflationAnnual,
  }) {
    final months = years * 12;
    final grossTotal = projectFutureValue(
      current: current,
      monthlyContribution: monthlyContribution,
      annualPercent: annualRate,
      months: months,
    );
    final principalFuture = current + (monthlyContribution * months);
    final grossGain = math.max(0.0, grossTotal - principalFuture).toDouble();
    final netGain = grossGain * (1 - taxRate / 100);
    final netTotal = principalFuture + netGain;
    final factor = math.pow(1 + inflationAnnual / 100, years).toDouble();
    final realTotal = factor <= 0 ? netTotal : (netTotal / factor);
    final realGain = realTotal - principalFuture;
    final netAnnual = annualRate <= 0
        ? annualRate
        : math.max(0.0, annualRate - ((annualRate * taxRate) / 100)).toDouble();
    final realAnnual = nominalToRealAnnual(netAnnual, inflationAnnual);

    return FinanceInvestmentProjectionScenario(
      type: type,
      label: label,
      years: years,
      nominalAnnualRate: annualRate,
      netAnnualRate: netAnnual,
      realAnnualRate: realAnnual,
      grossTotal: grossTotal,
      netTotal: netTotal,
      realTotal: realTotal,
      grossGain: grossGain,
      netGain: netGain,
      realGain: realGain,
    );
  }

  double _weightedReferenceRate(
    List<FinanceInvestmentBucketData> buckets,
    FinanceInvestmentScenarioType scenario,
  ) {
    final totalBase = buckets.fold<double>(
      0.0,
      (sum, item) => sum + (item.current > 0 ? item.current : item.principal),
    );
    if (totalBase <= 0.01) return _annualInterestRate;
    double weighted = 0;
    for (final bucket in buckets) {
      final base = bucket.current > 0 ? bucket.current : bucket.principal;
      final profile = _profileById(bucket.profileId);
      weighted += _scenarioAdjustedAnnualRate(profile, bucket, scenario) * base;
    }
    return weighted / totalBase;
  }

  int? _monthsToGoal({
    required double current,
    required double monthlyContribution,
    required double target,
    required double annualRate,
  }) {
    if (target <= 0 || current >= target) return 0;
    var total = current;
    int safety = 0;
    while (total < target && safety < 1200) {
      total = projectFutureValue(
        current: total,
        monthlyContribution: monthlyContribution,
        annualPercent: annualRate,
        months: 1,
      );
      safety++;
    }
    return safety >= 1200 ? null : safety;
  }

  List<FinanceInvestmentGoalProgress> _buildGoalItems(
    List<FinanceInvestmentBucketData> buckets,
    FinanceInvestmentScenarioType scenario,
  ) {
    final items = <FinanceInvestmentGoalProgress>[];
    for (final bucket in buckets) {
      if (bucket.goalAmount <= 0) continue;
      final profile = _profileById(bucket.profileId);
      final progress = bucket.current <= 0
          ? 0.0
          : (bucket.current / bucket.goalAmount).clamp(0.0, 1.0);
      items.add(
        FinanceInvestmentGoalProgress(
          title: bucket.config.title,
          target: bucket.goalAmount,
          current: bucket.current,
          progress: progress,
          monthsAtBaseScenario: _monthsToGoal(
            current: bucket.current,
            monthlyContribution: bucket.monthlyContribution,
            target: bucket.goalAmount,
            annualRate: _scenarioAdjustedAnnualRate(profile, bucket, scenario),
          ),
        ),
      );
    }
    return items;
  }

  String _taxRuleLabel(FinanceInvestmentTaxRule rule) {
    switch (rule) {
      case FinanceInvestmentTaxRule.regressiveFixedIncome:
        return 'IR regressivo';
      case FinanceInvestmentTaxRule.taxFree:
        return 'Isento';
      case FinanceInvestmentTaxRule.exemptGain:
        return 'Ganho isento';
      case FinanceInvestmentTaxRule.variableIncome15:
        return 'IR 15%';
      case FinanceInvestmentTaxRule.customNone:
        return 'Sem IR automático';
    }
  }

  String _benchmarkLabelForProfile(FinanceInvestmentProductProfile profile) {
    switch (profile.benchmarkType) {
      case FinanceInvestmentBenchmarkType.cdi:
        return '${(profile.multiplier * 100).toStringAsFixed(0)}% do CDI';
      case FinanceInvestmentBenchmarkType.selic:
        return 'Selic';
      case FinanceInvestmentBenchmarkType.ipca:
        return 'IPCA + ${profile.spreadAnnual.toStringAsFixed(1).replaceAll('.', ',')}%';
      case FinanceInvestmentBenchmarkType.fixed:
        return 'Prefixado';
      case FinanceInvestmentBenchmarkType.custom:
        return 'Taxa custom';
      case FinanceInvestmentBenchmarkType.savings:
        return 'Poupança';
    }
  }

  double _bucketNetProjection12Months(FinanceInvestmentBucketData bucket) {
    final profile = _profileById(bucket.profileId);
    final annualRate = _scenarioAdjustedAnnualRate(
      profile,
      bucket,
      FinanceInvestmentScenarioType.base,
    );
    final grossTotal = projectFutureValue(
      current: bucket.current,
      monthlyContribution: bucket.monthlyContribution,
      annualPercent: annualRate,
      months: 12,
    );
    final principalFuture = bucket.current + (bucket.monthlyContribution * 12);
    final grossGain = math.max(0.0, grossTotal - principalFuture).toDouble();
    final taxRate = _estimateTaxRate(profile, 12);
    final netGain = grossGain * (1 - taxRate / 100);
    return principalFuture + netGain;
  }

  FinanceInvestmentViewData _buildInvestmentData() {
    final buckets = _buildInvestmentBuckets();
    final principal = buckets.fold<double>(
      0.0,
      (sum, item) => sum + item.principal,
    );
    final current = buckets.fold<double>(
      0.0,
      (sum, item) => sum + item.current,
    );
    final monthly = buckets.fold<double>(
      0.0,
      (sum, item) => sum + item.monthlyContribution,
    );
    final earnings = math.max(0.0, current - principal).toDouble();
    final progress = _investmentTarget <= 0
        ? 0.0
        : (current / _investmentTarget).clamp(0.0, 1.0);

    final inflation = _marketSnapshot?.ipca12Months ?? 0.0;
    final grossAnnualReference = _weightedReferenceRate(
      buckets,
      FinanceInvestmentScenarioType.base,
    );
    final double taxDragAnnual = buckets.isEmpty
        ? 0.0
        : buckets
                  .map((bucket) {
                    final profile = _profileById(bucket.profileId);
                    final tax = _estimateTaxRate(profile, 12);
                    final rate = _scenarioAdjustedAnnualRate(
                      profile,
                      bucket,
                      FinanceInvestmentScenarioType.base,
                    );
                    return rate * tax / 100;
                  })
                  .fold<double>(0.0, (sum, item) => sum + item) /
              buckets.length;
    final double netAnnualReference = math
        .max(0.0, grossAnnualReference - taxDragAnnual)
        .toDouble();
    final double realAnnualReference = nominalToRealAnnual(
      netAnnualReference,
      inflation,
    ).toDouble();

    final conservativeScenario = _buildProjectionScenario(
      type: FinanceInvestmentScenarioType.conservative,
      label: 'Conservador',
      years: 5,
      current: current,
      monthlyContribution: monthly,
      annualRate: _weightedReferenceRate(
        buckets,
        FinanceInvestmentScenarioType.conservative,
      ),
      taxRate: buckets.isEmpty ? 0.0 : taxDragAnnual,
      inflationAnnual: inflation,
    );

    final baseScenario = _buildProjectionScenario(
      type: FinanceInvestmentScenarioType.base,
      label: 'Base',
      years: 5,
      current: current,
      monthlyContribution: monthly,
      annualRate: grossAnnualReference,
      taxRate: buckets.isEmpty ? 0.0 : taxDragAnnual,
      inflationAnnual: inflation,
    );

    final optimisticScenario = _buildProjectionScenario(
      type: FinanceInvestmentScenarioType.optimistic,
      label: 'Otimista',
      years: 5,
      current: current,
      monthlyContribution: monthly,
      annualRate: _weightedReferenceRate(
        buckets,
        FinanceInvestmentScenarioType.optimistic,
      ),
      taxRate: buckets.isEmpty ? 0.0 : taxDragAnnual,
      inflationAnnual: inflation,
    );

    final snapshots = <FinanceInvestmentSnapshot>[];
    for (final months in <int>[6, 12, 24, 60]) {
      final total = projectFutureValue(
        current: current,
        monthlyContribution: monthly,
        annualPercent: grossAnnualReference,
        months: months,
      );
      final principalPart = current + (monthly * months);
      snapshots.add(
        FinanceInvestmentSnapshot(
          label: months >= 12 ? '${months ~/ 12}a' : '${months}m',
          total: total,
          principal: principalPart,
          earnings: math.max(0.0, total - principalPart).toDouble(),
        ),
      );
    }

    final monthsToTarget = _monthsToGoal(
      current: current,
      monthlyContribution: monthly,
      target: _investmentTarget,
      annualRate: grossAnnualReference,
    );

    return FinanceInvestmentViewData(
      principal: principal,
      current: current,
      earnings: earnings,
      monthlyContribution: monthly,
      annualRate: grossAnnualReference,
      target: _investmentTarget,
      targetProgress: progress,
      monthsToTarget: monthsToTarget,
      snapshots: snapshots,
      buckets: buckets,
      suggestedMonthlyContribution: _suggestedInvestmentCapacity(),
      powerHistory: _buildInvestmentCapacityHistory(),
      healthItems: _buildInvestmentHealthItems(buckets),
      portfolioRiskScore: _investmentRiskScore(buckets),
      marketSnapshot: _marketSnapshot,
      marketError: _marketError,
      marketLoading: _loadingMarket,
      baseScenario: baseScenario,
      conservativeScenario: conservativeScenario,
      optimisticScenario: optimisticScenario,
      goalItems: _buildGoalItems(buckets, FinanceInvestmentScenarioType.base),
      grossAnnualReference: grossAnnualReference,
      netAnnualReference: netAnnualReference,
      realAnnualReference: realAnnualReference,
      taxDragAnnual: taxDragAnnual,
    );
  }

  Widget _buildPlanPreviewTile(FinancePlanningBucket bucket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bucket.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucket.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  bucket.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCurrency(bucket.amount, hideValues: _hideValues),
            style: TextStyle(fontWeight: FontWeight.w800, color: bucket.color),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionSection() {
    final items = _buildCategoryTotals();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Leitura rápida',
          subtitle: _store.quickInsight,
          child: Column(
            children: [
              FinancePeriodChips(
                current: _store.selectedPeriod,
                onChanged: _store.setPeriod,
              ),
              const SizedBox(height: 12),
              Text(
                _store.periodComparisonText,
                style: TextStyle(color: Colors.white.withOpacity(0.72)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Gastos por categoria',
          subtitle:
              'Valores do período selecionado. Toque para ver os lançamentos.',
          child: Column(
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhuma saída registrada no período.'),
                )
              else
                ...items.take(6).map((item) {
                  final maxValue = items.first.total <= 0
                      ? 1.0
                      : items.first.total;
                  final progress = (item.total / maxValue).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openCategoryDetails(item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFF111A1A),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: item.category.color
                                      .withOpacity(0.18),
                                  child: Icon(
                                    item.category.icon,
                                    color: item.category.color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  formatCurrency(
                                    item.total,
                                    hideValues: _hideValues,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white.withOpacity(0.06),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.category.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanningSection() {
    final summary = _buildPlanningSummary();
    final preview = _buildPlanningBuckets();
    final activeCategories = _sortedPlanningCategories(
      _activePlanningCategoryIds.isEmpty
          ? _defaultActivePlanningIds()
          : _activePlanningCategoryIds,
    );
    final lifeFlags = <String>[
      if (_planningOwnHome) 'Casa própria',
      if (_planningMealTicket) 'Vale alimentação',
      if (_planningNoCar) 'Sem carro',
      if (_planningFreeTransit) 'Passagem grátis',
      if (_planningHasHealthPlan) 'Plano de saúde',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Planejamento do mês',
          subtitle: 'O app sugere, mas você adapta ao seu jeito de viver.',
          trailing: TextButton.icon(
            onPressed: _openPlanningSheet,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Renda planejada',
                      value: formatCurrency(
                        summary['Renda planejada'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF9CFF3F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Essenciais',
                      value: formatCurrency(
                        summary['Essenciais'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF28C76F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Investir + reserva',
                      value: formatCurrency(
                        summary['Investir + reserva'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Livre',
                      value: formatCurrency(
                        summary['Livre'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFFFFB020),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FinanceValueBadge(
                label: 'Sobra automática',
                value: formatCurrency(
                  summary['Sobra'] ?? 0,
                  hideValues: _hideValues,
                ),
                color: const Color(0xFF39D0FF),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Seu perfil do mês',
          subtitle: 'Esses atalhos mudam a divisão automática.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lifeFlags.isEmpty)
                Text(
                  'Nenhum atalho ligado. Toque em Editar para marcar casa própria, vale alimentação, sem carro e outros.',
                  style: TextStyle(color: Colors.white.withOpacity(0.72)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lifeFlags
                      .map((label) => Chip(label: Text(label)))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Categorias ativas do plano',
          subtitle: 'Só aparece forte aqui o que você realmente usa.',
          child: Column(
            children: [
              if (activeCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhuma categoria ativa ainda.'),
                )
              else
                ...activeCategories.take(8).map((category) {
                  final amount = (_resolvedPlanValues()[category.id] ?? 0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FinanceCategorySummaryTile(
                      icon: category.icon,
                      color: category.color,
                      title: category.name,
                      subtitle: FinancePlanningCatalog.bucketLabel(
                        FinancePlanningCatalog.bucketOf(category.id),
                      ),
                      trailing: formatCurrency(amount, hideValues: _hideValues),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Sugestão em ação',
          subtitle:
              'A divisão automática respeita as categorias ativas e o jeito que você vive.',
          child: Column(
            children: preview.take(6).map(_buildPlanPreviewTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestSection() {
    final data = _buildInvestmentData();
    final current = data.current <= 0 ? 1.0 : data.current;
    final principalRatio = (data.principal / current).clamp(0.0, 1.0);
    final earningsRatio = (data.earnings / current).clamp(0.0, 1.0);
    final maxPower = data.powerHistory.fold<double>(
      1.0,
      (best, item) => math.max(best, item.amount.abs()),
    );

    Widget scenarioCard(
      FinanceInvestmentProjectionScenario scenario,
      Color color,
    ) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withOpacity(0.10),
          border: Border.all(color: color.withOpacity(0.26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scenario.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  formatCurrencyCompact(
                    scenario.netTotal,
                    hideValues: _hideValues,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bruto ${scenario.nominalAnnualRate.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
            const SizedBox(height: 4),
            Text(
              'Líquido ${scenario.netAnnualRate.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
            const SizedBox(height: 4),
            Text(
              'Real ${scenario.realAnnualRate.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
            const SizedBox(height: 8),
            Text(
              'Em ${scenario.years} anos, líquido estimado.',
              style: TextStyle(color: Colors.white.withOpacity(0.64)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Investimentos',
          subtitle:
              'Bruto, líquido, real e cenários usando benchmark do produto quando disponível.',
          trailing: TextButton.icon(
            onPressed: _openInvestmentSheet,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Ajustar'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Patrimônio atual',
                      value: formatCurrency(
                        data.current,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Seu dinheiro',
                      value: formatCurrency(
                        data.principal,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF39D0FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Lucro bruto',
                      value: formatCurrency(
                        data.earnings,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFFFFB020),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Aporte sugerido',
                      value: formatCurrency(
                        data.suggestedMonthlyContribution,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF9CFF3F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Bruto de referência',
                      value:
                          '${data.grossAnnualReference.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
                      color: const Color(0xFF39D0FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Líquido estimado',
                      value:
                          '${data.netAnnualReference.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
                      color: const Color(0xFF28C76F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Real acima da inflação',
                      value:
                          '${data.realAnnualReference.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
                      color: const Color(0xFFFFB020),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Arrasto de imposto',
                      value:
                          '${data.taxDragAnnual.toStringAsFixed(2).replaceAll('.', ',')} p.p.',
                      color: const Color(0xFFFF5D73),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Composição atual',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                        flex: math.max(1, (principalRatio * 1000).round()),
                        child: Container(color: const Color(0xFF39D0FF)),
                      ),
                      Expanded(
                        flex: math.max(1, (earningsRatio * 1000).round()),
                        child: Container(color: const Color(0xFFFFB020)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  FinanceLegendDot(
                    color: Color(0xFF39D0FF),
                    text: 'Seu dinheiro',
                  ),
                  SizedBox(width: 14),
                  FinanceLegendDot(
                    color: Color(0xFFFFB020),
                    text: 'Ganho bruto',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Benchmarks e inflação',
          subtitle:
              'Taxas de referência usadas para acompanhar produtos indexados a CDI, Selic e IPCA.',
          trailing: IconButton(
            onPressed: _refreshMarketData,
            tooltip: 'Atualizar indicadores',
            icon: const Icon(Icons.refresh_rounded),
          ),
          child: Column(
            children: [
              if (data.marketLoading)
                const FinanceSoftInfoCard(
                  title: 'Atualizando',
                  text:
                      'Buscando CDI, Selic e IPCA para alimentar os cálculos.',
                  icon: Icons.sync_rounded,
                )
              else if (data.marketSnapshot != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: FinanceValueBadge(
                        label: 'CDI',
                        value:
                            '${data.marketSnapshot!.cdiAnnual.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
                        color: const Color(0xFF39D0FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FinanceValueBadge(
                        label: 'Selic',
                        value:
                            '${data.marketSnapshot!.selicAnnual.toStringAsFixed(2).replaceAll('.', ',')}% a.a.',
                        color: const Color(0xFF9CFF3F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FinanceValueBadge(
                  label: 'IPCA 12 meses',
                  value:
                      '${data.marketSnapshot!.ipca12Months.toStringAsFixed(2).replaceAll('.', ',')}%',
                  color: const Color(0xFFFFB020),
                ),
              ] else
                FinanceSoftInfoCard(
                  title: 'Sem atualização agora',
                  text:
                      data.marketError ??
                      'Ainda não deu para carregar os indicadores.',
                  icon: Icons.cloud_off_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Cenários de projeção',
          subtitle:
              'Projeção bruta, líquida estimada e real descontando inflação.',
          child: Column(
            children: [
              scenarioCard(data.conservativeScenario, const Color(0xFFFFB020)),
              scenarioCard(data.baseScenario, const Color(0xFF39D0FF)),
              scenarioCard(data.optimisticScenario, const Color(0xFF28C76F)),
            ],
          ),
        ),
        if (data.goalItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          FinanceSectionCard(
            title: 'Metas por gaveta',
            subtitle:
                'Quanto falta para cada objetivo usando o cenário base como referência.',
            child: Column(
              children: data.goalItems.map((goal) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFF111A1A),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              formatCurrency(
                                goal.target,
                                hideValues: _hideValues,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: goal.progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          goal.monthsAtBaseScenario == null
                              ? 'Ainda sem prazo confiável para atingir a meta.'
                              : 'Projeção: cerca de ${goal.monthsAtBaseScenario} meses no cenário base.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Suas gavetas',
          subtitle:
              'Cada gaveta mostra produto, benchmark, imposto estimado e projeção líquida de 12 meses.',
          child: Column(
            children: data.buckets.map((bucket) {
              final profile = _profileById(bucket.profileId);
              final share = data.current <= 0
                  ? 0.0
                  : (bucket.current / data.current).clamp(0.0, 1.0);
              final projectedNet12m = _bucketNetProjection12Months(bucket);
              final taxLabel = _taxRuleLabel(profile.taxRule);
              final benchmarkLabel = _benchmarkLabelForProfile(profile);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF111A1A),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: bucket.config.color.withOpacity(
                              0.18,
                            ),
                            child: Icon(
                              bucket.config.icon,
                              color: bucket.config.color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bucket.config.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${profile.title} • ${profile.badge}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.68),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCurrency(
                              bucket.current,
                              hideValues: _hideValues,
                            ),
                            style: TextStyle(
                              color: bucket.config.color,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: share,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            bucket.config.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FinanceCompactStatCard(
                              title: 'Seu dinheiro',
                              value: formatCurrency(
                                bucket.principal,
                                hideValues: _hideValues,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FinanceCompactStatCard(
                              title: 'Aporte/mês',
                              value: formatCurrency(
                                bucket.monthlyContribution,
                                hideValues: _hideValues,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FinanceCompactStatCard(
                              title: 'Proj. líq. 12m',
                              value: formatCurrencyCompact(
                                projectedNet12m,
                                hideValues: _hideValues,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FinanceSoftInfoCard(
                        title: benchmarkLabel,
                        text:
                            'Imposto: $taxLabel${bucket.goalAmount > 0 ? ' • Meta: ${formatCurrency(bucket.goalAmount, hideValues: _hideValues)}' : ''}',
                        icon: Icons.insights_outlined,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Poder de aporte',
          subtitle:
              'Leitura simples da sua sobra mensal ao longo do tempo. Verde = mais folga, vermelho = aperto.',
          child: Column(
            children: data.powerHistory.map((point) {
              final positive = point.amount >= 0;
              final progress = (point.amount.abs() / maxPower).clamp(0.0, 1.0);
              final color = positive
                  ? (point.isCurrent
                        ? const Color(0xFF9CFF3F)
                        : const Color(0xFF28C76F))
                  : const Color(0xFFFF5D73);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF111A1A),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            point.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (point.isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: const Color(
                                  0xFF9CFF3F,
                                ).withOpacity(0.14),
                              ),
                              child: const Text(
                                'Atual',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF9CFF3F),
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            formatCurrency(
                              point.amount,
                              hideValues: _hideValues,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Saúde da carteira',
          subtitle:
              'O app faz um checklist rápido para dizer se a carteira está protegendo bem.',
          child: Column(
            children: data.healthItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FinanceSoftInfoCard(
                  title: item.title,
                  text: item.message,
                  icon: item.icon,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildControlSection() {
    final items = _store.filteredTransactions.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Controle',
          subtitle: 'Aqui fica o lado mais detalhado do financeiro.',
          child: Column(
            children: [
              FinanceFilterChips(
                current: _store.selectedFilter,
                onChanged: _store.setFilter,
              ),
              const SizedBox(height: 12),
              FinancePeriodChips(
                current: _store.selectedPeriod,
                onChanged: _store.setPeriod,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FinanceCompactStatCard(
                      title: 'Registros',
                      value: _store.filteredTransactionCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceCompactStatCard(
                      title: 'Top categoria',
                      value: _store.topExpenseCategory?.name ?? '—',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Lançamentos',
          subtitle: 'Últimos registros do filtro atual.',
          child: Column(
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhum lançamento encontrado.'),
                )
              else
                ...items.map(
                  (tx) => FinanceTransactionTile(
                    transaction: tx,
                    amountLabel: formatCurrency(
                      tx.amount,
                      hideValues: _hideValues,
                    ),
                    dateLabel: formatShortDate(tx.date),
                    onEdit: () => _openEditTransactionPage(tx),
                    onDelete: () => _confirmRemoveTransaction(tx),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return _buildVisionSection();
      case 1:
        return _buildPlanningSection();
      case 2:
        return _buildInvestSection();
      case 3:
        return _buildControlSection();
      default:
        return _buildVisionSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddTransactionPage,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Lançar'),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
              children: [
                FinanceHeroCard(
                  title: 'Finanças',
                  subtitle: _financePeriodLabel(_store.selectedPeriod),
                  balanceLabel: 'Saldo disponível',
                  balanceValue: formatCurrency(
                    _store.balance,
                    hideValues: _hideValues,
                  ),
                  hideValues: _hideValues,
                  onTogglePrivacy: _loadingPrefs ? null : _togglePrivacy,
                  onLeadingTap: _openQuickAdjustSheet,
                  metrics: [
                    FinanceHeroMetric(
                      label: 'Entradas',
                      value: formatCurrency(
                        _store.totalIncome,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.call_received_rounded,
                      color: const Color(0xFF9CFF3F),
                    ),
                    FinanceHeroMetric(
                      label: 'Saídas',
                      value: formatCurrency(
                        _store.totalExpense,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.call_made_rounded,
                      color: const Color(0xFFFF5D73),
                    ),
                    FinanceHeroMetric(
                      label: 'Débito',
                      value: formatCurrency(
                        _store.totalDebitExpense,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF39D0FF),
                    ),
                    FinanceHeroMetric(
                      label: 'Crédito',
                      value: formatCurrency(
                        _store.totalCreditExpense,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.credit_card_outlined,
                      color: const Color(0xFF6C63FF),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FinanceSectionTabs(
                  currentIndex: _currentSection,
                  onChanged: (index) => setState(() => _currentSection = index),
                ),
                const SizedBox(height: 14),
                _buildCurrentSection(),
              ],
            ),
          ),
        );
      },
    );
  }
}
