enum FinanceTransactionSource { manual, imported, bankSync }

extension FinanceTransactionSourceX on FinanceTransactionSource {
  String get label {
    switch (this) {
      case FinanceTransactionSource.manual:
        return 'Manual';
      case FinanceTransactionSource.imported:
        return 'Importado';
      case FinanceTransactionSource.bankSync:
        return 'Sincronizado com banco';
    }
  }
}
