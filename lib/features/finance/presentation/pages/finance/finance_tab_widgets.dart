// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_tab_widgets.dart
//
// Widgets reutilizáveis da tela de Finanças.
//
// O que este arquivo faz:
// - Agrupa hero, tabs, cards, chips, sheets e tiles de lançamento.
// - Deixa o finance_tab.dart focado na lógica e no fluxo da tela.
// - Mantém a identidade visual do financeiro em um lugar só.
// ============================================================================

import 'package:flutter/material.dart';

import '../../../data/models/finance_filter_type.dart';
import '../../../data/models/finance_period_type.dart';
import '../../../data/models/finance_transaction.dart';
import 'finance_tab_models.dart';

String _financeWidgetPeriodLabel(FinancePeriodType period) {
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

String _financeWidgetFilterLabel(FinanceFilterType filter) {
  switch (filter) {
    case FinanceFilterType.all:
      return 'Todas';
    case FinanceFilterType.income:
      return 'Entradas';
    case FinanceFilterType.expense:
      return 'Saídas';
    case FinanceFilterType.debit:
      return 'Débito';
    case FinanceFilterType.credit:
      return 'Crédito';
  }
}

class FinanceHeroCard extends StatelessWidget {
  const FinanceHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.balanceLabel,
    required this.balanceValue,
    required this.onTogglePrivacy,
    required this.hideValues,
    required this.metrics,
    this.onLeadingTap,
  });

  final String title;
  final String subtitle;
  final String balanceLabel;
  final String balanceValue;
  final VoidCallback? onTogglePrivacy;
  final bool hideValues;
  final List<FinanceHeroMetric> metrics;
  final VoidCallback? onLeadingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF103E33), Color(0xFF0B6B50)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B6B50).withOpacity(0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onLeadingTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onTogglePrivacy,
                tooltip: hideValues ? 'Mostrar valores' : 'Ocultar valores',
                icon: Icon(
                  hideValues
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            balanceLabel,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            balanceValue,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.25,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return FinanceMetricCard(metric: metric);
            },
          ),
        ],
      ),
    );
  }
}

class FinanceMetricCard extends StatelessWidget {
  const FinanceMetricCard({super.key, required this.metric});

  final FinanceHeroMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: metric.color.withOpacity(0.16),
            ),
            child: Icon(metric.icon, size: 18, color: metric.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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

class FinanceSectionTabs extends StatelessWidget {
  const FinanceSectionTabs({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _labels = ['Visão', 'Planejar', 'Investir', 'Controle'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0B1012),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: List<Widget>.generate(_labels.length, (index) {
          final selected = currentIndex == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: selected
                      ? const Color(0xFF35D26F)
                      : Colors.transparent,
                ),
                child: Text(
                  _labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.black
                        : Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w800,
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

class FinanceSectionCard extends StatelessWidget {
  const FinanceSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class FinanceValueBadge extends StatelessWidget {
  const FinanceValueBadge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceMiniPercentCard extends StatelessWidget {
  const FinanceMiniPercentCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceSoftInfoCard extends StatelessWidget {
  const FinanceSoftInfoCard({
    super.key,
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
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF39D0FF)),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceSheetFrame extends StatelessWidget {
  const FinanceSheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 60, 10, 10),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
        decoration: BoxDecoration(
          color: const Color(0xFF071112),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceTextField extends StatelessWidget {
  const FinanceTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class FinancePeriodChips extends StatelessWidget {
  const FinancePeriodChips({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final FinancePeriodType current;
  final ValueChanged<FinancePeriodType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FinancePeriodType.values.map((period) {
        return ChoiceChip(
          label: Text(_financeWidgetPeriodLabel(period)),
          selected: current == period,
          onSelected: (_) => onChanged(period),
        );
      }).toList(),
    );
  }
}

class FinanceFilterChips extends StatelessWidget {
  const FinanceFilterChips({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final FinanceFilterType current;
  final ValueChanged<FinanceFilterType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FinanceFilterType.values.map((filter) {
        return ChoiceChip(
          label: Text(_financeWidgetFilterLabel(filter)),
          selected: current == filter,
          onSelected: (_) => onChanged(filter),
        );
      }).toList(),
    );
  }
}

class FinanceCompactStatCard extends StatelessWidget {
  const FinanceCompactStatCard({
    super.key,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class FinanceLegendDot extends StatelessWidget {
  const FinanceLegendDot({super.key, required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class FinanceCategorySummaryTile extends StatelessWidget {
  const FinanceCategorySummaryTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color, size: 18),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.68)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class FinanceTransactionTile extends StatelessWidget {
  const FinanceTransactionTile({
    super.key,
    required this.transaction,
    required this.amountLabel,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final FinanceTransaction transaction;
  final String amountLabel;
  final String dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = transaction.isIncome
        ? const Color(0xFF9CFF3F)
        : (transaction.entryType.name.contains('credit')
              ? const Color(0xFF6C63FF)
              : const Color(0xFFFF5D73));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withOpacity(0.16),
            child: Icon(transaction.category.icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.category.name} • $dateLabel',
                  style: TextStyle(color: Colors.white.withOpacity(0.68)),
                ),
                if ((transaction.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    transaction.note!.trim(),
                    style: TextStyle(color: Colors.white.withOpacity(0.60)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountLabel,
                style: TextStyle(fontWeight: FontWeight.w900, color: accent),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
