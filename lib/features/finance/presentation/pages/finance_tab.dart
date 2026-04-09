// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance_tab.dart
//
// O que faz:
// - Deixa Finanças mais clara, visual e rápida de entender
// - Mantém o store financeiro atual do app
// - Mostra saldo, entradas, saídas, crédito, débito e visão por categoria
// - Mantém edição/remoção de transações
// - Cria um bloco de "caixinhas" manuais para orçamento, dívidas, reserva,
//   investimentos, dinheiro separado e metas
// - Continua salvando o snapshot usado por Áreas para orçamento, dívidas,
//   reserva e metas
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/areas/areas_store.dart';

import '../../data/models/finance_filter_type.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../../data/models/finance_entry_type.dart';
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
  final AreasStore _areasStore = AreasStore();

  double? _manualBudget;
  double? _manualDebts;
  double? _manualReserve;
  double? _manualGoalsProgress;
  double? _manualInvestments;
  double? _manualSeparatedMoney;

  bool _manualLoading = true;
  bool _manualSaving = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? FinanceStore();
    if (!_store.hasLoaded && !_store.isLoading) {
      _store.load();
    }
    _loadManualFinanceData();
  }

  String _currency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _currencyNullable(double? value) {
    if (value == null) return 'Não definido';
    return _currency(value);
  }

  String _percentNullable(double? value) {
    if (value == null) return 'Não definido';
    return '${value.toStringAsFixed(0)}%';
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([_store.load(), _loadManualFinanceData()]);
    if (mounted) setState(() {});
  }

  Future<void> _loadManualFinanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _manualLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    double? readNum(List<String> keys) {
      for (final key in keys) {
        final raw = prefs.get(key);
        if (raw is int) return raw.toDouble();
        if (raw is double) return raw;
        if (raw is String) {
          final normalized = raw.replaceAll(',', '.').trim();
          final value = double.tryParse(normalized);
          if (value != null) return value;
        }
      }
      return null;
    }

    if (!mounted) return;
    setState(() {
      _manualBudget = readNum([
        '$uid:monthly_budget',
        '$uid:finance_monthly_budget',
        '$uid:budget',
      ]);
      _manualDebts = readNum([
        '$uid:total_debts',
        '$uid:finance_total_debts',
        '$uid:debts',
      ]);
      _manualReserve = readNum([
        '$uid:emergency_reserve',
        '$uid:finance_emergency_reserve',
        '$uid:reserve',
      ]);
      _manualGoalsProgress = readNum([
        '$uid:finance_goals_progress',
        '$uid:goals_fin_progress',
      ]);
      _manualInvestments = readNum([
        '$uid:finance_investments_total',
        '$uid:finance_investments',
      ]);
      _manualSeparatedMoney = readNum([
        '$uid:finance_separated_money',
        '$uid:separated_money',
      ]);
      _manualLoading = false;
    });
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
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir transação'),
          content: Text('Deseja excluir "${transaction.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _store.removeTransaction(transaction.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transação "${transaction.title}" excluída.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  Future<void> _openManualFinanceSheet() async {
    final budgetController = TextEditingController(
      text: _manualBudget?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final debtsController = TextEditingController(
      text: _manualDebts?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final reserveController = TextEditingController(
      text: _manualReserve?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final goalsController = TextEditingController(
      text: _manualGoalsProgress?.toStringAsFixed(0) ?? '',
    );
    final investmentsController = TextEditingController(
      text: _manualInvestments?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
    final separatedController = TextEditingController(
      text:
          _manualSeparatedMoney?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );

    double? parseMoney(String raw) {
      final normalized = raw
          .replaceAll('R\$', '')
          .replaceAll(' ', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }

    double? parsePercent(String raw) {
      final normalized = raw.replaceAll('%', '').replaceAll(',', '.').trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: StatefulBuilder(
            builder: (sheetInnerContext, setSheetState) {
              Future<void> save() async {
                final budget = parseMoney(budgetController.text);
                final debts = parseMoney(debtsController.text);
                final reserve = parseMoney(reserveController.text);
                final goals = parsePercent(goalsController.text);
                final investments = parseMoney(investmentsController.text);
                final separated = parseMoney(separatedController.text);

                if (goals != null && (goals < 0 || goals > 100)) {
                  ScaffoldMessenger.of(sheetInnerContext).showSnackBar(
                    const SnackBar(
                      content: Text('As metas devem ficar entre 0 e 100%.'),
                    ),
                  );
                  return;
                }

                setSheetState(() {});
                if (mounted) {
                  setState(() => _manualSaving = true);
                }

                await _areasStore.saveFinanceSnapshot(
                  monthlyBudget: budget,
                  totalDebts: debts,
                  emergencyReserve: reserve,
                  goalsProgress: goals,
                );

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    '${user.uid}:finance_investments_total',
                    investments?.toString() ?? '',
                  );
                  await prefs.setString(
                    '${user.uid}:finance_separated_money',
                    separated?.toString() ?? '',
                  );
                }

                if (!mounted) return;
                setState(() {
                  _manualBudget = budget;
                  _manualDebts = debts;
                  _manualReserve = reserve;
                  _manualGoalsProgress = goals;
                  _manualInvestments = investments;
                  _manualSeparatedMoney = separated;
                  _manualSaving = false;
                });

                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Caixinhas financeiras atualizadas.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }

              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1120),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Organizar seu dinheiro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Preencha o que ainda não vem das transações reais. Isso deixa Finanças mais clara e também ajuda Áreas.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.74),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _MoneyInput(
                      label: 'Orçamento mensal',
                      controller: budgetController,
                      hint: 'Ex.: 2500',
                    ),
                    const SizedBox(height: 12),
                    _MoneyInput(
                      label: 'Dívidas fora do cartão',
                      controller: debtsController,
                      hint: 'Ex.: 800',
                    ),
                    const SizedBox(height: 12),
                    _MoneyInput(
                      label: 'Reserva de emergência',
                      controller: reserveController,
                      hint: 'Ex.: 1500',
                    ),
                    const SizedBox(height: 12),
                    _MoneyInput(
                      label: 'Investimentos',
                      controller: investmentsController,
                      hint: 'Ex.: 3000',
                    ),
                    const SizedBox(height: 12),
                    _MoneyInput(
                      label: 'Dinheiro separado por objetivo',
                      controller: separatedController,
                      hint: 'Ex.: 450',
                    ),
                    const SizedBox(height: 12),
                    _PercentInput(
                      label: 'Metas financeiras',
                      controller: goalsController,
                      hint: 'Ex.: 45',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _manualSaving ? null : save,
                      icon: _manualSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Salvar'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _entryLabel(FinanceTransaction tx) {
    if (tx.isIncome) return 'Entrada • ${tx.entryType.label}';
    return 'Saída • ${tx.entryType.label}';
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Color _accentForBalance(double value) {
    if (value > 0) return const Color(0xFF22C55E);
    if (value < 0) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final balanceColor = _accentForBalance(_store.balance);
        final topCategory = _store.topExpenseCategory;
        final freeToSpend = _manualBudget == null
            ? null
            : (_manualBudget! - _store.totalDebitExpense);

        return Scaffold(
          backgroundColor: const Color(0xFF070A14),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddTransactionPage,
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Lançar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
              children: [
                const SizedBox(height: 6),
                const Text(
                  'Finanças',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Um painel vivo para entender para onde seu dinheiro foi e o que precisa de atenção.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _HeroFinanceCard(
                  title: 'Saldo do período',
                  amount: _currency(_store.balance),
                  accent: balanceColor,
                  subtitle: _store.quickInsight,
                  comparison: _store.periodComparisonText,
                  onQuickAdd: _openAddTransactionPage,
                  onManualTap: _openManualFinanceSheet,
                ),
                const SizedBox(height: 14),
                _SectionTitle(
                  title: 'Visão rápida',
                  trailing: IconButton(
                    onPressed: _openManualFinanceSheet,
                    tooltip: 'Editar caixinhas',
                    icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FinancePeriodType.values.map((period) {
                    return ChoiceChip(
                      label: Text(period.label),
                      selected: _store.selectedPeriod == period,
                      onSelected: (_) => _store.setPeriod(period),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: FinanceFilterType.values.map((filter) {
                    return ChoiceChip(
                      label: Text(filter.label),
                      selected: _store.selectedFilter == filter,
                      onSelected: (_) => _store.setFilter(filter),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.22,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MetricCard(
                      title: 'Entradas',
                      value: _currency(_store.totalIncome),
                      icon: Icons.south_west_rounded,
                      accent: const Color(0xFF22C55E),
                      subtitle:
                          '${_store.transactionCount} lançamentos no período',
                    ),
                    _MetricCard(
                      title: 'Saídas',
                      value: _currency(_store.totalExpense),
                      icon: Icons.north_east_rounded,
                      accent: const Color(0xFFEF4444),
                      subtitle: 'Tudo o que saiu no período',
                    ),
                    _MetricCard(
                      title: 'Cartão',
                      value: _currency(_store.totalCreditExpense),
                      icon: Icons.credit_card_rounded,
                      accent: const Color(0xFFF59E0B),
                      subtitle: 'Gastos que ainda vão bater',
                    ),
                    _MetricCard(
                      title: 'Débito / à vista',
                      value: _currency(_store.totalDebitExpense),
                      icon: Icons.account_balance_wallet_rounded,
                      accent: const Color(0xFF38BDF8),
                      subtitle: 'Saiu do caixa agora',
                    ),
                    _MetricCard(
                      title: 'Maior peso',
                      value: topCategory?.name ?? 'Sem dados',
                      icon:
                          topCategory?.icon ?? Icons.pie_chart_outline_rounded,
                      accent: topCategory?.color ?? const Color(0xFF94A3B8),
                      subtitle: topCategory == null
                          ? 'Ainda sem saídas suficientes'
                          : _currency(_store.topExpenseCategoryAmount),
                    ),
                    _MetricCard(
                      title: 'Livre no mês',
                      value: freeToSpend == null
                          ? 'Defina orçamento'
                          : _currency(freeToSpend),
                      icon: Icons.savings_outlined,
                      accent: freeToSpend == null
                          ? const Color(0xFF94A3B8)
                          : _accentForBalance(freeToSpend),
                      subtitle: freeToSpend == null
                          ? 'Use as caixinhas abaixo'
                          : 'Orçamento - saídas à vista',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Caixinhas financeiras',
                  trailing: TextButton(
                    onPressed: _openManualFinanceSheet,
                    child: const Text('Editar'),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.28,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _SmallVaultCard(
                      label: 'Orçamento',
                      value: _manualLoading
                          ? 'Carregando...'
                          : _currencyNullable(_manualBudget),
                      icon: Icons.calendar_month_rounded,
                      accent: const Color(0xFF60A5FA),
                    ),
                    _SmallVaultCard(
                      label: 'Dívidas fora cartão',
                      value: _manualLoading
                          ? 'Carregando...'
                          : _currencyNullable(_manualDebts),
                      icon: Icons.warning_amber_rounded,
                      accent: const Color(0xFFFB7185),
                    ),
                    _SmallVaultCard(
                      label: 'Reserva',
                      value: _manualLoading
                          ? 'Carregando...'
                          : _currencyNullable(_manualReserve),
                      icon: Icons.shield_moon_outlined,
                      accent: const Color(0xFF34D399),
                    ),
                    _SmallVaultCard(
                      label: 'Investimentos',
                      value: _manualLoading
                          ? 'Carregando...'
                          : _currencyNullable(_manualInvestments),
                      icon: Icons.trending_up_rounded,
                      accent: const Color(0xFFA78BFA),
                    ),
                    _SmallVaultCard(
                      label: 'Dinheiro separado',
                      value: _manualLoading
                          ? 'Carregando...'
                          : _currencyNullable(_manualSeparatedMoney),
                      icon: Icons.inventory_2_outlined,
                      accent: const Color(0xFFF59E0B),
                    ),
                    _SmallVaultCard(
                      label: 'Metas',
                      value: _manualLoading
                          ? 'Carregando...'
                          : _percentNullable(_manualGoalsProgress),
                      icon: Icons.flag_circle_outlined,
                      accent: const Color(0xFF22D3EE),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Para onde o dinheiro foi',
                  trailing: Text(
                    _store.filteredTransactionCount.toString(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1222),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: _store.categoryChartItems.isEmpty
                      ? Text(
                          'Ainda não há saídas suficientes no período para separar por categoria.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            height: 1.35,
                          ),
                        )
                      : Column(
                          children: _store.categoryChartItems.take(5).map((
                            item,
                          ) {
                            final max =
                                _store.categoryChartItems.first.amount == 0
                                ? 1.0
                                : _store.categoryChartItems.first.amount;
                            final progress = (item.amount / max).clamp(
                              0.0,
                              1.0,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: item.color.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(item.icon, color: item.color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.label,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 8,
                                            backgroundColor: Colors.white
                                                .withOpacity(0.08),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  item.color,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _currency(item.amount),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.88),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Movimentações',
                  trailing: TextButton.icon(
                    onPressed: _openAddTransactionPage,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nova'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_store.filteredTransactions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1222),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      'Nada encontrado neste recorte. Tente outro período, outro filtro ou adicione um lançamento.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  ..._store.filteredTransactions.map((tx) {
                    final accent = tx.isIncome
                        ? const Color(0xFF22C55E)
                        : tx.category.color;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TransactionTile(
                        transaction: tx,
                        subtitle: '${_entryLabel(tx)} • ${_dateLabel(tx.date)}',
                        amount: _currency(tx.amount),
                        accent: accent,
                        onTap: () => _openEditTransactionPage(tx),
                        onDelete: () => _confirmRemoveTransaction(tx),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroFinanceCard extends StatelessWidget {
  const _HeroFinanceCard({
    required this.title,
    required this.amount,
    required this.accent,
    required this.subtitle,
    required this.comparison,
    required this.onQuickAdd,
    required this.onManualTap,
  });

  final String title;
  final String amount;
  final Color accent;
  final String subtitle;
  final String comparison;
  final VoidCallback onQuickAdd;
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.22),
            const Color(0xFF101528),
            const Color(0xFF0B101E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onManualTap,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Caixinhas'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            amount,
            style: TextStyle(
              color: accent,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.86),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            comparison,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onQuickAdd,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo lançamento'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1222),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallVaultCard extends StatelessWidget {
  const _SmallVaultCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1222),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const Spacer(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.subtitle,
    required this.amount,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  final FinanceTransaction transaction;
  final String subtitle;
  final String amount;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D1222),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(transaction.category.icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.64),
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
                    amount,
                    style: TextStyle(
                      color: transaction.isIncome
                          ? const Color(0xFF22C55E)
                          : accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.white70,
                    tooltip: 'Excluir',
                    visualDensity: VisualDensity.compact,
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

class _MoneyInput extends StatelessWidget {
  const _MoneyInput({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.70)),
        prefixText: 'R\$ ',
        prefixStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _PercentInput extends StatelessWidget {
  const _PercentInput({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.70)),
        suffixText: '%',
        suffixStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
