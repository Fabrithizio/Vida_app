// ============================================================================
// FILE: lib/features/finance/presentation/stores/finance_store.dart
//
// Store principal do módulo de finanças.
//
// O que este arquivo faz:
// - Carrega, salva e atualiza transações.
// - Aplica filtros por período e por tipo.
// - Calcula entradas, saídas reais, crédito e saldo.
// - Gera dados para ranking e gráfico de categorias.
// - Mantém histórico consolidado para compras parceladas e projeta as parcelas
//   mês a mês apenas para a visão de crédito.
//
// Ajuste desta versão:
// - Compra no crédito não contamina mais “Saídas”.
// - Saída real agora considera só dinheiro que já saiu da conta.
// - Compras parceladas no crédito ficam salvas uma vez no histórico, mas a
//   fatura mensal continua distribuída pelos meses seguintes.
// ============================================================================

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
  final List<FinanceCategory> _categories = List.from(
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

  List<FinanceTransaction> get periodTransactions =>
      _transactionsForPeriod(_selectedPeriod);

  List<FinanceTransaction> get previousPeriodTransactions {
    if (_selectedPeriod == FinancePeriodType.allTime) return [];

    final now = DateTime.now();
    switch (_selectedPeriod) {
      case FinancePeriodType.currentMonth:
        return _transactionsForPeriod(FinancePeriodType.previousMonth);
      case FinancePeriodType.previousMonth:
        final target = DateTime(now.year, now.month - 2, 1);
        return _transactions
            .where(
              (transaction) =>
                  transaction.date.year == target.year &&
                  transaction.date.month == target.month,
            )
            .toList();
      case FinancePeriodType.currentYear:
        final previousYear = now.year - 1;
        return _transactions
            .where((transaction) => transaction.date.year == previousYear)
            .toList();
      case FinancePeriodType.allTime:
        return [];
    }
  }

  bool _matchesPeriod(DateTime date, FinancePeriodType period, DateTime now) {
    switch (period) {
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
  }

  List<FinanceTransaction> _transactionsForPeriod(FinancePeriodType period) {
    final now = DateTime.now();
    return _transactions
        .where((transaction) => _matchesPeriod(transaction.date, period, now))
        .toList();
  }

  List<double> _splitInstallments(double total, int count) {
    final cents = (total * 100).round();
    final base = cents ~/ count;
    final remainder = cents % count;

    return List.generate(count, (index) {
      final part = base + (index < remainder ? 1 : 0);
      return part / 100.0;
    });
  }

  DateTime _addMonthsKeepingDay(DateTime base, int monthOffset) {
    final targetMonth = DateTime(base.year, base.month + monthOffset, 1);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final safeDay = base.day < 1
        ? 1
        : (base.day > lastDay ? lastDay : base.day);
    return DateTime(targetMonth.year, targetMonth.month, safeDay);
  }

  List<FinanceTransaction> _expandCreditTransactionsForPeriod(
    FinancePeriodType period,
  ) {
    final rawCredit = _transactions
        .where(
          (transaction) =>
              !transaction.isIncome &&
              transaction.entryType == FinanceEntryType.credit,
        )
        .toList();

    if (rawCredit.isEmpty) return const [];

    final groups = <String, List<FinanceTransaction>>{};
    final standalone = <FinanceTransaction>[];

    for (final transaction in rawCredit) {
      final groupId = transaction.installmentGroupId;
      if (groupId == null || groupId.isEmpty) {
        standalone.add(transaction);
        continue;
      }
      groups.putIfAbsent(groupId, () => []).add(transaction);
    }

    final projected = <FinanceTransaction>[];
    final now = DateTime.now();

    for (final transaction in standalone) {
      if (_matchesPeriod(transaction.date, period, now)) {
        projected.add(transaction);
      }
    }

    for (final entry in groups.entries) {
      final items = entry.value..sort((a, b) => a.date.compareTo(b.date));
      final base = items.first;

      // Compatibilidade com lançamentos antigos, já salvos uma parcela por mês.
      if (items.length > 1) {
        for (final transaction in items) {
          if (_matchesPeriod(transaction.date, period, now)) {
            projected.add(transaction);
          }
        }
        continue;
      }

      final installmentTotal = base.installmentTotal;
      if (installmentTotal <= 1) {
        if (_matchesPeriod(base.date, period, now)) {
          projected.add(base);
        }
        continue;
      }

      final amounts = _splitInstallments(base.amount, installmentTotal);
      for (var index = 0; index < installmentTotal; index++) {
        final installmentDate = _addMonthsKeepingDay(base.date, index);
        if (!_matchesPeriod(installmentDate, period, now)) continue;

        projected.add(
          FinanceTransaction(
            id: '${base.id}__credit_${index + 1}',
            title: base.title,
            amount: amounts[index],
            date: installmentDate,
            category: base.category,
            entryType: base.entryType,
            source: base.source,
            isIncome: false,
            note: base.note,
            subcategory: base.subcategory,
            tag: base.tag,
            isRecurring: false,
            recurringDayOfMonth: null,
            installmentGroupId: base.installmentGroupId,
            installmentIndex: index + 1,
            installmentTotal: installmentTotal,
          ),
        );
      }
    }

    projected.sort((a, b) => b.date.compareTo(a.date));
    return projected;
  }

  double _sumIncome(List<FinanceTransaction> items) {
    return items
        .where((transaction) => transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double _sumExpense(List<FinanceTransaction> items) {
    return items
        .where(
          (transaction) =>
              !transaction.isIncome &&
              _isImmediateOutflow(transaction.entryType),
        )
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

  /// Saídas reais: só dinheiro que já saiu da conta.
  double get totalExpense => _sumExpense(periodTransactions);

  /// Saldo disponível: só cai com saídas imediatas.
  /// Compra no crédito entra como compromisso/fatura, não como dinheiro já saído.
  double get balance => totalIncome - totalDebitExpense;

  double get totalCreditExpense => _sumCreditExpense(creditTransactions);
  double get totalDebitExpense => _sumDebitExpense(periodTransactions);
  double get previousPeriodIncome => _sumIncome(previousPeriodTransactions);
  double get previousPeriodExpense => _sumExpense(previousPeriodTransactions);
  double get previousPeriodBalance =>
      previousPeriodIncome - _sumDebitExpense(previousPeriodTransactions);
  int get transactionCount => periodTransactions.length;

  List<FinanceTransaction> get recentTransactions {
    final items = List<FinanceTransaction>.from(periodTransactions);
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  /// Apenas saídas imediatas. Crédito fica fora daqui.
  List<FinanceTransaction> get expenseTransactions {
    return periodTransactions
        .where(
          (transaction) =>
              !transaction.isIncome &&
              _isImmediateOutflow(transaction.entryType),
        )
        .toList();
  }

  /// Crédito do período atual, já projetado mês a mês quando a compra foi
  /// salva como uma única compra parcelada no histórico.
  List<FinanceTransaction> get creditTransactions =>
      _expandCreditTransactionsForPeriod(_selectedPeriod);

  List<FinanceTransaction> get filteredTransactions {
    final items = recentTransactions;
    switch (_selectedFilter) {
      case FinanceFilterType.all:
        return items;
      case FinanceFilterType.income:
        return items.where((transaction) => transaction.isIncome).toList();
      case FinanceFilterType.expense:
        return items
            .where(
              (transaction) =>
                  !transaction.isIncome &&
                  _isImmediateOutflow(transaction.entryType),
            )
            .toList();
      case FinanceFilterType.debit:
        return items
            .where(
              (transaction) =>
                  !transaction.isIncome &&
                  _isImmediateOutflow(transaction.entryType),
            )
            .toList();
      case FinanceFilterType.credit:
        return creditTransactions;
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
    if (expenseTransactions.isEmpty) return const [];

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
    if (periodTransactions.isEmpty && creditTransactions.isEmpty) {
      return 'Nenhuma movimentação encontrada no período selecionado.';
    }
    if (totalExpense == 0 && totalIncome > 0 && totalCreditExpense == 0) {
      return 'Neste período você registrou entradas, mas nenhuma saída.';
    }
    if (totalIncome == 0 && totalExpense > 0) {
      return 'Neste período você registrou saídas, mas nenhuma entrada.';
    }
    if (totalCreditExpense > totalDebitExpense) {
      return 'Neste período suas compras no crédito estão maiores que as saídas imediatas.';
    }
    if (totalDebitExpense > totalCreditExpense) {
      return 'Neste período suas saídas imediatas estão maiores que as compras no crédito.';
    }
    return 'Neste período suas saídas imediatas e compras no crédito estão equilibradas.';
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
      return 'Você teve mais saídas reais do que no período anterior.';
    }
    if (currentExpense < previousExpense) {
      return 'Você teve menos saídas reais do que no período anterior.';
    }
    return 'Suas saídas reais ficaram iguais ao período anterior.';
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
