import '../models/finance_transaction.dart';

abstract class FinanceRepository {
  Future<List<FinanceTransaction>> loadAll();
  Future<void> saveAll(List<FinanceTransaction> items);
}
