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

import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';
import 'add_transaction_page.dart';
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

  double _investedPrincipal = 0;
  double _investedCurrentValue = 0;
  double _monthlyInvestmentContribution = 0;
  double _annualInterestRate = 10;
  double _investmentTarget = 0;

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

  Future<void> _togglePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_hideValues;
    await prefs.setBool('$_prefsPrefix:finance_hide_values', next);
    if (!mounted) return;
    setState(() => _hideValues = next);
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

    int localPreset = _planningPresetIndex;
    double essential = _planningEssentialPercent;
    double future = _planningFuturePercent;
    double free = _planningFreePercent;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final preview = _buildPlanningBuckets(
              income: parseMoney(incomeController.text),
              essentialPercent: essential,
              futurePercent: future,
              freePercent: free,
            );

            return FinanceSheetFrame(
              title: 'Planejar o mês',
              subtitle: 'Escolha um modelo simples para separar sua renda.',
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
                  const SizedBox(height: 18),
                  const Text(
                    'Sugestão automática',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...preview.map(_buildPlanPreviewTile),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final income = parseMoney(incomeController.text);
                        await prefs.setDouble(
                          '$_prefsPrefix:finance_income_plan',
                          income,
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
          },
        );
      },
    );
  }

  Future<void> _openInvestmentSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final principalController = TextEditingController(
      text: _investedPrincipal == 0 ? '' : moneyField(_investedPrincipal),
    );
    final currentValueController = TextEditingController(
      text: _investedCurrentValue == 0 ? '' : moneyField(_investedCurrentValue),
    );
    final monthlyContributionController = TextEditingController(
      text: _monthlyInvestmentContribution == 0
          ? ''
          : moneyField(_monthlyInvestmentContribution),
    );
    final rateController = TextEditingController(
      text: _annualInterestRate == 0
          ? ''
          : _annualInterestRate.toStringAsFixed(2),
    );
    final targetController = TextEditingController(
      text: _investmentTarget == 0 ? '' : moneyField(_investmentTarget),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FinanceSheetFrame(
          title: 'Ajustar investimentos',
          subtitle: 'Seu dinheiro aportado é só o que saiu do seu bolso.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FinanceTextField(
                controller: principalController,
                label: 'Seu dinheiro já aportado',
                prefixText: 'R\$ ',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: currentValueController,
                label: 'Montante atual',
                prefixText: 'R\$ ',
                icon: Icons.savings_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: monthlyContributionController,
                label: 'Aporte mensal',
                prefixText: 'R\$ ',
                icon: Icons.calendar_month_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: rateController,
                label: 'Juros médios ao ano',
                suffixText: '%',
                icon: Icons.trending_up_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: targetController,
                label: 'Meta de patrimônio',
                prefixText: 'R\$ ',
                icon: Icons.flag_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              const FinanceSoftInfoCard(
                title: 'Como ler',
                text:
                    'Montante atual = seu dinheiro aportado + rendimento. '
                    'A projeção abaixo não desconta IR, IOF, taxas ou inflação.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_principal',
                      parseMoney(principalController.text),
                    );
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_current_value',
                      parseMoney(currentValueController.text),
                    );
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_monthly_contribution',
                      parseMoney(monthlyContributionController.text),
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

  List<FinancePlanningBucket> _buildPlanningBuckets({
    required double income,
    required double essentialPercent,
    required double futurePercent,
    required double freePercent,
  }) {
    final essentialTotal = income * (essentialPercent / 100);
    final futureTotal = income * (futurePercent / 100);
    final freeTotal = income * (freePercent / 100);

    return [
      FinancePlanningBucket(
        title: 'Moradia + contas',
        subtitle: 'aluguel, energia, água, internet',
        amount: essentialTotal * 0.45,
        color: const Color(0xFF28C76F),
      ),
      FinancePlanningBucket(
        title: 'Alimentação',
        subtitle: 'mercado, padaria, açougue, hortifruti',
        amount: essentialTotal * 0.25,
        color: const Color(0xFF00C2A8),
      ),
      FinancePlanningBucket(
        title: 'Transporte + saúde',
        subtitle: 'combustível, ônibus, remédios, consultas',
        amount: essentialTotal * 0.20,
        color: const Color(0xFF39D0FF),
      ),
      FinancePlanningBucket(
        title: 'Investir + reserva',
        subtitle: 'reserva, caixinha, ações, FIIs',
        amount: futureTotal,
        color: const Color(0xFF6C63FF),
      ),
      FinancePlanningBucket(
        title: 'Livre + lazer',
        subtitle: 'restaurantes, delivery, roupas, hobbies',
        amount: freeTotal,
        color: const Color(0xFFFFB020),
      ),
      FinancePlanningBucket(
        title: 'Margem de ajuste',
        subtitle: 'sobras para reorganizar o mês',
        amount: math.max(
          0,
          income - (essentialTotal * 0.90 + futureTotal + freeTotal),
        ),
        color: const Color(0xFFFF6B6B),
      ),
    ];
  }

  Map<String, double> _buildPlanningSummary() {
    final income = _monthlyIncomePlan;
    return {
      'Renda planejada': income,
      'Essenciais': income * (_planningEssentialPercent / 100),
      'Investir + reserva': income * (_planningFuturePercent / 100),
      'Livre': income * (_planningFreePercent / 100),
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

  FinanceInvestmentViewData _buildInvestmentData() {
    final current = _investedCurrentValue;
    final principal = _investedPrincipal;
    final monthly = _monthlyInvestmentContribution;
    final annualRate = _annualInterestRate;
    final monthlyRate = annualRate <= 0 ? 0 : annualRate / 100 / 12;
    final earnings = math.max(0.0, current - principal).toDouble();
    final progress = _investmentTarget <= 0
        ? 0.0
        : (current / _investmentTarget).clamp(0.0, 1.0);

    final snapshots = <FinanceInvestmentSnapshot>[];
    for (final months in <int>[6, 12, 24, 60]) {
      double total = current;
      double principalPart = principal;
      for (int i = 0; i < months; i++) {
        total += monthly;
        principalPart += monthly;
        total *= (1 + monthlyRate);
      }
      snapshots.add(
        FinanceInvestmentSnapshot(
          label: months >= 12 ? '${months ~/ 12}a' : '${months}m',
          total: total,
          principal: principalPart,
          earnings: math.max(0.0, total - principalPart).toDouble(),
        ),
      );
    }

    int? monthsToTarget;
    if (_investmentTarget > 0 && current < _investmentTarget) {
      double total = current;
      int safety = 0;
      while (total < _investmentTarget && safety < 1200) {
        total += monthly;
        total *= (1 + monthlyRate);
        safety++;
      }
      if (safety < 1200) monthsToTarget = safety;
    }

    return FinanceInvestmentViewData(
      principal: principal,
      current: current,
      earnings: earnings,
      monthlyContribution: monthly,
      annualRate: annualRate,
      target: _investmentTarget,
      targetProgress: progress,
      monthsToTarget: monthsToTarget,
      snapshots: snapshots,
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
    final preview = _buildPlanningBuckets(
      income: _monthlyIncomePlan,
      essentialPercent: _planningEssentialPercent,
      futurePercent: _planningFuturePercent,
      freePercent: _planningFreePercent,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Planejamento do mês',
          subtitle: 'Separação simples para não virar planilha chata.',
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Sugestão de divisão',
          subtitle:
              'Base simples para você começar e depois ajustar com o dedo ou pela voz.',
          child: Column(
            children: preview.take(5).map(_buildPlanPreviewTile).toList(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Investimentos',
          subtitle:
              'Seu dinheiro, rendimento e meta em uma leitura mais clara.',
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
                      label: 'Seu dinheiro',
                      value: formatCurrency(
                        data.principal,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF39D0FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Rendimento',
                      value: formatCurrency(
                        data.earnings,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFFFFB020),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Montante atual',
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
                      label: 'Aporte mensal',
                      value: formatCurrency(
                        data.monthlyContribution,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF9CFF3F),
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
                    text: 'Juros / rendimento',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (data.target > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Progresso até a meta',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ),
                    Text(
                      formatCurrency(data.target, hideValues: _hideValues),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: data.targetProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.monthsToTarget == null
                      ? 'Com os dados atuais, a meta ainda não foi alcançada.'
                      : 'Mantendo esse ritmo, a projeção chega na meta em cerca de ${data.monthsToTarget} meses.',
                  style: TextStyle(color: Colors.white.withOpacity(0.72)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Projeção visual',
          subtitle:
              'Comparação do seu dinheiro x rendimento ao longo do tempo.',
          child: Column(
            children: data.snapshots.map((snap) {
              final total = snap.total <= 0 ? 1.0 : snap.total;
              final ownRatio = (snap.principal / total).clamp(0.0, 1.0);
              final earnRatio = (snap.earnings / total).clamp(0.0, 1.0);
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
                          Text(
                            snap.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            formatCurrency(snap.total, hideValues: _hideValues),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              Expanded(
                                flex: math.max(1, (ownRatio * 1000).round()),
                                child: Container(
                                  color: const Color(0xFF39D0FF),
                                ),
                              ),
                              Expanded(
                                flex: math.max(1, (earnRatio * 1000).round()),
                                child: Container(
                                  color: const Color(0xFFFFB020),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seu dinheiro: ${formatCurrency(snap.principal, hideValues: _hideValues)}  •  Juros: ${formatCurrency(snap.earnings, hideValues: _hideValues)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.72)),
                      ),
                    ],
                  ),
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
