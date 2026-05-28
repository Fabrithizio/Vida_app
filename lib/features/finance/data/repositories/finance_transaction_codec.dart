import '../models/finance_category.dart';
import '../models/finance_entry_type.dart';
import '../models/finance_transaction.dart';
import '../models/finance_transaction_source.dart';

class FinanceTransactionCodec {
  const FinanceTransactionCodec();

  Map<String, dynamic> toMap(FinanceTransaction transaction) {
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
      'accountName': transaction.accountName,
      'cardName': transaction.cardName,
      'isRecurring': transaction.isRecurring,
      'recurringDayOfMonth': transaction.recurringDayOfMonth,
      'installmentGroupId': transaction.installmentGroupId,
      'installmentIndex': transaction.installmentIndex,
      'installmentTotal': transaction.installmentTotal,
    };
  }

  FinanceTransaction fromMap(Map<String, dynamic> map) {
    final categoryMap = Map<String, dynamic>.from(
      (map['category'] as Map?) ?? const <String, dynamic>{},
    );

    final category = FinanceCategory(
      id: (categoryMap['id'] as String?) ?? 'other_expense',
      name: _fixText((categoryMap['name'] as String?) ?? 'Outras saídas'),
      iconKey: (categoryMap['iconKey'] as String?) ?? 'expense',
      colorValue: (categoryMap['colorValue'] as int?) ?? 0xFF424242,
      isIncomeCategory: (categoryMap['isIncomeCategory'] as bool?) ?? false,
    );

    return FinanceTransaction(
      id:
          (map['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _fixText((map['title'] as String?) ?? 'Lançamento'),
      amount: ((map['amount'] as num?) ?? 0).toDouble(),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      category: category,
      entryType: _parseEntryType(map['entryType'] as String?),
      source: _parseSource(map['source'] as String?),
      isIncome: (map['isIncome'] as bool?) ?? false,
      note: _nullableFixedText(map['note']),
      subcategory: _nullableFixedText(map['subcategory']),
      tag: _nullableFixedText(map['tag']),
      accountName: _nullableFixedText(map['accountName']),
      cardName: _nullableFixedText(map['cardName']),
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

  String? _nullableFixedText(dynamic value) {
    if (value is! String) return null;
    final fixed = _fixText(value).trim();
    return fixed.isEmpty ? null : fixed;
  }

  String _fixText(String value) {
    return value
        .replaceAll('VisÃ£o', 'Visão')
        .replaceAll('mÃªs', 'mês')
        .replaceAll('MÃªs', 'Mês')
        .replaceAll('DÃ©bito', 'Débito')
        .replaceAll('CrÃ©dito', 'Crédito')
        .replaceAll('LanÃ§amento', 'Lançamento')
        .replaceAll('LanÃ§ado', 'Lançado')
        .replaceAll('saÃ­das', 'saídas')
        .replaceAll('SaÃ­das', 'Saídas')
        .replaceAll('CombustÃ­vel', 'Combustível')
        .replaceAll('TransferÃªncia', 'Transferência');
  }
}
