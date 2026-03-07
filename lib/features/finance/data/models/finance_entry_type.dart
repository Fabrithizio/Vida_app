enum FinanceEntryType {
  debit,
  credit,
  pixIn,
  pixOut,
  transferIn,
  transferOut,
  cash,
  boleto,
  other,
}

extension FinanceEntryTypeX on FinanceEntryType {
  String get label {
    switch (this) {
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
