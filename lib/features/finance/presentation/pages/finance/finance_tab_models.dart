// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_tab_models.dart
//
// Modelos leves usados apenas pela UI da tela de Finanças.
//
// O que este arquivo faz:
// - Guarda os modelos visuais do Financeiro 2.0.
// - Evita deixar o finance_tab.dart cheio de classes pequenas.
// - Mantém os dados da tela separados da lógica do store principal.
// ============================================================================

import 'package:flutter/material.dart';

import '../../../data/models/finance_category.dart';

class FinancePlanningPreset {
  const FinancePlanningPreset({
    required this.label,
    required this.essential,
    required this.future,
    required this.free,
  });

  final String label;
  final double essential;
  final double future;
  final double free;
}

class FinancePlanningBucket {
  const FinancePlanningBucket({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final String title;
  final String subtitle;
  final double amount;
  final Color color;
}

class FinanceCategoryTotal {
  const FinanceCategoryTotal({required this.category, required this.total});

  final FinanceCategory category;
  final double total;
}

class FinanceInvestmentSnapshot {
  const FinanceInvestmentSnapshot({
    required this.label,
    required this.total,
    required this.principal,
    required this.earnings,
  });

  final String label;
  final double total;
  final double principal;
  final double earnings;
}

class FinanceInvestmentViewData {
  const FinanceInvestmentViewData({
    required this.principal,
    required this.current,
    required this.earnings,
    required this.monthlyContribution,
    required this.annualRate,
    required this.target,
    required this.targetProgress,
    required this.monthsToTarget,
    required this.snapshots,
  });

  final double principal;
  final double current;
  final double earnings;
  final double monthlyContribution;
  final double annualRate;
  final double target;
  final double targetProgress;
  final int? monthsToTarget;
  final List<FinanceInvestmentSnapshot> snapshots;
}

class FinanceHeroMetric {
  const FinanceHeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
