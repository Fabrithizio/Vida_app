import 'package:flutter/foundation.dart';

import '../../data/local/finance_seed_data.dart';
import '../../data/models/finance_category.dart';
import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_filter_type.dart';
import '../../data/models/finance_transaction.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/hive_finance_repository.dart';

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

  List<FinanceCategory> get categories => List.unmodifiable(_categories);
  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isEmpty => _transactions.isEmpty;

  FinanceFilterType get selectedFilter => _selectedFilter;

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

  double get totalIncome {
    return _transactions
        .where((transaction) => transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double get totalExpense {
    return _transactions
        .where((transaction) => !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double get balance => totalIncome - totalExpense;

  double get totalCreditExpense {
    return _transactions
        .where(
          (transaction) =>
              !transaction.isIncome &&
              transaction.entryType == FinanceEntryType.credit,
        )
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double get totalDebitExpense {
    return _transactions
        .where(
          (transaction) =>
              !transaction.isIncome &&
              _isImmediateOutflow(transaction.entryType),
        )
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  int get transactionCount => _transactions.length;

  List<FinanceTransaction> get recentTransactions {
    final items = List<FinanceTransaction>.from(_transactions);
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  List<FinanceTransaction> get expenseTransactions {
    return _transactions.where((transaction) => !transaction.isIncome).toList();
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

  String get quickInsight {
    if (_transactions.isEmpty) {
      return 'Adicione sua primeira transação para começar.';
    }

    if (totalExpense == 0 && totalIncome > 0) {
      return 'Você registrou entradas, mas ainda não registrou saídas.';
    }

    if (totalIncome == 0 && totalExpense > 0) {
      return 'Você registrou saídas, mas ainda não registrou entradas.';
    }

    if (totalCreditExpense > totalDebitExpense) {
      return 'Seus gastos no crédito estão maiores que no débito.';
    }

    if (totalDebitExpense > totalCreditExpense) {
      return 'Seus gastos no débito estão maiores que no crédito.';
    }

    return 'Seus gastos no crédito e no débito estão equilibrados.';
  }

  void setFilter(FinanceFilterType filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
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
