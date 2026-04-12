// ============================================================================
// FILE: lib/features/voice/application/finance_voice_intents.dart
//
// Camada nova para voz do financeiro.
//
// O que este arquivo faz:
// - Interpreta comandos financeiros em linguagem natural.
// - Gera rascunhos de lançamentos sem gravar direto.
// - Suporta gasto, entrada, parcelamento e recorrência mensal.
// - Foi pensado para ser plugado no VoiceCommandRouter atual.
// ============================================================================

import 'package:vida_app/features/finance/data/models/finance_category.dart';
import 'package:vida_app/features/finance/data/models/finance_entry_type.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction.dart';
import 'package:vida_app/features/finance/data/models/finance_transaction_source.dart';
import 'package:vida_app/features/finance/presentation/stores/finance_store.dart';

class FinanceVoiceDraft {
  const FinanceVoiceDraft({required this.transactions, required this.summary});

  final List<FinanceTransaction> transactions;
  final String summary;
}

class FinanceVoiceIntents {
  const FinanceVoiceIntents();

  Future<FinanceVoiceDraft?> tryBuild({
    required String original,
    required String normalized,
    required FinanceStore store,
  }) async {
    if (!_looksLikeFinance(normalized)) return null;

    final amount = _extractAmount(original);
    if (amount == null || amount <= 0) return null;

    final isIncome = _looksLikeIncome(normalized);
    final entryType = _entryTypeFromText(normalized, isIncome: isIncome);
    final category = _categoryFromText(
      normalized,
      store: store,
      isIncome: isIncome,
    );
    final date = _extractDate(normalized) ?? DateTime.now();
    final title = _buildTitle(
      normalized,
      fallbackCategory: category.name,
      isIncome: isIncome,
    );
    final tag = _extractTag(normalized);
    final recurringDay = _extractRecurringDay(normalized);
    final installments = _extractInstallments(normalized);

    if (!isIncome && entryType == FinanceEntryType.credit && installments > 1) {
      final groupId = 'voice_inst_${DateTime.now().microsecondsSinceEpoch}';
      final split = _splitInstallments(amount, installments);
      final transactions = <FinanceTransaction>[];

      for (var i = 0; i < installments; i++) {
        final dueDate = _addMonthsKeepingDay(date, i);
        transactions.add(
          FinanceTransaction(
            id: '${groupId}_${i + 1}',
            title: title,
            amount: split[i],
            date: dueDate,
            category: category,
            entryType: entryType,
            source: FinanceTransactionSource.manual,
            isIncome: false,
            tag: tag,
            installmentGroupId: groupId,
            installmentIndex: i + 1,
            installmentTotal: installments,
            note: 'Lançado por voz: $original',
          ),
        );
      }

      return FinanceVoiceDraft(
        transactions: transactions,
        summary:
            'compra parcelada "$title" em $installments x de ${_money(split.first)} na categoria ${category.name}',
      );
    }

    final transaction = FinanceTransaction(
      id: 'tx_voice_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      amount: amount,
      date: date,
      category: category,
      entryType: entryType,
      source: FinanceTransactionSource.manual,
      isIncome: isIncome,
      tag: tag,
      isRecurring: recurringDay != null,
      recurringDayOfMonth: recurringDay,
      note: 'Lançado por voz: $original',
    );

    final recurringText = recurringDay == null
        ? ''
        : ' recorrente todo dia $recurringDay';
    return FinanceVoiceDraft(
      transactions: [transaction],
      summary:
          '${isIncome ? 'entrada' : 'gasto'} "$title" de ${_money(amount)} em ${category.name}$recurringText',
    );
  }

  bool _looksLikeFinance(String text) {
    return text.contains('gastei') ||
        text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('salario') ||
        text.contains('salário') ||
        text.contains('comprei') ||
        text.contains('paguei') ||
        text.contains('pix') ||
        text.contains('credito') ||
        text.contains('crédito') ||
        text.contains('debito') ||
        text.contains('débito') ||
        text.contains('boleto') ||
        text.contains('reais') ||
        text.contains('real');
  }

  bool _looksLikeIncome(String text) {
    return text.contains('recebi') ||
        text.contains('ganhei') ||
        text.contains('salario') ||
        text.contains('salário') ||
        text.contains('pagamento') ||
        text.contains('entrada') ||
        text.contains('caiu');
  }

  double? _extractAmount(String text) {
    final source = text.toLowerCase();
    final moneyContext = RegExp(
      r'(?:r\$\s*)?(\d[\d\s\.,]*\d|\d)\s*(reais|real)?',
      caseSensitive: false,
    );

    final matches = moneyContext.allMatches(source).toList();
    if (matches.isEmpty) return null;

    for (final match in matches.reversed) {
      final raw = (match.group(1) ?? '').trim();
      final value = _parseMoney(raw);
      if (value != null && value > 0) return value;
    }
    return null;
  }

  double? _parseMoney(String raw) {
    var text = raw.replaceAll(' ', '').trim();
    if (text.isEmpty) return null;

    final hasComma = text.contains(',');
    final hasDot = text.contains('.');

    if (hasComma && hasDot) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      text = text.replaceAll(',', '.');
    }

    return double.tryParse(text);
  }

  int _extractInstallments(String text) {
    final xMatch = RegExp(r'(\d{1,2})\s*x').firstMatch(text);
    if (xMatch != null) return int.tryParse(xMatch.group(1) ?? '') ?? 1;

    final vezesMatch = RegExp(r'em\s+(\d{1,2})\s+vez').firstMatch(text);
    if (vezesMatch != null) return int.tryParse(vezesMatch.group(1) ?? '') ?? 1;

    return 1;
  }

  int? _extractRecurringDay(String text) {
    if (!(text.contains('todo dia') || text.contains('mensal'))) return null;

    final dayMatch = RegExp(r'todo dia\s+(\d{1,2})').firstMatch(text);
    if (dayMatch != null) {
      final day = int.tryParse(dayMatch.group(1) ?? '');
      if (day != null) return _clampRecurringDay(day);
    }

    return _clampRecurringDay(DateTime.now().day);
  }

  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (text.contains('hoje')) return today;
    if (text.contains('amanha') || text.contains('amanhã')) {
      return today.add(const Duration(days: 1));
    }
    if (text.contains('ontem')) {
      return today.subtract(const Duration(days: 1));
    }

    final explicitDate = RegExp(
      r'(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?',
    ).firstMatch(text);
    if (explicitDate != null) {
      final day = int.tryParse(explicitDate.group(1) ?? '');
      final month = int.tryParse(explicitDate.group(2) ?? '');
      final year = int.tryParse(explicitDate.group(3) ?? '') ?? now.year;
      if (day != null && month != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  FinanceEntryType _entryTypeFromText(String text, {required bool isIncome}) {
    if (isIncome) {
      if (text.contains('pix')) return FinanceEntryType.pixIn;
      if (text.contains('transfer')) return FinanceEntryType.transferIn;
      if (text.contains('dinheiro')) return FinanceEntryType.cash;
      return FinanceEntryType.transferIn;
    }

    if (text.contains('credito') || text.contains('crédito'))
      return FinanceEntryType.credit;
    if (text.contains('pix')) return FinanceEntryType.pixOut;
    if (text.contains('boleto')) return FinanceEntryType.boleto;
    if (text.contains('transfer')) return FinanceEntryType.transferOut;
    if (text.contains('dinheiro')) return FinanceEntryType.cash;
    return FinanceEntryType.debit;
  }

  FinanceCategory _categoryFromText(
    String text, {
    required FinanceStore store,
    required bool isIncome,
  }) {
    final categories = store.categories
        .where((item) => item.isIncomeCategory == isIncome)
        .toList();

    FinanceCategory? byId(String id) {
      for (final category in categories) {
        if (category.id == id) return category;
      }
      return null;
    }

    if (isIncome) {
      if (text.contains('salario') || text.contains('salário')) {
        return byId('salary') ?? categories.first;
      }
      return byId('other_income') ?? categories.first;
    }

    if (text.contains('mercado') ||
        text.contains('supermercado') ||
        text.contains('comida') ||
        text.contains('lanche')) {
      return byId('food') ?? categories.first;
    }
    if (text.contains('gasolina') ||
        text.contains('uber') ||
        text.contains('onibus') ||
        text.contains('ônibus')) {
      return byId('transport') ?? categories.first;
    }
    if (text.contains('farmacia') ||
        text.contains('farmácia') ||
        text.contains('medico') ||
        text.contains('médico')) {
      return byId('health') ?? categories.first;
    }
    if (text.contains('roupa') ||
        text.contains('camisa') ||
        text.contains('tenis') ||
        text.contains('tênis')) {
      return byId('shopping') ?? categories.first;
    }
    if (text.contains('cinema') ||
        text.contains('jogo') ||
        text.contains('lazer') ||
        text.contains('viagem')) {
      return byId('leisure') ?? categories.first;
    }
    if (text.contains('aluguel') ||
        text.contains('internet') ||
        text.contains('energia') ||
        text.contains('agua') ||
        text.contains('água')) {
      return byId('home') ?? categories.first;
    }
    if (text.contains('curso') ||
        text.contains('faculdade') ||
        text.contains('escola')) {
      return byId('education') ?? categories.first;
    }

    return byId('other_expense') ?? categories.first;
  }

  String _buildTitle(
    String text, {
    required String fallbackCategory,
    required bool isIncome,
  }) {
    var cleaned = text;

    final removeBits = <RegExp>[
      RegExp(r'\br\$\s*\d[\d\.,]*\b', caseSensitive: false),
      RegExp(r'\b\d[\d\.,]*\s*(reais|real)\b', caseSensitive: false),
      RegExp(
        r'\b(credito|crédito|debito|débito|pix|boleto|transferencia|transferência)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(todo dia\s+\d{1,2}|mensal|hoje|amanha|amanhã|ontem)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(em\s+\d{1,2}\s+vezes|\d{1,2}\s*x)\b', caseSensitive: false),
      RegExp(
        r'\b(gastei|comprei|paguei|recebi|ganhei|caiu|entrada)\b',
        caseSensitive: false,
      ),
    ];

    for (final regExp in removeBits) {
      cleaned = cleaned.replaceAll(regExp, ' ');
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isEmpty) {
      return isIncome ? 'Entrada' : _capitalize(fallbackCategory);
    }

    return _capitalize(cleaned);
  }

  String? _extractTag(String text) {
    final match = RegExp(
      r'(?:para|pro|pra)\s+(viagem|reforma|aniversario|aniversário|presente|faculdade|obra)',
    ).firstMatch(text);
    return match?.group(1);
  }

  DateTime _addMonthsKeepingDay(DateTime base, int monthOffset) {
    final targetMonth = DateTime(base.year, base.month + monthOffset, 1);
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final safeDay = base.day < 1
        ? 1
        : (base.day > lastDay ? lastDay : base.day);
    return DateTime(targetMonth.year, targetMonth.month, safeDay);
  }

  int _clampRecurringDay(int day) {
    if (day < 1) return 1;
    if (day > 28) return 28;
    return day;
  }

  List<double> _splitInstallments(double total, int count) {
    final cents = (total * 100).round();
    final base = cents ~/ count;
    final remainder = cents % count;
    return List<double>.generate(count, (index) {
      final part = base + (index < remainder ? 1 : 0);
      return part / 100.0;
    });
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $fixed';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}
