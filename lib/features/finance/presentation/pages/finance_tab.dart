import 'package:flutter/material.dart';

import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_filter_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';
import 'add_transaction_page.dart';

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  late final FinanceStore _store;

  @override
  void initState() {
    super.initState();
    _store = FinanceStore();
    _store.load();
  }

  String _currency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Color _softCategoryColor(Color color) {
    return color.withAlpha(40);
  }

  Future<void> _openAddTransactionPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionPage(store: _store)),
    );
  }

  Future<void> _openEditTransactionPage(FinanceTransaction transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionPage(store: _store, initialTransaction: transaction),
      ),
    );
  }

  Future<void> _confirmRemoveTransaction(FinanceTransaction transaction) async {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transação "${transaction.title}" excluída.')),
    );
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
            return _EmptyFinanceState(onAddPressed: _openAddTransactionPage);
          }

          final transactions = _store.filteredTransactions;
          final topCategory = _store.topExpenseCategory;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
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
                      'Nenhuma transação encontrada para este filtro.',
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
                        '${category.name} - ${_entryTypeLabel(transaction.entryType)}',
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
