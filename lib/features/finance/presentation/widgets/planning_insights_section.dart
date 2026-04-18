// ============================================================================
// FILE: lib/features/finance/presentation/widgets/planning_insights_section.dart
//
// Uso:
// - Este arquivo foi feito para preservar o layout antigo da aba Planejar.
// - Ele adiciona SOMENTE os 2 blocos aprovados:
//   1) Calendário de vencimentos
//   2) Projeção dos próximos 3 meses
//
// Como encaixar:
// - Importe este arquivo na sua finance_tab.dart antiga.
// - Dentro da aba Planejar, no ponto em que quiser mostrar os novos blocos,
//   adicione: PlanningInsightsSection(store: _store)
//
// Compatibilidade:
// - Ajustado para o FinanceStore atual, que expõe `transactions` e
//   `creditTransactions`, mas não possui `allTransactions`.
// - Respeita o modelo atual de crédito parcelado projetado pela store.
// ============================================================================

import 'package:flutter/material.dart';

import '../../data/models/finance_category.dart';
import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';

class PlanningInsightsSection extends StatelessWidget {
  const PlanningInsightsSection({super.key, required this.store});

  final FinanceStore store;

  static const Color _panel = Color(0xFF171327);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _softText = Color(0xFFB8B2D1);

  String _money(double value) {
    final cents = (value.abs() * 100).round();
    final integer = cents ~/ 100;
    final decimal = (cents % 100).toString().padLeft(2, '0');
    final digits = integer.toString();
    final out = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      out.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) out.write('.');
    }

    final sign = value < 0 ? '- ' : '';
    return '${sign}R\$ ${out.toString()},$decimal';
  }

  bool _isImmediateOutflow(FinanceEntryType entryType) {
    switch (entryType) {
      case FinanceEntryType.debit:
      case FinanceEntryType.pixOut:
      case FinanceEntryType.transferOut:
      case FinanceEntryType.cash:
      case FinanceEntryType.boleto:
        return true;
      case FinanceEntryType.credit:
      case FinanceEntryType.pixIn:
      case FinanceEntryType.transferIn:
      case FinanceEntryType.other:
        return false;
    }
  }

  Iterable<FinanceTransaction> _allBaseTransactions() => store.transactions;

  Iterable<FinanceTransaction> _projectedCreditForMonth(DateTime month) sync* {
    final previous = store.selectedPeriod;
    final targetPeriod = _periodForMonth(month);
    if (targetPeriod == null) return;

    store.setPeriod(targetPeriod);
    try {
      for (final tx in store.creditTransactions) {
        if (tx.date.year == month.year && tx.date.month == month.month) {
          yield tx;
        }
      }
    } finally {
      store.setPeriod(previous);
    }
  }

  FinancePeriodType? _periodForMonth(DateTime month) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final previous = DateTime(now.year, now.month - 1, 1);
    final target = DateTime(month.year, month.month, 1);

    if (target.year == current.year && target.month == current.month) {
      return FinancePeriodType.currentMonth;
    }
    if (target.year == previous.year && target.month == previous.month) {
      return FinancePeriodType.previousMonth;
    }
    if (target.year == now.year) {
      return FinancePeriodType.currentYear;
    }
    return FinancePeriodType.allTime;
  }

  double _sumIncomeForMonth(DateTime month) {
    return _allBaseTransactions()
        .where(
          (t) =>
              t.isIncome &&
              t.date.year == month.year &&
              t.date.month == month.month,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _sumImmediateForMonth(DateTime month) {
    return _allBaseTransactions()
        .where(
          (t) =>
              !t.isIncome &&
              t.date.year == month.year &&
              t.date.month == month.month &&
              _isImmediateOutflow(t.entryType),
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _sumCreditForMonth(DateTime month) {
    return _projectedCreditForMonth(
      month,
    ).fold(0.0, (sum, t) => sum + t.amount);
  }

  List<_DueItem> _buildUpcomingDueItems(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    final immediateItems = _allBaseTransactions()
        .where(
          (t) =>
              !t.isIncome &&
              _isImmediateOutflow(t.entryType) &&
              !DateTime(t.date.year, t.date.month, t.date.day).isBefore(today),
        )
        .map(
          (t) => _DueItem(
            title: t.title,
            date: t.date,
            amount: t.amount,
            category: t.category,
            isCredit: false,
            subtitle: t.category.name,
          ),
        );

    final creditItems = <_DueItem>[];
    for (var offset = 0; offset < 3; offset++) {
      final month = DateTime(now.year, now.month + offset, 1);
      for (final t in _projectedCreditForMonth(month)) {
        final itemDate = DateTime(t.date.year, t.date.month, t.date.day);
        if (itemDate.isBefore(today)) continue;
        creditItems.add(
          _DueItem(
            title: t.title,
            date: t.date,
            amount: t.amount,
            category: t.category,
            isCredit: true,
            subtitle: t.installmentTotal > 1
                ? 'Parcela ${t.installmentIndex}/${t.installmentTotal}'
                : t.category.name,
          ),
        );
      }
    }

    final items = <_DueItem>[...immediateItems, ...creditItems]
      ..sort((a, b) => a.date.compareTo(b.date));

    return items.take(8).toList();
  }

  List<_ForecastItem> _buildForecast(DateTime now) {
    return List.generate(3, (index) {
      final month = DateTime(now.year, now.month + index, 1);
      final income = _sumIncomeForMonth(month);
      final immediate = _sumImmediateForMonth(month);
      final credit = _sumCreditForMonth(month);
      final leftover = income - immediate - credit;

      return _ForecastItem(
        month: month,
        expectedIncome: income,
        expectedImmediate: immediate,
        expectedCredit: credit,
        leftover: leftover,
      );
    });
  }

  String _monthLabel(DateTime date) {
    const names = [
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
    return '${names[date.month - 1]}/${date.year}';
  }

  String _dateLabel(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueItems = _buildUpcomingDueItems(now);
    final forecast = _buildForecast(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Calendário de vencimentos',
          subtitle:
              'Próximos compromissos para você visualizar o que vem pela frente.',
        ),
        const SizedBox(height: 12),
        if (dueItems.isEmpty)
          const _EmptyPlanningCard(
            title: 'Sem compromissos próximos',
            subtitle:
                'Quando houver contas, parcelas ou vencimentos futuros, eles aparecem aqui.',
          )
        else
          ...dueItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DueItemCard(
                item: item,
                money: _money,
                dateLabel: _dateLabel,
              ),
            ),
          ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Projeção dos próximos 3 meses',
          subtitle:
              'Resumo simples de entradas, saídas reais e crédito por mês.',
        ),
        const SizedBox(height: 12),
        ...forecast.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ForecastCard(
              item: item,
              money: _money,
              monthLabel: _monthLabel,
            ),
          ),
        ),
      ],
    );
  }
}

class _DueItem {
  const _DueItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.category,
    required this.isCredit,
    required this.subtitle,
  });

  final String title;
  final DateTime date;
  final double amount;
  final FinanceCategory category;
  final bool isCredit;
  final String subtitle;
}

class _ForecastItem {
  const _ForecastItem({
    required this.month,
    required this.expectedIncome,
    required this.expectedImmediate,
    required this.expectedCredit,
    required this.leftover,
  });

  final DateTime month;
  final double expectedIncome;
  final double expectedImmediate;
  final double expectedCredit;
  final double leftover;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: PlanningInsightsSection._softText,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _EmptyPlanningCard extends StatelessWidget {
  const _EmptyPlanningCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PlanningInsightsSection._panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PlanningInsightsSection._purple.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: PlanningInsightsSection._purple,
            ),
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
                  subtitle,
                  style: const TextStyle(
                    color: PlanningInsightsSection._softText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DueItemCard extends StatelessWidget {
  const _DueItemCard({
    required this.item,
    required this.money,
    required this.dateLabel,
  });

  final _DueItem item;
  final String Function(double) money;
  final String Function(DateTime) dateLabel;

  @override
  Widget build(BuildContext context) {
    final color = item.isCredit
        ? PlanningInsightsSection._purple
        : const Color(0xFFFFB020);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PlanningInsightsSection._panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.category.icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.subtitle} • ${dateLabel(item.date)}',
                  style: const TextStyle(
                    color: PlanningInsightsSection._softText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(item.amount),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.item,
    required this.money,
    required this.monthLabel,
  });

  final _ForecastItem item;
  final String Function(double) money;
  final String Function(DateTime) monthLabel;

  @override
  Widget build(BuildContext context) {
    final safe = item.leftover >= 0;
    final color = safe ? const Color(0xFF28C76F) : const Color(0xFFFF5B5B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PlanningInsightsSection._panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                monthLabel(item.month),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                money(item.leftover),
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                  label: 'Entradas',
                  value: money(item.expectedIncome),
                ),
              ),
              Expanded(
                child: _MiniInfo(
                  label: 'Saídas',
                  value: money(item.expectedImmediate),
                ),
              ),
              Expanded(
                child: _MiniInfo(
                  label: 'Crédito',
                  value: money(item.expectedCredit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: PlanningInsightsSection._softText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
