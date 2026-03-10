import '../models/finance_category.dart';
import '../models/finance_entry_type.dart';
import '../models/finance_transaction.dart';
import '../models/finance_transaction_source.dart';

class FinanceSeedData {
  FinanceSeedData._();

  static final List<FinanceCategory> categories = [
    FinanceCategory(
      id: 'salary',
      name: 'Salário',
      iconKey: 'work',
      colorValue: 0xFF2E7D32,
      isIncomeCategory: true,
    ),
    FinanceCategory(
      id: 'food',
      name: 'Alimentação',
      iconKey: 'food',
      colorValue: 0xFFE65100,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'transport',
      name: 'Transporte',
      iconKey: 'transport',
      colorValue: 0xFF1565C0,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'health',
      name: 'Saúde',
      iconKey: 'health',
      colorValue: 0xFFC62828,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'shopping',
      name: 'Compras',
      iconKey: 'shopping',
      colorValue: 0xFF6A1B9A,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'leisure',
      name: 'Lazer',
      iconKey: 'leisure',
      colorValue: 0xFF00838F,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'home',
      name: 'Casa',
      iconKey: 'home',
      colorValue: 0xFF5D4037,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'education',
      name: 'Estudos',
      iconKey: 'education',
      colorValue: 0xFF283593,
      isIncomeCategory: false,
    ),
    FinanceCategory(
      id: 'other_income',
      name: 'Outras entradas',
      iconKey: 'income',
      colorValue: 0xFF1B5E20,
      isIncomeCategory: true,
    ),
    FinanceCategory(
      id: 'other_expense',
      name: 'Outras saídas',
      iconKey: 'expense',
      colorValue: 0xFF424242,
      isIncomeCategory: false,
    ),
  ];

  static FinanceCategory getCategoryById(String id) {
    return categories.firstWhere(
      (category) => category.id == id,
      orElse: () => categories.last,
    );
  }

  static List<FinanceTransaction> sampleTransactions() {
    final now = DateTime.now();

    return [
      FinanceTransaction(
        id: 'tx_1',
        title: 'Salário mensal',
        amount: 3500.00,
        date: DateTime(now.year, now.month, 5),
        category: getCategoryById('salary'),
        entryType: FinanceEntryType.transferIn,
        source: FinanceTransactionSource.manual,
        isIncome: true,
      ),
      FinanceTransaction(
        id: 'tx_2',
        title: 'Supermercado',
        amount: 285.40,
        date: DateTime(now.year, now.month, 7),
        category: getCategoryById('food'),
        entryType: FinanceEntryType.debit,
        source: FinanceTransactionSource.manual,
        isIncome: false,
      ),
      FinanceTransaction(
        id: 'tx_3',
        title: 'Farmácia',
        amount: 64.90,
        date: DateTime(now.year, now.month, 8),
        category: getCategoryById('health'),
        entryType: FinanceEntryType.credit,
        source: FinanceTransactionSource.manual,
        isIncome: false,
        note: 'Compra no cartão',
      ),
      FinanceTransaction(
        id: 'tx_4',
        title: 'Combustível',
        amount: 120.00,
        date: DateTime(now.year, now.month, 10),
        category: getCategoryById('transport'),
        entryType: FinanceEntryType.debit,
        source: FinanceTransactionSource.manual,
        isIncome: false,
      ),
      FinanceTransaction(
        id: 'tx_5',
        title: 'Camisa',
        amount: 89.90,
        date: DateTime(now.year, now.month, 12),
        category: getCategoryById('shopping'),
        entryType: FinanceEntryType.credit,
        source: FinanceTransactionSource.manual,
        isIncome: false,
        note: 'Compra parcelável',
      ),
      FinanceTransaction(
        id: 'tx_6',
        title: 'Freelance',
        amount: 450.00,
        date: DateTime(now.year, now.month, 14),
        category: getCategoryById('other_income'),
        entryType: FinanceEntryType.pixIn,
        source: FinanceTransactionSource.manual,
        isIncome: true,
      ),
      FinanceTransaction(
        id: 'tx_7',
        title: 'Cinema',
        amount: 52.00,
        date: DateTime(now.year, now.month, 15),
        category: getCategoryById('leisure'),
        entryType: FinanceEntryType.credit,
        source: FinanceTransactionSource.manual,
        isIncome: false,
      ),
      FinanceTransaction(
        id: 'tx_8',
        title: 'Conta de energia',
        amount: 140.75,
        date: DateTime(now.year, now.month, 18),
        category: getCategoryById('home'),
        entryType: FinanceEntryType.boleto,
        source: FinanceTransactionSource.manual,
        isIncome: false,
      ),
    ];
  }
}
