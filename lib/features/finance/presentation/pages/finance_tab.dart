// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance_tab.dart
//
// Tela principal do financeiro do Vida.
//
// O que este arquivo faz:
// - Deixa a home do financeiro mais viva e com menos altura no topo.
// - Mantém o básico em destaque: saldo, entradas, saídas, débito e crédito.
// - Separa o restante em 4 áreas internas: Visão, Planejar, Investir e Controle.
// - Planejar foca em distribuição da renda e metas do mês, sem misturar com
//   simulação de investimentos.
// - Investir vira uma área própria com aporte, patrimônio atual, rendimento,
//   projeções e tempo estimado até uma meta.
// - Controle concentra filtro/período, recorrências, parcelas, tags e histórico.
// - Corrige overflows usando layout flexível e sheets com rolagem segura.
// ============================================================================

import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/finance_filter_type.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';
import '../widgets/expense_category_chart.dart';
import 'add_transaction_page.dart';

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
  int _investmentMode = 0;

  bool _showQuickModules = true;
  bool _showPlanningPreview = true;
  bool _showCategoryFocus = true;
  bool _showRecentTransactions = true;

  double _monthlyIncomePlan = 0;
  Map<String, double> _plannedByCategory = <String, double>{};

  double _investedPrincipal = 0;
  double _investedCurrentValue = 0;
  double _monthlyInvestmentContribution = 0;
  double _annualInterestRate = 10;
  double _investmentTarget = 0;

  String get _prefsPrefix {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    return (uid == null || uid.isEmpty) ? 'anon' : uid;
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
  }

  Future<void> _refreshAll() async {
    await _store.load();
    await _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nextPlanned = <String, double>{};

    for (final category in _expenseCategories) {
      nextPlanned[category.id] =
          prefs.getDouble('$_prefsPrefix:plan:${category.id}') ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _hideValues = prefs.getBool('$_prefsPrefix:finance_hide_values') ?? false;
      _showQuickModules =
          prefs.getBool('$_prefsPrefix:finance_home_modules') ?? true;
      _showPlanningPreview =
          prefs.getBool('$_prefsPrefix:finance_home_planning_preview') ?? true;
      _showCategoryFocus =
          prefs.getBool('$_prefsPrefix:finance_home_category_focus') ?? true;
      _showRecentTransactions =
          prefs.getBool('$_prefsPrefix:finance_home_recent') ?? true;
      _monthlyIncomePlan =
          prefs.getDouble('$_prefsPrefix:finance_income_plan') ?? 0;
      _plannedByCategory = nextPlanned;
      _investedPrincipal =
          prefs.getDouble('$_prefsPrefix:invest_principal') ?? 0;
      _investedCurrentValue =
          prefs.getDouble('$_prefsPrefix:invest_current_value') ?? 0;
      _monthlyInvestmentContribution =
          prefs.getDouble('$_prefsPrefix:invest_monthly_contribution') ?? 0;
      _annualInterestRate =
          prefs.getDouble('$_prefsPrefix:invest_annual_rate') ?? 10;
      _investmentTarget = prefs.getDouble('$_prefsPrefix:invest_target') ?? 0;
      _loadingPrefs = false;
    });
  }

  List<dynamic> get _expenseCategories =>
      _store.categories.where((item) => item.isIncomeCategory != true).toList();

  Future<void> _togglePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_hideValues;
    await prefs.setBool('$_prefsPrefix:finance_hide_values', next);
    if (!mounted) return;
    setState(() => _hideValues = next);
  }

  Future<void> _openAddTransactionPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionPage(store: _store)),
    );
    await _refreshAll();
  }

  Future<void> _openEditTransactionPage(FinanceTransaction transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionPage(store: _store, initialTransaction: transaction),
      ),
    );
    await _refreshAll();
  }

  Future<void> _confirmRemoveTransaction(FinanceTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );

    if (confirmed != true) return;
    await _store.removeTransaction(transaction.id);
  }

  Future<void> _openHomeCustomizeSheet() async {
    final prefs = await SharedPreferences.getInstance();
    bool localModules = _showQuickModules;
    bool localPlanning = _showPlanningPreview;
    bool localCategory = _showCategoryFocus;
    bool localRecent = _showRecentTransactions;

    await _showLargeSheet(
      title: 'Personalizar financeiro',
      subtitle:
          'Deixe a home mais enxuta ou mais completa sem perder a pegada do app.',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          Widget buildToggle({
            required String title,
            required String subtitle,
            required bool value,
            required ValueChanged<bool> onChanged,
          }) {
            return _SheetToggleTile(
              title: title,
              subtitle: subtitle,
              value: value,
              onChanged: (next) => setSheetState(() => onChanged(next)),
            );
          }

          return Column(
            children: [
              buildToggle(
                title: 'Módulos rápidos',
                subtitle: 'Cards para abrir Planejar, Investir e Controle.',
                value: localModules,
                onChanged: (value) => localModules = value,
              ),
              const SizedBox(height: 12),
              buildToggle(
                title: 'Prévia do planejamento',
                subtitle: 'Mostra renda planejada, distribuído e livre.',
                value: localPlanning,
                onChanged: (value) => localPlanning = value,
              ),
              const SizedBox(height: 12),
              buildToggle(
                title: 'Foco por categoria',
                subtitle: 'Mostra as categorias que mais pesam no período.',
                value: localCategory,
                onChanged: (value) => localCategory = value,
              ),
              const SizedBox(height: 12),
              buildToggle(
                title: 'Lançamentos recentes',
                subtitle: 'Mantém os últimos registros logo na home.',
                value: localRecent,
                onChanged: (value) => localRecent = value,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await prefs.setBool(
                      '$_prefsPrefix:finance_home_modules',
                      localModules,
                    );
                    await prefs.setBool(
                      '$_prefsPrefix:finance_home_planning_preview',
                      localPlanning,
                    );
                    await prefs.setBool(
                      '$_prefsPrefix:finance_home_category_focus',
                      localCategory,
                    );
                    await prefs.setBool(
                      '$_prefsPrefix:finance_home_recent',
                      localRecent,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    await _loadPrefs();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar aparência da home'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPlanningSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final incomeController = TextEditingController(
      text: _moneyField(_monthlyIncomePlan),
    );
    final controllers = <String, TextEditingController>{
      for (final category in _expenseCategories)
        category.id: TextEditingController(
          text: _moneyField(_plannedByCategory[category.id] ?? 0),
        ),
    };

    double parseMoney(TextEditingController controller) {
      return double.tryParse(
            controller.text.trim().replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    await _showLargeSheet(
      title: 'Planejar o mês',
      subtitle:
          'Aqui você define a renda esperada e distribui para cada parte da vida sem misturar com investimentos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetField(
            controller: incomeController,
            label: 'Renda planejada do mês',
            prefixText: 'R\$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 16),
          _HintBand(
            title: 'Sugestão base',
            text:
                'Para começar sem neura: separe primeiro essenciais, depois metas e só então o restante para conforto e lazer.',
            icon: Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: 18),
          const Text(
            'Distribuição por categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ..._expenseCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SheetField(
                controller: controllers[category.id]!,
                label: category.name,
                prefixText: 'R\$ ',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                icon: category.icon,
                iconColor: category.color,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await prefs.setDouble(
                  '$_prefsPrefix:finance_income_plan',
                  parseMoney(incomeController),
                );
                for (final category in _expenseCategories) {
                  await prefs.setDouble(
                    '$_prefsPrefix:plan:${category.id}',
                    parseMoney(controllers[category.id]!),
                  );
                }
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadPrefs();
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Salvar planejamento'),
            ),
          ),
        ],
      ),
    );

    incomeController.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<void> _openInvestmentSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final principalController = TextEditingController(
      text: _moneyField(_investedPrincipal),
    );
    final currentValueController = TextEditingController(
      text: _moneyField(_investedCurrentValue),
    );
    final monthlyContributionController = TextEditingController(
      text: _moneyField(_monthlyInvestmentContribution),
    );
    final rateController = TextEditingController(
      text: _annualInterestRate == 0
          ? ''
          : _annualInterestRate.toStringAsFixed(1).replaceAll('.', ','),
    );
    final targetController = TextEditingController(
      text: _moneyField(_investmentTarget),
    );

    double parseMoney(TextEditingController controller) {
      return double.tryParse(
            controller.text.trim().replaceAll('.', '').replaceAll(',', '.'),
          ) ??
          0;
    }

    double parsePercent(TextEditingController controller) {
      return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    }

    await _showLargeSheet(
      title: 'Ajustar investimentos',
      subtitle:
          'Área separada da renda do mês. Aqui você controla patrimônio investido, aporte e meta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetField(
            controller: principalController,
            label: 'Quanto do patrimônio foi seu dinheiro',
            prefixText: 'R\$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: currentValueController,
            label: 'Valor atual investido',
            prefixText: 'R\$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.savings_outlined,
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: monthlyContributionController,
            label: 'Aporte mensal planejado',
            prefixText: 'R\$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: rateController,
            label: 'Taxa média anual usada na simulação',
            suffixText: '%',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: targetController,
            label: 'Meta de patrimônio',
            prefixText: 'R\$ ',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 16),
          _HintBand(
            title: 'Importante',
            text:
                'Aqui é manual e simples: ótimo para ter noção do caminho, sem virar um home broker dentro do Vida.',
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await prefs.setDouble(
                  '$_prefsPrefix:invest_principal',
                  parseMoney(principalController),
                );
                await prefs.setDouble(
                  '$_prefsPrefix:invest_current_value',
                  parseMoney(currentValueController),
                );
                await prefs.setDouble(
                  '$_prefsPrefix:invest_monthly_contribution',
                  parseMoney(monthlyContributionController),
                );
                await prefs.setDouble(
                  '$_prefsPrefix:invest_annual_rate',
                  parsePercent(rateController),
                );
                await prefs.setDouble(
                  '$_prefsPrefix:invest_target',
                  parseMoney(targetController),
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadPrefs();
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Salvar investimentos'),
            ),
          ),
        ],
      ),
    );

    principalController.dispose();
    currentValueController.dispose();
    monthlyContributionController.dispose();
    rateController.dispose();
    targetController.dispose();
  }

  Future<void> _showLargeSheet({
    required String title,
    required String subtitle,
    required Widget child,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final media = MediaQuery.of(context);
        final theme = Theme.of(context);
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: _panelColor(theme),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withOpacity(0.24),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        24 + media.viewInsets.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.76),
                            ),
                          ),
                          const SizedBox(height: 20),
                          child,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final totalBalance = _store.balance;
        final totalIncome = _store.totalIncome;
        final totalExpense = _store.totalExpense;
        final totalDebit = _store.totalDebitExpense;
        final totalCredit = _store.totalCreditExpense;

        final planningSummary = _buildPlanningSummary();
        final categoryFocus = _buildCategoryFocusItems();
        final investmentData = _buildInvestmentData();
        final recentItems = _store.recentTransactions.take(5).toList();
        final recurringRules = _recurringRules();
        final tagTotals = _currentPeriodTagTotals();

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddTransactionPage,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Lançar'),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
              children: [
                _CompactFinanceHero(
                  title: 'Finanças',
                  subtitle:
                      'Visão viva do dinheiro • ${_store.selectedPeriod.label}',
                  mainLabel: 'Saldo disponível',
                  mainValue: _displayMoney(totalBalance),
                  insight: _store.quickInsight,
                  onTogglePrivacy: _loadingPrefs ? null : _togglePrivacy,
                  onCustomize: _loadingPrefs ? null : _openHomeCustomizeSheet,
                  hideValues: _hideValues,
                  metricCards: [
                    _HeroMetricData(
                      label: 'Entradas',
                      value: _displayMoney(totalIncome),
                      icon: Icons.call_received_rounded,
                    ),
                    _HeroMetricData(
                      label: 'Saídas',
                      value: _displayMoney(totalExpense),
                      icon: Icons.call_made_rounded,
                    ),
                    _HeroMetricData(
                      label: 'Débito',
                      value: _displayMoney(totalDebit),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _HeroMetricData(
                      label: 'Crédito',
                      value: _displayMoney(totalCredit),
                      icon: Icons.credit_card_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _FinanceSectionTabs(
                  index: _currentSection,
                  onChanged: (index) => setState(() => _currentSection = index),
                ),
                const SizedBox(height: 12),
                if (_currentSection == 0) ...[
                  if (_showQuickModules)
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Módulos do financeiro',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cada parte mais forte fica em um lugar próprio.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _QuickJumpCard(
                                title: 'Planejamento',
                                subtitle:
                                    'Distribuição da renda e metas do mês',
                                icon: Icons.edit_note_rounded,
                                accentA: const Color(0xFF27C5E8),
                                accentB: const Color(0xFF1A7F9C),
                                onTap: () =>
                                    setState(() => _currentSection = 1),
                              ),
                              _QuickJumpCard(
                                title: 'Investimentos',
                                subtitle: 'Patrimônio, rendimento e meta',
                                icon: Icons.trending_up_rounded,
                                accentA: const Color(0xFF7B61FF),
                                accentB: const Color(0xFF4327A8),
                                onTap: () =>
                                    setState(() => _currentSection = 2),
                              ),
                              _QuickJumpCard(
                                title: 'Controle',
                                subtitle: 'Filtros, histórico e recorrências',
                                icon: Icons.tune_rounded,
                                accentA: const Color(0xFFF2B13C),
                                accentB: const Color(0xFFB86A0F),
                                onTap: () =>
                                    setState(() => _currentSection = 3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_showQuickModules) const SizedBox(height: 12),
                  if (_showPlanningPreview)
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Distribuição consciente da renda',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _openPlanningSheet,
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Editar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Preview rápido. O detalhado fica em Planejar.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _MiniInfoCard(
                                title: 'Renda planejada',
                                value: _displayMoney(planningSummary.income),
                                accent: const Color(0xFF31D68A),
                              ),
                              _MiniInfoCard(
                                title: 'Distribuído',
                                value: _displayMoney(planningSummary.allocated),
                                accent: const Color(0xFF28C7E8),
                              ),
                              _MiniInfoCard(
                                title: 'Poupar / metas',
                                value: _displayMoney(
                                  planningSummary.goalReserve,
                                ),
                                accent: const Color(0xFF7B61FF),
                              ),
                              _MiniInfoCard(
                                title: 'Livre no mês',
                                value: _displayMoney(planningSummary.free),
                                accent: const Color(0xFFFFB347),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (_showPlanningPreview) const SizedBox(height: 12),
                  if (_showCategoryFocus)
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Onde o dinheiro mais pesa',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Só o que importa agora, sem entulhar a home.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (categoryFocus.isEmpty)
                            const Text(
                              'Ainda não há categorias fortes o suficiente neste período.',
                            )
                          else
                            ...categoryFocus.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CategoryFocusTile(
                                  title: item.label,
                                  value: _displayMoney(item.amount),
                                  ratio: item.ratio,
                                  color: item.color,
                                  icon: item.icon,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_showCategoryFocus) const SizedBox(height: 12),
                  if (_store.categoryChartItems.isNotEmpty)
                    ExpenseCategoryChart(
                      items: _store.categoryChartItems.take(5).toList(),
                      currencyFormatter: _displayMoney,
                    ),
                  if (_store.categoryChartItems.isNotEmpty)
                    const SizedBox(height: 12),
                  if (_showRecentTransactions)
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Últimos lançamentos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Uma visão curta. O histórico completo fica em Controle.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (recentItems.isEmpty)
                            const Text('Nenhum lançamento recente por aqui.')
                          else
                            ...recentItems
                                .take(4)
                                .map(
                                  (transaction) => _SimpleTransactionTile(
                                    transaction: transaction,
                                    subtitle: _buildTransactionSubtitle(
                                      transaction,
                                    ),
                                    moneyFormatter: _displayMoney,
                                  ),
                                ),
                        ],
                      ),
                    ),
                ] else if (_currentSection == 1) ...[
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Planejamento do mês',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _openPlanningSheet,
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Editar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A ideia aqui é dar direção: quanto entra, para onde vai e quanto sobra para viver sem culpa.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MiniInfoCard(
                              title: 'Renda do mês',
                              value: _displayMoney(planningSummary.income),
                              accent: const Color(0xFF31D68A),
                            ),
                            _MiniInfoCard(
                              title: 'Essenciais',
                              value: _displayMoney(planningSummary.essentials),
                              accent: const Color(0xFF28C7E8),
                            ),
                            _MiniInfoCard(
                              title: 'Flexível / lazer',
                              value: _displayMoney(planningSummary.flexible),
                              accent: const Color(0xFFFFB347),
                            ),
                            _MiniInfoCard(
                              title: 'Metas / reserva',
                              value: _displayMoney(planningSummary.goalReserve),
                              accent: const Color(0xFF7B61FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _HintBand(
                          title: 'Leitura do mês',
                          text: _planningMessage(planningSummary),
                          icon: Icons.checklist_rtl_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distribuição por área da vida',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Planejado x gasto no mês. Não precisa ser perfeito: serve para te orientar, não para te punir.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._planningBreakdownItems().map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _PlanningBudgetTile(
                              title: item.category.name,
                              planned: _displayMoney(item.planned),
                              spent: _displayMoney(item.spent),
                              ratio: item.ratio,
                              color: item.category.color,
                              icon: item.category.icon,
                            ),
                          ),
                        ),
                        if (_planningBreakdownItems().isEmpty)
                          const Text(
                            'Defina valores no planejamento para enxergar a distribuição por área.',
                          ),
                      ],
                    ),
                  ),
                ] else if (_currentSection == 2) ...[
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Investimentos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _openInvestmentSheet,
                              icon: const Icon(Icons.tune_rounded),
                              label: const Text('Ajustar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Área separada da renda pessoal. Serve para acompanhar patrimônio, rendimento e o caminho até uma meta.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MiniInfoCard(
                              title: 'Seu dinheiro aportado',
                              value: _displayMoney(investmentData.principal),
                              accent: const Color(0xFF31D68A),
                            ),
                            _MiniInfoCard(
                              title: 'Valor atual',
                              value: _displayMoney(investmentData.currentValue),
                              accent: const Color(0xFF28C7E8),
                            ),
                            _MiniInfoCard(
                              title: 'Rendimento',
                              value: _displayMoney(investmentData.earnings),
                              accent: const Color(0xFF7B61FF),
                            ),
                            _MiniInfoCard(
                              title: 'Rentabilidade',
                              value: investmentData.performanceText,
                              accent: const Color(0xFFFFB347),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              label: const Text('Montante futuro'),
                              selected: _investmentMode == 0,
                              onSelected: (_) =>
                                  setState(() => _investmentMode = 0),
                            ),
                            ChoiceChip(
                              label: const Text('Tempo até meta'),
                              selected: _investmentMode == 1,
                              onSelected: (_) =>
                                  setState(() => _investmentMode = 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_investmentMode == 0)
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _ProjectionCard(
                                      label: '1 ano',
                                      value: _displayMoney(
                                        investmentData.after1Year,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ProjectionCard(
                                      label: '3 anos',
                                      value: _displayMoney(
                                        investmentData.after3Years,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ProjectionCard(
                                      label: '5 anos',
                                      value: _displayMoney(
                                        investmentData.after5Years,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _ProjectionCard(
                                      label: '10 anos',
                                      value: _displayMoney(
                                        investmentData.after10Years,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          _GoalTimeCard(
                            target: _displayMoney(investmentData.target),
                            currentValue: _displayMoney(
                              investmentData.currentValue,
                            ),
                            monthlyContribution: _displayMoney(
                              investmentData.monthlyContribution,
                            ),
                            etaText: investmentData.etaText,
                            progress: investmentData.targetProgress,
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Controle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aqui fica a parte mais detalhada: filtros, período, recorrências, parcelas, tags e histórico completo.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Período',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: FinancePeriodType.values
                                .map(
                                  (period) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(period.label),
                                      selected: _store.selectedPeriod == period,
                                      onSelected: (_) =>
                                          _store.setPeriod(period),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Filtro',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: FinanceFilterType.values
                                .map(
                                  (filter) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(filter.label),
                                      selected: _store.selectedFilter == filter,
                                      onSelected: (_) =>
                                          _store.setFilter(filter),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recorrências e tags',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (recurringRules.isEmpty)
                          const Text('Nenhuma recorrência cadastrada ainda.')
                        else
                          ...recurringRules.map(
                            (rule) => _RecurringTile(
                              title: rule.title,
                              subtitle:
                                  'Todo dia ${rule.dayOfMonth} • ${rule.category.name}',
                              amount: _displayMoney(rule.amount),
                              color: rule.category.color,
                              icon: rule.category.icon,
                              isIncome: rule.isIncome,
                            ),
                          ),
                        if (recurringRules.isNotEmpty)
                          const SizedBox(height: 10),
                        if (tagTotals.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tagTotals.entries
                                .map(
                                  (entry) => Chip(
                                    label: Text(
                                      '${entry.key} • ${_displayMoney(entry.value)}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Histórico completo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toque para editar. O detalhamento mais pesado fica aqui para não poluir a home.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_store.filteredTransactions.isEmpty)
                          const Text(
                            'Nenhum lançamento encontrado neste filtro.',
                          )
                        else
                          ..._store.filteredTransactions.map(
                            (transaction) => _HistoryTransactionTile(
                              transaction: transaction,
                              subtitle: _buildTransactionSubtitle(transaction),
                              moneyFormatter: _displayMoney,
                              onEdit: () =>
                                  _openEditTransactionPage(transaction),
                              onDelete: () =>
                                  _confirmRemoveTransaction(transaction),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildTransactionSubtitle(FinanceTransaction transaction) {
    final parts = <String>[
      '${transaction.date.day.toString().padLeft(2, '0')}/${transaction.date.month.toString().padLeft(2, '0')}',
      transaction.category.name,
    ];

    if ((transaction.subcategory ?? '').trim().isNotEmpty) {
      parts.add(transaction.subcategory!.trim());
    }
    if ((transaction.tag ?? '').trim().isNotEmpty) {
      parts.add('#${transaction.tag!.trim()}');
    }
    if (transaction.isInstallment) {
      parts.add('Parcela ${transaction.installmentLabel}');
    }
    if (transaction.isRecurring) {
      parts.add('Recorrente');
    }

    return parts.join(' • ');
  }

  String _displayMoney(double value) {
    if (_hideValues) return 'R\$ ••••';
    return _currency(value);
  }

  String _currency(double value) {
    final negative = value < 0;
    final absValue = value.abs();
    final fixed = absValue.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final cents = parts[1];

    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final reverseIndex = whole.length - i;
      buffer.write(whole[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${negative ? '- ' : ''}R\$ ${buffer.toString()},$cents';
  }

  String _moneyField(double value) {
    if (value == 0) return '';
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  _PlanningSummary _buildPlanningSummary() {
    final income = _monthlyIncomePlan;
    var essentials = 0.0;
    var flexible = 0.0;

    for (final item in _planningBreakdownItems()) {
      if (_isEssentialCategory(item.category)) {
        essentials += item.planned;
      } else {
        flexible += item.planned;
      }
    }

    final goalReserve = math.max(0.0, income - essentials - flexible);
    final allocated = essentials + flexible;
    final free = math.max(0.0, income - allocated);

    return _PlanningSummary(
      income: income,
      essentials: essentials,
      flexible: flexible,
      goalReserve: goalReserve,
      allocated: allocated,
      free: free,
    );
  }

  List<_PlanningBreakdownItem> _planningBreakdownItems() {
    final spentByCategory = <String, double>{};
    final now = DateTime.now();

    for (final transaction in _store.transactions) {
      if (transaction.isIncome) continue;
      if (transaction.date.year != now.year ||
          transaction.date.month != now.month)
        continue;
      spentByCategory.update(
        transaction.category.id,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final items = <_PlanningBreakdownItem>[];
    for (final category in _expenseCategories) {
      final planned = _plannedByCategory[category.id] ?? 0;
      final spent = spentByCategory[category.id] ?? 0;
      if (planned <= 0 && spent <= 0) continue;
      items.add(
        _PlanningBreakdownItem(
          category: category,
          planned: planned,
          spent: spent,
        ),
      );
    }

    items.sort((a, b) => (b.planned + b.spent).compareTo(a.planned + a.spent));
    return items;
  }

  bool _isEssentialCategory(dynamic category) {
    final id = '${category.id}'.toLowerCase();
    final name = '${category.name}'.toLowerCase();
    return id.contains('home') ||
        id.contains('food') ||
        id.contains('transport') ||
        id.contains('health') ||
        id.contains('education') ||
        name.contains('casa') ||
        name.contains('aliment') ||
        name.contains('transporte') ||
        name.contains('saúde') ||
        name.contains('educa');
  }

  String _planningMessage(_PlanningSummary summary) {
    if (summary.income <= 0) {
      return 'Comece preenchendo a renda planejada do mês para o Vida conseguir sugerir melhor o equilíbrio entre viver, poupar e cumprir metas.';
    }
    final essentialsRatio = summary.income == 0
        ? 0
        : summary.essentials / summary.income;
    final flexibleRatio = summary.income == 0
        ? 0
        : summary.flexible / summary.income;

    if (essentialsRatio > 0.7) {
      return 'Seu mês está bem puxado nas partes essenciais. Talvez valha aliviar alguma categoria variável para sobrar mais respiro.';
    }
    if (flexibleRatio > 0.35) {
      return 'O lado flexível está ocupando bastante espaço. Se tiver metas grandes, talvez seja um bom mês para apertar só um pouco.';
    }
    if (summary.free > summary.income * 0.15) {
      return 'Você ainda tem uma boa parte livre. Dá para usar isso como margem de segurança ou reforçar uma meta.';
    }
    return 'Seu planejamento está equilibrado: essenciais, conforto e metas convivendo de um jeito saudável.';
  }

  List<_CategoryFocusItem> _buildCategoryFocusItems() {
    final items = _store.categoryChartItems.take(3).toList();
    if (items.isEmpty) return const <_CategoryFocusItem>[];
    final maxAmount = items.fold<double>(
      0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return items
        .map(
          (item) => _CategoryFocusItem(
            label: item.label,
            amount: item.amount,
            ratio: maxAmount <= 0 ? 0 : item.amount / maxAmount,
            color: item.color,
            icon: item.icon,
          ),
        )
        .toList();
  }

  List<_RecurringRule> _recurringRules() {
    final seen = <String>{};
    final rules = <_RecurringRule>[];

    for (final transaction in _store.transactions.where(
      (item) => item.isRecurring,
    )) {
      final key =
          '${transaction.title}|${transaction.amount}|${transaction.category.id}|${transaction.recurringDayOfMonth ?? transaction.date.day}|${transaction.isIncome}';
      if (!seen.add(key)) continue;
      rules.add(
        _RecurringRule(
          title: transaction.title,
          amount: transaction.amount,
          dayOfMonth: transaction.recurringDayOfMonth ?? transaction.date.day,
          category: transaction.category,
          isIncome: transaction.isIncome,
        ),
      );
    }

    rules.sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
    return rules;
  }

  Map<String, double> _currentPeriodTagTotals() {
    final result = <String, double>{};
    for (final transaction in _store.periodTransactions) {
      final tag = (transaction.tag ?? '').trim();
      if (tag.isEmpty) continue;
      result.update(
        tag,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return Map<String, double>.fromEntries(
      result.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  _InvestmentData _buildInvestmentData() {
    double simulateFuture({required int months}) {
      var value = _investedCurrentValue;
      final monthlyRate = (_annualInterestRate / 100) / 12;
      for (var i = 0; i < months; i++) {
        value = (value * (1 + monthlyRate)) + _monthlyInvestmentContribution;
      }
      return value;
    }

    int? estimateMonthsToTarget() {
      if (_investmentTarget <= 0) return null;
      if (_investedCurrentValue >= _investmentTarget) return 0;
      final monthlyRate = (_annualInterestRate / 100) / 12;
      var value = _investedCurrentValue;
      for (var month = 1; month <= 1200; month++) {
        value = (value * (1 + monthlyRate)) + _monthlyInvestmentContribution;
        if (value >= _investmentTarget) return month;
      }
      return null;
    }

    final earnings = _investedCurrentValue - _investedPrincipal;
    final performance = _investedPrincipal > 0
        ? (earnings / _investedPrincipal) * 100
        : 0.0;
    final monthsToTarget = estimateMonthsToTarget();
    final targetProgress = _investmentTarget <= 0
        ? 0.0
        : (_investedCurrentValue / _investmentTarget).clamp(0.0, 1.0);

    return _InvestmentData(
      principal: _investedPrincipal,
      currentValue: _investedCurrentValue,
      earnings: earnings,
      performanceText:
          '${performance.toStringAsFixed(1).replaceAll('.', ',')}%',
      monthlyContribution: _monthlyInvestmentContribution,
      annualRate: _annualInterestRate,
      target: _investmentTarget,
      after1Year: simulateFuture(months: 12),
      after3Years: simulateFuture(months: 36),
      after5Years: simulateFuture(months: 60),
      after10Years: simulateFuture(months: 120),
      etaText: _etaText(monthsToTarget),
      targetProgress: targetProgress,
    );
  }

  String _etaText(int? months) {
    if (months == null) {
      return 'Meta ainda distante com os dados atuais.';
    }
    if (months == 0) {
      return 'Meta já alcançada.';
    }
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years <= 0) {
      return '$months meses';
    }
    if (remainingMonths == 0) {
      return '$years anos';
    }
    return '$years anos e $remainingMonths meses';
  }
}

class _CompactFinanceHero extends StatelessWidget {
  const _CompactFinanceHero({
    required this.title,
    required this.subtitle,
    required this.mainLabel,
    required this.mainValue,
    required this.insight,
    required this.onTogglePrivacy,
    required this.onCustomize,
    required this.hideValues,
    required this.metricCards,
  });

  final String title;
  final String subtitle;
  final String mainLabel;
  final String mainValue;
  final String insight;
  final VoidCallback? onTogglePrivacy;
  final VoidCallback? onCustomize;
  final bool hideValues;
  final List<_HeroMetricData> metricCards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF157E55), Color(0xFF0B3D31)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF157E55).withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.78)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onTogglePrivacy,
                icon: Icon(
                  hideValues
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: onCustomize,
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mainLabel,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mainValue,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            insight,
            style: TextStyle(color: Colors.white.withOpacity(0.82)),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 10.0;
              final itemWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: 10,
                children: metricCards
                    .map(
                      (metric) => SizedBox(
                        width: itemWidth,
                        child: _HeroMetricCard(data: metric),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroMetricData {
  const _HeroMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({required this.data});

  final _HeroMetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.10),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: Colors.white.withOpacity(0.90), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.74),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceSectionTabs extends StatelessWidget {
  const _FinanceSectionTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Visão', 'Planejar', 'Investir', 'Controle'];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: List.generate(labels.length, (itemIndex) {
          final selected = itemIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(itemIndex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: selected
                      ? const Color(0xFF32D96B)
                      : Colors.transparent,
                ),
                child: Text(
                  labels[itemIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.black
                        : Colors.white.withOpacity(0.84),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class _QuickJumpCard extends StatelessWidget {
  const _QuickJumpCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentA,
    required this.accentB,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentA;
  final Color accentB;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accentA, accentB],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withOpacity(0.12),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.88)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintBand extends StatelessWidget {
  const _HintBand({
    required this.title,
    required this.text,
    required this.icon,
  });

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.08),
            ),
            child: Icon(icon, color: const Color(0xFF32D96B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(color: Colors.white.withOpacity(0.74)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFocusTile extends StatelessWidget {
  const _CategoryFocusTile({
    required this.title,
    required this.value,
    required this.ratio,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final double ratio;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.16),
              foregroundColor: color,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.16),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SimpleTransactionTile extends StatelessWidget {
  const _SimpleTransactionTile({
    required this.transaction,
    required this.subtitle,
    required this.moneyFormatter,
  });

  final FinanceTransaction transaction;
  final String subtitle;
  final String Function(double value) moneyFormatter;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isIncome
        ? const Color(0xFF31D68A)
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: transaction.category.color.withOpacity(0.16),
              foregroundColor: transaction.category.color,
              child: Icon(transaction.category.icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              moneyFormatter(transaction.amount),
              style: TextStyle(fontWeight: FontWeight.w800, color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanningBudgetTile extends StatelessWidget {
  const _PlanningBudgetTile({
    required this.title,
    required this.planned,
    required this.spent,
    required this.ratio,
    required this.color,
    required this.icon,
  });

  final String title;
  final String planned;
  final String spent;
  final double ratio;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final progressColor = ratio < 0.75
        ? const Color(0xFF31D68A)
        : ratio < 1
        ? const Color(0xFFFFB347)
        : const Color(0xFFFF5E5E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.16),
              foregroundColor: color,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Planejado: $planned',
                style: TextStyle(color: Colors.white.withOpacity(0.72)),
              ),
            ),
            Text(
              'Gasto: $spent',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio.isNaN ? 0 : ratio.clamp(0.0, 1.0),
            backgroundColor: progressColor.withOpacity(0.16),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.72))),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _GoalTimeCard extends StatelessWidget {
  const _GoalTimeCard({
    required this.target,
    required this.currentValue,
    required this.monthlyContribution,
    required this.etaText,
    required this.progress,
  });

  final String target;
  final String currentValue;
  final String monthlyContribution;
  final String etaText;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _GoalMini(label: 'Meta', value: target),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GoalMini(label: 'Atual', value: currentValue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GoalMini(label: 'Aporte mensal', value: monthlyContribution),
          const SizedBox(height: 14),
          Text(
            'Tempo estimado',
            style: TextStyle(color: Colors.white.withOpacity(0.72)),
          ),
          const SizedBox(height: 4),
          Text(
            etaText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF32D96B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalMini extends StatelessWidget {
  const _GoalMini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.72))),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.icon,
    required this.isIncome,
  });

  final String title;
  final String subtitle;
  final String amount;
  final Color color;
  final IconData icon;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.16),
              foregroundColor: color,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.68),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isIncome ? const Color(0xFF31D68A) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTransactionTile extends StatelessWidget {
  const _HistoryTransactionTile({
    required this.transaction,
    required this.subtitle,
    required this.moneyFormatter,
    required this.onEdit,
    required this.onDelete,
  });

  final FinanceTransaction transaction;
  final String subtitle;
  final String Function(double value) moneyFormatter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: transaction.category.color.withOpacity(0.16),
                foregroundColor: transaction.category.color,
                child: Icon(transaction.category.icon, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    moneyFormatter(transaction.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: transaction.isIncome
                          ? const Color(0xFF31D68A)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetToggleTile extends StatelessWidget {
  const _SheetToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.74)),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.keyboardType,
    required this.icon,
    this.iconColor,
    this.prefixText,
    this.suffixText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final IconData icon;
  final Color? iconColor;
  final String? prefixText;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixIcon: Icon(icon, color: iconColor),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
    );
  }
}

class _PlanningSummary {
  const _PlanningSummary({
    required this.income,
    required this.essentials,
    required this.flexible,
    required this.goalReserve,
    required this.allocated,
    required this.free,
  });

  final double income;
  final double essentials;
  final double flexible;
  final double goalReserve;
  final double allocated;
  final double free;
}

class _PlanningBreakdownItem {
  const _PlanningBreakdownItem({
    required this.category,
    required this.planned,
    required this.spent,
  });

  final dynamic category;
  final double planned;
  final double spent;

  double get ratio {
    if (planned <= 0) return spent > 0 ? 1.0 : 0.0;
    return spent / planned;
  }
}

class _CategoryFocusItem {
  const _CategoryFocusItem({
    required this.label,
    required this.amount,
    required this.ratio,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final double ratio;
  final Color color;
  final IconData icon;
}

class _RecurringRule {
  const _RecurringRule({
    required this.title,
    required this.amount,
    required this.dayOfMonth,
    required this.category,
    required this.isIncome,
  });

  final String title;
  final double amount;
  final int dayOfMonth;
  final dynamic category;
  final bool isIncome;
}

class _InvestmentData {
  const _InvestmentData({
    required this.principal,
    required this.currentValue,
    required this.earnings,
    required this.performanceText,
    required this.monthlyContribution,
    required this.annualRate,
    required this.target,
    required this.after1Year,
    required this.after3Years,
    required this.after5Years,
    required this.after10Years,
    required this.etaText,
    required this.targetProgress,
  });

  final double principal;
  final double currentValue;
  final double earnings;
  final String performanceText;
  final double monthlyContribution;
  final double annualRate;
  final double target;
  final double after1Year;
  final double after3Years;
  final double after5Years;
  final double after10Years;
  final String etaText;
  final double targetProgress;
}

Color _panelColor(ThemeData theme) {
  return theme.brightness == Brightness.dark
      ? const Color(0xFF091512)
      : const Color(0xFFF4F6F8);
}
