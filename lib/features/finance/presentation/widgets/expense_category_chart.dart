import 'package:flutter/material.dart';

class ExpenseCategoryChartItem {
  const ExpenseCategoryChartItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;
}

class ExpenseCategoryChart extends StatelessWidget {
  const ExpenseCategoryChart({
    super.key,
    required this.items,
    required this.currencyFormatter,
  });

  final List<ExpenseCategoryChartItem> items;
  final String Function(double value) currencyFormatter;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ainda não há gastos suficientes neste período para montar o gráfico.',
          ),
        ),
      );
    }

    final maxAmount = items
        .map((item) => item.amount)
        .fold<double>(0, (max, value) => value > max ? value : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos por categoria',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...items.map((item) {
              final ratio = maxAmount <= 0 ? 0.0 : item.amount / maxAmount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.icon, color: item.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currencyFormatter(item.amount),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: item.color.withAlpha(35),
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
