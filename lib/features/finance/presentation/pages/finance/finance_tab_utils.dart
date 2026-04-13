// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_tab_utils.dart
//
// Utilitários visuais e de formatação da tela de Finanças.
//
// O que este arquivo faz:
// - Formata moeda e data.
// - Faz parse seguro de campos de texto numéricos.
// - Centraliza helpers pequenos que antes poluíam o arquivo principal.
// ============================================================================

String parseMoneyField(String raw) {
  final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
  return normalized;
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

  final fixed = value.toStringAsFixed(2);
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

  return 'R\$ ${buffer.toString()},$cents';
}

String formatShortDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
