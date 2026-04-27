// ============================================================================
// FILE: lib/features/finance/application/finance_areas_sync_bridge.dart
//
// O que faz:
// - Traduz os dados do Financeiro para o formato que o Areas entende
// - Salva snapshot consolidado de orçamento, dívidas, reserva e metas
// - Evita espalhar essa lógica dentro da UI da aba de Finanças
//
// Regras desta versão:
// - orçamento = total planejado do mês (exceto renda e sobra)
// - dívidas = peso do crédito/parcelas ainda em aberto a partir do mês atual
// - reserva = valor atual da gaveta "reserve"
// - metas = progresso ponderado das metas por gaveta; se não houver gavetas
//   com meta, usa a meta global de investimento
// - gasto do mês = saídas reais já registradas no FinanceStore
// ============================================================================

import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/finance/data/models/finance_entry_type.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction.dart';
import 'package:vida_app/features/finance/presentation/stores/finance_store.dart';

class FinanceAreasSyncBridge {
  FinanceAreasSyncBridge({AreasStore? areasStore})
    : _areasStore = areasStore ?? AreasStore.consolidated();

  final AreasStore _areasStore;

  Future<void> sync({
    required FinanceStore store,
    required double monthlyBudget,
    required double totalDebts,
    required double emergencyReserve,
    required double goalsProgress,
  }) async {
    await _areasStore.saveFinanceSnapshot(
      monthlyBudget: monthlyBudget,
      totalDebts: totalDebts,
      emergencyReserve: emergencyReserve,
      goalsProgress: goalsProgress,
      monthSpending: store.totalExpense,
    );
  }

  static double monthlyBudgetFromPlanningSummary(Map<String, double> summary) {
    return [
      summary['Essenciais'] ?? 0,
      summary['Investir + reserva'] ?? 0,
      summary['Livre'] ?? 0,
    ].fold<double>(0.0, (sum, item) => sum + item);
  }

  static double reserveFromBuckets(Map<String, double> bucketCurrent) {
    return (bucketCurrent['reserve'] ?? 0).clamp(0.0, double.infinity);
  }

  static double goalsProgressFromBuckets({
    required Map<String, double> bucketCurrent,
    required Map<String, double> bucketGoal,
    required double overallTarget,
  }) {
    double totalGoal = 0;
    double totalCurrent = 0;

    for (final entry in bucketGoal.entries) {
      final goal = entry.value;
      if (goal <= 0) continue;
      totalGoal += goal;
      totalCurrent += (bucketCurrent[entry.key] ?? 0);
    }

    if (totalGoal > 0) {
      return ((totalCurrent / totalGoal) * 100).clamp(0.0, 100.0);
    }

    if (overallTarget > 0) {
      final current = bucketCurrent.values.fold<double>(
        0.0,
        (sum, item) => sum + item,
      );
      return ((current / overallTarget) * 100).clamp(0.0, 100.0);
    }

    return 0;
  }

  static double totalOutstandingDebtFromTransactions(
    List<FinanceTransaction> transactions,
  ) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final rawCredit = transactions
        .where(
          (transaction) =>
              !transaction.isIncome &&
              transaction.entryType == FinanceEntryType.credit,
        )
        .toList();

    if (rawCredit.isEmpty) return 0;

    final groups = <String, List<FinanceTransaction>>{};
    final standalone = <FinanceTransaction>[];

    for (final transaction in rawCredit) {
      final groupId = transaction.installmentGroupId;
      if (groupId == null || groupId.trim().isEmpty) {
        standalone.add(transaction);
        continue;
      }
      groups
          .putIfAbsent(groupId, () => <FinanceTransaction>[])
          .add(transaction);
    }

    double total = 0;

    for (final transaction in standalone) {
      if (!_isBeforeMonth(transaction.date, monthStart)) {
        total += transaction.amount;
      }
    }

    for (final entry in groups.entries) {
      final items = [...entry.value]..sort((a, b) => a.date.compareTo(b.date));
      final base = items.first;

      if (items.length > 1) {
        for (final transaction in items) {
          if (!_isBeforeMonth(transaction.date, monthStart)) {
            total += transaction.amount;
          }
        }
        continue;
      }

      final installmentTotal = base.installmentTotal;
      if (installmentTotal <= 1) {
        if (!_isBeforeMonth(base.date, monthStart)) {
          total += base.amount;
        }
        continue;
      }

      final parts = _splitInstallments(base.amount, installmentTotal);
      for (var index = 0; index < installmentTotal; index++) {
        final installmentDate = _addMonthsKeepingDay(base.date, index);
        if (_isBeforeMonth(installmentDate, monthStart)) continue;
        total += parts[index];
      }
    }

    return total;
  }

  static bool _isBeforeMonth(DateTime date, DateTime monthStart) {
    return date.year < monthStart.year ||
        (date.year == monthStart.year && date.month < monthStart.month);
  }

  static List<double> _splitInstallments(double total, int count) {
    final cents = (total * 100).round();
    final base = cents ~/ count;
    final remainder = cents % count;

    return List.generate(count, (index) {
      final part = base + (index < remainder ? 1 : 0);
      return part / 100.0;
    });
  }

  static DateTime _addMonthsKeepingDay(DateTime base, int monthOffset) {
    final targetMonth = DateTime(base.year, base.month + monthOffset, 1);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final safeDay = base.day < 1
        ? 1
        : (base.day > lastDay ? lastDay : base.day);
    return DateTime(targetMonth.year, targetMonth.month, safeDay);
  }
}
