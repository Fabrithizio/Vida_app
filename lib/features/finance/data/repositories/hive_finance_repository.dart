import 'package:hive_flutter/hive_flutter.dart';

import '../models/finance_category.dart';
import '../models/finance_entry_type.dart';
import '../models/finance_transaction.dart';
import '../models/finance_transaction_source.dart';
import 'finance_repository.dart';

class HiveFinanceRepository implements FinanceRepository {
  static const String _boxName = 'finance_box';
  static const String _key = 'transactions';

  Future<Box<dynamic>> _open() async {
    return Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<List<FinanceTransaction>> loadAll() async {
    final box = await _open();
    final raw = box.get(_key);

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => _fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<void> saveAll(List<FinanceTransaction> items) async {
    final box = await _open();
    final raw = items.map(_toMap).toList();
    await box.put(_key, raw);
  }

  Map<String, dynamic> _toMap(FinanceTransaction transaction) {
    return <String, dynamic>{
      'id': transaction.id,
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'category': <String, dynamic>{
        'id': transaction.category.id,
        'name': transaction.category.name,
        'iconKey': transaction.category.iconKey,
        'colorValue': transaction.category.colorValue,
        'isIncomeCategory': transaction.category.isIncomeCategory,
      },
      'entryType': transaction.entryType.name,
      'source': transaction.source.name,
      'isIncome': transaction.isIncome,
      'note': transaction.note,
    };
  }

  FinanceTransaction _fromMap(Map<String, dynamic> map) {
    final categoryMap = Map<String, dynamic>.from(map['category'] as Map);

    final category = FinanceCategory(
      id: categoryMap['id'] as String,
      name: categoryMap['name'] as String,
      iconKey: (categoryMap['iconKey'] as String?) ?? 'expense',
      colorValue: categoryMap['colorValue'] as int,
      isIncomeCategory: categoryMap['isIncomeCategory'] as bool,
    );

    return FinanceTransaction(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: category,
      entryType: FinanceEntryType.values.byName(map['entryType'] as String),
      source: FinanceTransactionSource.values.byName(map['source'] as String),
      isIncome: map['isIncome'] as bool,
      note: map['note'] as String?,
    );
  }
}
