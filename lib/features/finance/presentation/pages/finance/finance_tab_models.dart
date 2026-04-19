// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_tab_models.dart
//
// Modelos leves usados pela UI da tela de Finanças.
// ============================================================================

import 'package:flutter/material.dart';

import '../../../data/models/finance_category.dart';

enum FinancePlanningBucketKind { essential, future, free }

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

class FinanceInvestmentBucketConfig {
  const FinanceInvestmentBucketConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.riskLevel,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int riskLevel;
}

enum FinanceInvestmentBenchmarkType { cdi, selic, ipca, fixed, custom, savings }

enum FinanceInvestmentTaxRule {
  regressiveFixedIncome,
  taxFree,
  exemptGain,
  variableIncome15,
  customNone,
}

enum FinanceInvestmentScenarioType { conservative, base, optimistic }

class FinanceInvestmentProductProfile {
  const FinanceInvestmentProductProfile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.benchmarkType,
    required this.multiplier,
    required this.spreadAnnual,
    required this.taxRule,
    required this.isVariableIncome,
    required this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final FinanceInvestmentBenchmarkType benchmarkType;
  final double multiplier;
  final double spreadAnnual;
  final FinanceInvestmentTaxRule taxRule;
  final bool isVariableIncome;
  final String badge;
}

class FinanceInvestmentBucketData {
  const FinanceInvestmentBucketData({
    required this.config,
    required this.principal,
    required this.current,
    required this.monthlyContribution,
    required this.profileId,
    required this.customAnnualRate,
    required this.goalAmount,
  });

  final FinanceInvestmentBucketConfig config;
  final double principal;
  final double current;
  final double monthlyContribution;
  final String profileId;
  final double customAnnualRate;
  final double goalAmount;

  double get earnings => (current - principal) > 0 ? (current - principal) : 0;
}

class FinanceInvestmentCapacityPoint {
  const FinanceInvestmentCapacityPoint({
    required this.label,
    required this.amount,
    required this.isCurrent,
  });

  final String label;
  final double amount;
  final bool isCurrent;
}

class FinanceInvestmentHealthItem {
  const FinanceInvestmentHealthItem({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
}

class FinanceMarketSnapshot {
  const FinanceMarketSnapshot({
    required this.cdiAnnual,
    required this.selicAnnual,
    required this.ipca12Months,
    required this.fetchedAt,
  });

  final double cdiAnnual;
  final double selicAnnual;
  final double ipca12Months;
  final DateTime fetchedAt;
}

class FinanceInvestmentProjectionScenario {
  const FinanceInvestmentProjectionScenario({
    required this.type,
    required this.label,
    required this.years,
    required this.nominalAnnualRate,
    required this.netAnnualRate,
    required this.realAnnualRate,
    required this.grossTotal,
    required this.netTotal,
    required this.realTotal,
    required this.grossGain,
    required this.netGain,
    required this.realGain,
  });

  final FinanceInvestmentScenarioType type;
  final String label;
  final int years;
  final double nominalAnnualRate;
  final double netAnnualRate;
  final double realAnnualRate;
  final double grossTotal;
  final double netTotal;
  final double realTotal;
  final double grossGain;
  final double netGain;
  final double realGain;
}

class FinanceInvestmentGoalProgress {
  const FinanceInvestmentGoalProgress({
    required this.title,
    required this.target,
    required this.current,
    required this.progress,
    required this.monthsAtBaseScenario,
  });

  final String title;
  final double target;
  final double current;
  final double progress;
  final int? monthsAtBaseScenario;
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
    required this.buckets,
    required this.suggestedMonthlyContribution,
    required this.powerHistory,
    required this.healthItems,
    required this.portfolioRiskScore,
    required this.marketSnapshot,
    required this.marketError,
    required this.marketLoading,
    required this.baseScenario,
    required this.conservativeScenario,
    required this.optimisticScenario,
    required this.goalItems,
    required this.grossAnnualReference,
    required this.netAnnualReference,
    required this.realAnnualReference,
    required this.taxDragAnnual,
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
  final List<FinanceInvestmentBucketData> buckets;
  final double suggestedMonthlyContribution;
  final List<FinanceInvestmentCapacityPoint> powerHistory;
  final List<FinanceInvestmentHealthItem> healthItems;
  final double portfolioRiskScore;
  final FinanceMarketSnapshot? marketSnapshot;
  final String? marketError;
  final bool marketLoading;
  final FinanceInvestmentProjectionScenario baseScenario;
  final FinanceInvestmentProjectionScenario conservativeScenario;
  final FinanceInvestmentProjectionScenario optimisticScenario;
  final List<FinanceInvestmentGoalProgress> goalItems;
  final double grossAnnualReference;
  final double netAnnualReference;
  final double realAnnualReference;
  final double taxDragAnnual;
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
