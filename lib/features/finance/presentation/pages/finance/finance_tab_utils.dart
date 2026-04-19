// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_tab_utils.dart
// ============================================================================

import 'dart:math' as math;

String parseMoneyField(String raw) {
  return raw
      .trim()
      .replaceAll('R\$', '')
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.');
}

double parseMoney(String raw) {
  return double.tryParse(parseMoneyField(raw)) ?? 0;
}

double parseDoubleValue(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

String moneyField(double value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}

String formatCurrency(double value, {required bool hideValues}) {
  if (hideValues) return 'R\$ •••••';

  final isNegative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts[0];
  final cents = parts[1];
  final buffer = StringBuffer();

  for (int i = 0; i < integer.length; i++) {
    final reverseIndex = integer.length - i;
    buffer.write(integer[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  final sign = isNegative ? '-' : '';
  return '${sign}R\$ ${buffer.toString()},$cents';
}

String formatCurrencyCompact(double value, {required bool hideValues}) {
  if (hideValues) return 'R\$ •••••';

  final absValue = value.abs();
  final sign = value < 0 ? '-' : '';

  if (absValue >= 1000000000) {
    final formatted = (absValue / 1000000000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return '${sign}R\$ ${formatted}B';
  }

  if (absValue >= 1000000) {
    final formatted = (absValue / 1000000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return '${sign}R\$ ${formatted}M';
  }

  if (absValue >= 1000) {
    final formatted = (absValue / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return '${sign}R\$ ${formatted}K';
  }

  return formatCurrency(value, hideValues: hideValues);
}

String formatShortDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

double projectFutureValue({
  required double current,
  required double monthlyContribution,
  required double annualPercent,
  required int months,
}) {
  if (months <= 0) return current;
  final monthlyRate = annualPercent <= 0
      ? 0.0
      : math.pow(1 + (annualPercent / 100), 1 / 12).toDouble() - 1;

  double total = current;
  for (int i = 0; i < months; i++) {
    total = (total + monthlyContribution) * (1 + monthlyRate);
  }
  return total;
}

double estimateFixedIncomeTaxRate(int months) {
  if (months <= 6) return 22.5;
  if (months <= 12) return 20.0;
  if (months <= 24) return 17.5;
  return 15.0;
}

double nominalToRealAnnual(double nominalAnnual, double inflationAnnual) {
  final nominalFactor = 1 + (nominalAnnual / 100);
  final inflationFactor = 1 + (inflationAnnual / 100);
  if (inflationFactor <= 0) return nominalAnnual;
  return ((nominalFactor / inflationFactor) - 1) * 100;
}
