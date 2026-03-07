import 'package:flutter/material.dart';

import '../../data/models/finance_entry_type.dart';
import '../stores/finance_store.dart';

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
  }

  String _currency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Color _softCategoryColor(Color color) {
    return color.withAlpha(40);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final transactions = _store.recentTransactions;

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
              'Movimentações recentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhuma transação cadastrada ainda.'),
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
                    leading: CircleAvatar(
                      backgroundColor: _softCategoryColor(category.color),
                      child: Icon(category.icon, color: category.color),
                    ),
                    title: Text(transaction.title),
                    subtitle: Text(
                      '${category.name} - ${_entryTypeLabel(transaction.entryType)}',
                    ),
                    trailing: Text(
                      amountText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }),
          ],
        );
      },
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
