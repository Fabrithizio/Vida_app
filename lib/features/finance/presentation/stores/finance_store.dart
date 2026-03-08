import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/local/finance_seed_data.dart';
import '../../data/models/finance_category.dart';
import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_filter_type.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/hive_finance_repository.dart';
import '../widgets/expense_category_chart.dart';

class FinanceStore extends ChangeNotifier {
  FinanceStore({FinanceRepository? repository})
    : _repository = repository ?? HiveFinanceRepository();

  final FinanceRepository _repository;

  final List<FinanceCategory> _categories = List<FinanceCategory>.from(
    FinanceSeedData.categories,
  );

  final List<FinanceTransaction> _transactions = [];

  bool _isLoading = false;
  bool _hasLoaded = false;
  FinanceFilterType _selectedFilter = FinanceFilterType.all;
  FinancePeriodType _selectedPeriod = FinancePeriodType.currentMonth;

  List<FinanceCategory> get categories => List.unmodifiable(_categories);
  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isEmpty => _transactions.isEmpty;

  FinanceFilterType get selectedFilter => _selectedFilter;
  FinancePeriodType get selectedPeriod => _selectedPeriod;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    final savedItems = await _repository.loadAll();

    _transactions
      ..clear()
      ..addAll(savedItems);

    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  List<FinanceTransaction> get periodTransactions {
    final now = DateTime.now();

    return _transactions.where((transaction) {
      final date = transaction.date;

      switch (_selectedPeriod) {
        case FinancePeriodType.currentMonth:
          return date.year == now.year && date.month == now.month;

        case FinancePeriodType.previousMonth:
          final previousMonthDate = DateTime(now.year, now.month - 1, 1);
          return date.year == previousMonthDate.year &&
              date.month == previousMonthDate.month;

        case FinancePeriodType.currentYear:
          return date.year == now.year;

        case FinancePeriodType.allTime:
          return true;
      }
    }).toList();
  }

  List<FinanceTransaction> get previousPeriodTransactions {
    if (_selectedPeriod == FinancePeriodType.allTime) {
      return <FinanceTransaction>[];
    }

    final now = DateTime.now();

    return _transactions.where((transaction) {
      final date = transaction.date;

      switch (_selectedPeriod) {
        case FinancePeriodType.currentMonth:
          final previousMonthDate = DateTime(now.year, now.month - 1, 1);
          return date.year == previousMonthDate.year &&
              date.month == previousMonthDate.month;

        case FinancePeriodType.previousMonth:
          final twoMonthsAgoDate = DateTime(now.year, now.month - 2, 1);
          return date.year == twoMonthsAgoDate.year &&
              date.month == twoMonthsAgoDate.month;

        case FinancePeriodType.currentYear:
          return date.year == now.year - 1;

        case FinancePeriodType.allTime:
          return false;
      }
    }).toList();
  }

  double _sumIncome(List<FinanceTransaction> items) {
    return items
        .where((transaction) => transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double _sumExpense(List<FinanceTransaction> items) {
    return items
        .where((transaction) => !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double _sumCreditExpense(List<FinanceTransaction> items) {
    return items
        .where(
          (transaction) =>
              !transaction.isIncome &&
              transaction.entryType == FinanceEntryType.credit,
        )
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double _sumDebitExpense(List<FinanceTransaction> items) {
    return items
        .where(
          (transaction) =>
              !transaction.isIncome &&
              _isImmediateOutflow(transaction.entryType),
        )
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double get totalIncome => _sumIncome(periodTransactions);
  double get totalExpense => _sumExpense(periodTransactions);
  double get balance => totalIncome - totalExpense;
  double get totalCreditExpense => _sumCreditExpense(periodTransactions);
  double get totalDebitExpense => _sumDebitExpense(periodTransactions);

  double get previousPeriodIncome => _sumIncome(previousPeriodTransactions);
  double get previousPeriodExpense => _sumExpense(previousPeriodTransactions);
  double get previousPeriodBalance =>
      previousPeriodIncome - previousPeriodExpense;

  int get transactionCount => periodTransactions.length;

  List<FinanceTransaction> get recentTransactions {
    final items = List<FinanceTransaction>.from(periodTransactions);
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  List<FinanceTransaction> get expenseTransactions {
    return periodTransactions
        .where((transaction) => !transaction.isIncome)
        .toList();
  }

  List<FinanceTransaction> get filteredTransactions {
    final items = recentTransactions;

    switch (_selectedFilter) {
      case FinanceFilterType.all:
        return items;
      case FinanceFilterType.income:
        return items.where((transaction) => transaction.isIncome).toList();
      case FinanceFilterType.expense:
        return items.where((transaction) => !transaction.isIncome).toList();
      case FinanceFilterType.debit:
        return items
            .where(
              (transaction) =>
                  !transaction.isIncome &&
                  _isImmediateOutflow(transaction.entryType),
            )
            .toList();
      case FinanceFilterType.credit:
        return items
            .where(
              (transaction) =>
                  !transaction.isIncome &&
                  transaction.entryType == FinanceEntryType.credit,
            )
            .toList();
    }
  }

  int get filteredTransactionCount => filteredTransactions.length;

  FinanceCategory? get topExpenseCategory {
    if (expenseTransactions.isEmpty) return null;

    final totalsByCategory = <String, double>{};
    final categoriesById = <String, FinanceCategory>{};

    for (final transaction in expenseTransactions) {
      final categoryId = transaction.category.id;
      totalsByCategory[categoryId] =
          (totalsByCategory[categoryId] ?? 0) + transaction.amount;
      categoriesById[categoryId] = transaction.category;
    }

    String? winnerId;
    double winnerTotal = 0;

    totalsByCategory.forEach((categoryId, total) {
      if (total > winnerTotal) {
        winnerId = categoryId;
        winnerTotal = total;
      }
    });

    if (winnerId == null) return null;
    return categoriesById[winnerId];
  }

  double get topExpenseCategoryAmount {
    final topCategory = topExpenseCategory;
    if (topCategory == null) return 0;

    return expenseTransactions
        .where((transaction) => transaction.category.id == topCategory.id)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  List<ExpenseCategoryChartItem> get categoryChartItems {
    if (expenseTransactions.isEmpty) {
      return const <ExpenseCategoryChartItem>[];
    }

    final totalsByCategory = <String, double>{};
    final categoryMeta = <String, FinanceCategory>{};

    for (final transaction in expenseTransactions) {
      final category = transaction.category;
      totalsByCategory[category.id] =
          (totalsByCategory[category.id] ?? 0) + transaction.amount;
      categoryMeta[category.id] = category;
    }

    final items = totalsByCategory.entries.map((entry) {
      final category = categoryMeta[entry.key]!;

      return ExpenseCategoryChartItem(
        label: category.name,
        amount: entry.value,
        color: category.color,
        icon: category.icon,
      );
    }).toList();

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  String get quickInsight {
    if (periodTransactions.isEmpty) {
      return 'Nenhuma movimentação encontrada no período selecionado.';
    }

    if (totalExpense == 0 && totalIncome > 0) {
      return 'Neste período você registrou entradas, mas nenhuma saída.';
    }

    if (totalIncome == 0 && totalExpense > 0) {
      return 'Neste período você registrou saídas, mas nenhuma entrada.';
    }

    if (totalCreditExpense > totalDebitExpense) {
      return 'Neste período seus gastos no crédito estão maiores que no débito.';
    }

    if (totalDebitExpense > totalCreditExpense) {
      return 'Neste período seus gastos no débito estão maiores que no crédito.';
    }

    return 'Neste período seus gastos no crédito e no débito estão equilibrados.';
  }

  String get periodComparisonText {
    if (_selectedPeriod == FinancePeriodType.allTime) {
      return 'Comparação não disponível para o período "Tudo".';
    }

    if (previousPeriodTransactions.isEmpty) {
      return 'Não há dados do período anterior para comparar.';
    }

    final currentExpense = totalExpense;
    final previousExpense = previousPeriodExpense;

    if (currentExpense > previousExpense) {
      return 'Você gastou mais do que no período anterior.';
    }

    if (currentExpense < previousExpense) {
      return 'Você gastou menos do que no período anterior.';
    }

    return 'Seus gastos ficaram iguais ao período anterior.';
  }

  void setFilter(FinanceFilterType filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  void setPeriod(FinancePeriodType period) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    notifyListeners();
  }

  bool _isImmediateOutflow(FinanceEntryType entryType) {
    switch (entryType) {
      case FinanceEntryType.debit:
      case FinanceEntryType.pixOut:
      case FinanceEntryType.transferOut:
      case FinanceEntryType.cash:
      case FinanceEntryType.boleto:
        return true;
      case FinanceEntryType.credit:
      case FinanceEntryType.pixIn:
      case FinanceEntryType.transferIn:
      case FinanceEntryType.other:
        return false;
    }
  }

  Future<void> addTransaction(FinanceTransaction transaction) async {
    _transactions.add(transaction);
    await _repository.saveAll(_transactions);
    notifyListeners();
  }

  Future<void> updateTransaction(FinanceTransaction updatedTransaction) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction.id == updatedTransaction.id,
    );

    if (index == -1) return;

    _transactions[index] = updatedTransaction;
    await _repository.saveAll(_transactions);
    notifyListeners();
  }

  Future<void> removeTransaction(String id) async {
    _transactions.removeWhere((transaction) => transaction.id == id);
    await _repository.saveAll(_transactions);
    notifyListeners();
  }
}
