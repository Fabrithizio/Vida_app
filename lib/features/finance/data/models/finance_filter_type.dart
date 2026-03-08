enum FinanceFilterType { all, income, expense, debit, credit }

extension FinanceFilterTypeX on FinanceFilterType {
  String get label {
    switch (this) {
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
}
