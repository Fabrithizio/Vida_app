// ============================================================================
// FILE: lib/shared/utils/currency_formatter.dart
//
// Utilitário global de formatação e leitura de valores monetários.
//
// Caminho no projeto:
// - lib/shared/utils/currency_formatter.dart
//
// Como se conecta com o app:
// - Pode ser importado por qualquer tela, serviço ou feature que precise lidar
//   com dinheiro.
// - Centraliza a regra de moeda para Finanças, Voz e futuras áreas do app.
// - Mantém o padrão brasileiro: R$ 1.000.000,00.
// ============================================================================

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
