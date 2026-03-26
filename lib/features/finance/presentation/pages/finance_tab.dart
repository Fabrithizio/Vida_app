// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance_tab.dart
//
// O que faz:
// - Exibe a área de Finanças
// - Mostra entradas, saídas, saldo, gráficos e movimentações
// - Permite preencher manualmente os dados complementares usados pela área
//   "Finanças & Material" do painel Areas:
//
//   * orçamento mensal
//   * dívidas
//   * reserva de emergência
//   * progresso das metas financeiras
//
// Resultado:
// - income e spending continuam vindo das transações reais
// - budget, debts, reserve e goals passam a poder ser preenchidos aqui
// - isso alimenta diretamente a área de vida "Finanças & Material"
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/areas/areas_store.dart';

import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_filter_type.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';
import '../widgets/expense_category_chart.dart';
import 'add_transaction_page.dart';

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

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
  bool _manualLoading = true;
  bool _manualSaving = false;

  @override
  void initState() {
    super.initState();
    _store = FinanceStore();
    _store.load();
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

  Color _softCategoryColor(Color color) {
    return color.withAlpha(40);
  }

  Future<void> _loadManualFinanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _manualLoading = false;
      });
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
      _manualLoading = false;
    });
  }

  Future<void> _openAddTransactionPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionPage(store: _store)),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openEditTransactionPage(FinanceTransaction transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionPage(store: _store, initialTransaction: transaction),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmRemoveTransaction(FinanceTransaction transaction) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir transação'),
          content: Text('Deseja excluir a transação "${transaction.title}"?'),
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
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Transação "${transaction.title}" excluída.')),
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

    double? parseMoney(String raw) {
      final normalized = raw
          .replaceAll('R\$', '')
          .replaceAll(' ', '')
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;

        return StatefulBuilder(
          builder: (sheetInnerContext, setSheetState) {
            Future<void> save() async {
              final budget = parseMoney(budgetController.text);
              final debts = parseMoney(debtsController.text);
              final reserve = parseMoney(reserveController.text);
              final goals = parsePercent(goalsController.text);

              final messenger = ScaffoldMessenger.of(sheetInnerContext);
              final navigator = Navigator.of(sheetContext);

              if (goals != null && (goals < 0 || goals > 100)) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'O progresso das metas deve ficar entre 0 e 100.',
                    ),
                  ),
                );
                return;
              }

              setSheetState(() {});
              if (mounted) {
                setState(() {
                  _manualSaving = true;
                });
              }

              await _areasStore.saveFinanceSnapshot(
                monthlyBudget: budget,
                totalDebts: debts,
                emergencyReserve: reserve,
                goalsProgress: goals,
              );

              if (!mounted) return;

              setState(() {
                _manualBudget = budget;
                _manualDebts = debts;
                _manualReserve = reserve;
                _manualGoalsProgress = goals;
                _manualSaving = false;
              });

              navigator.pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Dados complementares salvos. A área Finanças & Material foi atualizada.',
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(sheetInnerContext).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Base do painel da vida',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Preencha os dados que ainda não vêm automaticamente das transações.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: budgetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Orçamento mensal',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: debtsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Dívidas atuais',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reserveController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Reserva de emergência',
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: goalsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Progresso das metas financeiras',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _manualSaving ? null : save,
                          icon: _manualSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text('Salvar dados complementares'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransactionPage,
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          if (_store.isLoading && !_store.hasLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_store.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _ManualFinanceBridgeCard(
                  isLoading: _manualLoading,
                  budgetText: _currencyNullable(_manualBudget),
                  debtsText: _currencyNullable(_manualDebts),
                  reserveText: _currencyNullable(_manualReserve),
                  goalsText: _percentNullable(_manualGoalsProgress),
                  onEdit: _openManualFinanceSheet,
                ),
                const SizedBox(height: 28),
                _EmptyFinanceState(onAddPressed: _openAddTransactionPage),
              ],
            );
          }

          final transactions = _store.filteredTransactions;
          final topCategory = _store.topExpenseCategory;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ManualFinanceBridgeCard(
                isLoading: _manualLoading,
                budgetText: _currencyNullable(_manualBudget),
                debtsText: _currencyNullable(_manualDebts),
                reserveText: _currencyNullable(_manualReserve),
                goalsText: _percentNullable(_manualGoalsProgress),
                onEdit: _openManualFinanceSheet,
              ),
              const SizedBox(height: 20),
              const Text(
                'Período',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FinancePeriodType.values.map((period) {
                  final selected = _store.selectedPeriod == period;
                  return ChoiceChip(
                    label: Text(period.label),
                    selected: selected,
                    onSelected: (_) {
                      _store.setPeriod(period);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Entrou',
                      value: _currency(_store.totalIncome),
                      icon: Icons.arrow_downward_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Saiu',
                      value: _currency(_store.totalExpense),
                      icon: Icons.arrow_upward_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Saldo do período',
                value: _currency(_store.balance),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Débito',
                      value: _currency(_store.totalDebitExpense),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Crédito',
                      value: _currency(_store.totalCreditExpense),
                      icon: Icons.credit_card_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ExpenseCategoryChart(
                items: _store.categoryChartItems,
                currencyFormatter: _currency,
              ),
              const SizedBox(height: 20),
              const Text(
                'Comparação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _InsightCard(
                icon: Icons.compare_arrows_outlined,
                title: 'Comparação com período anterior',
                description: _store.periodComparisonText,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      title: 'Saídas atuais',
                      value: _currency(_store.totalExpense),
                      icon: Icons.trending_up_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStatCard(
                      title: 'Saídas anteriores',
                      value: _currency(_store.previousPeriodExpense),
                      icon: Icons.history_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Insights rápidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _InsightCard(
                icon: Icons.insights_outlined,
                title: 'Resumo',
                description: _store.quickInsight,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      title: 'Transações',
                      value: '${_store.transactionCount}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStatCard(
                      title: 'Maior gasto',
                      value: topCategory == null ? '—' : topCategory.name,
                      icon: Icons.local_fire_department_outlined,
                    ),
                  ),
                ],
              ),
              if (topCategory != null) ...[
                const SizedBox(height: 12),
                _InsightCard(
                  icon: topCategory.icon,
                  title: 'Categoria que mais pesou',
                  description:
                      '${topCategory.name} somou ${_currency(_store.topExpenseCategoryAmount)}.',
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Filtros',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FinanceFilterType.values.map((filter) {
                  final selected = _store.selectedFilter == filter;
                  return FilterChip(
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: (_) {
                      _store.setFilter(filter);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'Movimentações (${_store.filteredTransactionCount})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (transactions.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nenhuma transação encontrada para este período/filtro.',
                    ),
                  ),
                )
              else
                ...transactions.map((transaction) {
                  final category = transaction.category;
                  final amountText = transaction.isIncome
                      ? '+ ${_currency(transaction.amount)}'
                      : '- ${_currency(transaction.amount)}';

                  return Card(
                    child: ListTile(
                      onTap: () => _openEditTransactionPage(transaction),
                      leading: CircleAvatar(
                        backgroundColor: _softCategoryColor(category.color),
                        child: Icon(category.icon, color: category.color),
                      ),
                      title: Text(transaction.title),
                      subtitle: Text(
                        '${_formatDate(transaction.date)} • ${category.name} • ${_entryTypeLabel(transaction.entryType)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            amountText,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            tooltip: 'Excluir transação',
                            onPressed: () {
                              _confirmRemoveTransaction(transaction);
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  String _entryTypeLabel(FinanceEntryType type) {
    switch (type) {
      case FinanceEntryType.debit:
        return 'Débito';
      case FinanceEntryType.credit:
        return 'Crédito';
      case FinanceEntryType.pixIn:
        return 'PIX recebido';
      case FinanceEntryType.pixOut:
        return 'PIX enviado';
      case FinanceEntryType.transferIn:
        return 'Transferência recebida';
      case FinanceEntryType.transferOut:
        return 'Transferência enviada';
      case FinanceEntryType.cash:
        return 'Dinheiro';
      case FinanceEntryType.boleto:
        return 'Boleto';
      case FinanceEntryType.other:
        return 'Outro';
    }
  }
}

class _ManualFinanceBridgeCard extends StatelessWidget {
  const _ManualFinanceBridgeCard({
    required this.isLoading,
    required this.budgetText,
    required this.debtsText,
    required this.reserveText,
    required this.goalsText,
    required this.onEdit,
  });

  final bool isLoading;
  final String budgetText;
  final String debtsText;
  final String reserveText;
  final String goalsText;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hub_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Base do painel da vida',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Esses dados completam a leitura da área Finanças & Material no Areas.',
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ManualValueChip(label: 'Orçamento', value: budgetText),
                  _ManualValueChip(label: 'Dívidas', value: debtsText),
                  _ManualValueChip(label: 'Reserva', value: reserveText),
                  _ManualValueChip(label: 'Metas', value: goalsText),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ManualValueChip extends StatelessWidget {
  const _ManualValueChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyFinanceState extends StatelessWidget {
  const _EmptyFinanceState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Sua área financeira ainda está vazia',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione sua primeira transação para começar a acompanhar entradas, saídas, crédito e débito.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar primeira transação'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
