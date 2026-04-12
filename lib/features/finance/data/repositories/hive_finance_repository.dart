// ============================================================================
// FILE: lib/features/finance/data/repositories/hive_finance_repository.dart
//
// Repositório Hive do módulo financeiro.
//
// O que este arquivo faz:
// - Salva e lê todas as transações do usuário.
// - Mantém compatibilidade com a estrutura anterior.
// - Persiste os novos campos do Financeiro 2.0:
//   subcategoria, tag, recorrência e parcelamento.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/finance_category.dart';
import '../models/finance_entry_type.dart';
import '../models/finance_transaction.dart';
import '../models/finance_transaction_source.dart';
import 'finance_repository.dart';

class HiveFinanceRepository implements FinanceRepository {
  static const String _boxPrefix = 'finance_box_';
  static const String _key = 'transactions';

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> _open() async {
    return Hive.openBox<dynamic>('$_boxPrefix${_uidOrAnon()}');
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
    final payload = items.map(_toMap).toList();
    await box.put(_key, payload);
  }

  Map<String, dynamic> _toMap(FinanceTransaction transaction) {
    return {
      'id': transaction.id,
      'title': transaction.title,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'category': {
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
      'subcategory': transaction.subcategory,
      'tag': transaction.tag,
      'isRecurring': transaction.isRecurring,
      'recurringDayOfMonth': transaction.recurringDayOfMonth,
      'installmentGroupId': transaction.installmentGroupId,
      'installmentIndex': transaction.installmentIndex,
      'installmentTotal': transaction.installmentTotal,
    };
  }

  FinanceTransaction _fromMap(Map<String, dynamic> map) {
    final categoryMap = Map<String, dynamic>.from(
      (map['category'] as Map?) ?? const <String, dynamic>{},
    );

    final category = FinanceCategory(
      id: (categoryMap['id'] as String?) ?? 'other_expense',
      name: (categoryMap['name'] as String?) ?? 'Outras saídas',
      iconKey: (categoryMap['iconKey'] as String?) ?? 'expense',
      colorValue: (categoryMap['colorValue'] as int?) ?? 0xFF424242,
      isIncomeCategory: (categoryMap['isIncomeCategory'] as bool?) ?? false,
    );

    final rawEntryType = map['entryType'] as String?;
    final rawSource = map['source'] as String?;

    return FinanceTransaction(
      id:
          (map['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: (map['title'] as String?) ?? 'Lançamento',
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      category: category,
      entryType: _parseEntryType(rawEntryType),
      source: _parseSource(rawSource),
      isIncome: (map['isIncome'] as bool?) ?? false,
      note: map['note'] as String?,
      subcategory: map['subcategory'] as String?,
      tag: map['tag'] as String?,
      isRecurring: (map['isRecurring'] as bool?) ?? false,
      recurringDayOfMonth: _asNullableInt(map['recurringDayOfMonth']),
      installmentGroupId: map['installmentGroupId'] as String?,
      installmentIndex: _asNullableInt(map['installmentIndex']) ?? 1,
      installmentTotal: _asNullableInt(map['installmentTotal']) ?? 1,
    );
  }

  FinanceEntryType _parseEntryType(String? raw) {
    if (raw == null || raw.isEmpty) return FinanceEntryType.other;
    try {
      return FinanceEntryType.values.byName(raw);
    } catch (_) {
      return FinanceEntryType.other;
    }
  }

  FinanceTransactionSource _parseSource(String? raw) {
    if (raw == null || raw.isEmpty) return FinanceTransactionSource.manual;
    try {
      return FinanceTransactionSource.values.byName(raw);
    } catch (_) {
      return FinanceTransactionSource.manual;
    }
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
