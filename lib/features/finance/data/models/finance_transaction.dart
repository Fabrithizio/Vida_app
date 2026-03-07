import 'finance_category.dart';
import 'finance_entry_type.dart';
import 'finance_transaction_source.dart';

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.entryType,
    required this.source,
    required this.isIncome,
    this.note,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final FinanceCategory category;
  final FinanceEntryType entryType;
  final FinanceTransactionSource source;
  final bool isIncome;
  final String? note;

  FinanceTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    FinanceCategory? category,
    FinanceEntryType? entryType,
    FinanceTransactionSource? source,
    bool? isIncome,
    String? note,
    bool clearNote = false,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      entryType: entryType ?? this.entryType,
      source: source ?? this.source,
      isIncome: isIncome ?? this.isIncome,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
