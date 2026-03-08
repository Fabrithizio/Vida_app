enum FinancePeriodType { currentMonth, previousMonth, currentYear, allTime }

extension FinancePeriodTypeX on FinancePeriodType {
  String get label {
    switch (this) {
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
}
