// ============================================================================
// FILE: lib/features/finance/data/models/finance_transaction.dart
//
// Modelo principal de transação financeira.
//
// O que este arquivo faz:
// - Mantém compatibilidade com o sistema atual do Vida.
// - Adiciona campos opcionais para evolução do Financeiro 2.0.
// - Suporta tags, subcategoria, recorrência mensal e parcelamento.
// - Não quebra os lançamentos antigos, porque os novos campos são opcionais.
// ============================================================================

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
    this.subcategory,
    this.tag,
    this.accountName,
    this.cardName,
    this.isRecurring = false,
    this.recurringDayOfMonth,
    this.installmentGroupId,
    this.installmentIndex = 1,
    this.installmentTotal = 1,
    this.projectionParentId,
    this.projectionKind,
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

  /// Ex.: Alimentação -> Mercado / Padaria / Restaurante.
  final String? subcategory;

  /// Ex.: viagem, reforma, aniversário.
  final String? tag;

  /// Conta/carteira de origem. Ex.: Nubank, Inter, Dinheiro.
  final String? accountName;

  /// Cartão usado na compra. Ex.: Nubank, Inter, Itaú.
  final String? cardName;

  /// Regras simples de recorrência mensal.
  final bool isRecurring;

  /// Dia do mês em que a recorrência costuma acontecer.
  /// Ex.: 5 = todo dia 5.
  final int? recurringDayOfMonth;

  /// Identificador comum para todas as parcelas do mesmo gasto.
  final String? installmentGroupId;

  /// Número da parcela atual. Ex.: 3 de 10.
  final int installmentIndex;

  /// Total de parcelas.
  final int installmentTotal;

  /// Lançamentos projetados não são salvos diretamente; apontam para o registro
  /// original que gerou a previsão.
  final String? projectionParentId;
  final String? projectionKind;

  bool get isInstallment => installmentTotal > 1;
  bool get isProjection => projectionParentId != null;

  String get installmentLabel {
    if (!isInstallment) return '';
    return '$installmentIndex/$installmentTotal';
  }

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
    String? subcategory,
    bool clearSubcategory = false,
    String? tag,
    bool clearTag = false,
    String? accountName,
    bool clearAccountName = false,
    String? cardName,
    bool clearCardName = false,
    bool? isRecurring,
    int? recurringDayOfMonth,
    bool clearRecurringDayOfMonth = false,
    String? installmentGroupId,
    bool clearInstallmentGroupId = false,
    int? installmentIndex,
    int? installmentTotal,
    String? projectionParentId,
    bool clearProjectionParentId = false,
    String? projectionKind,
    bool clearProjectionKind = false,
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
      subcategory: clearSubcategory ? null : (subcategory ?? this.subcategory),
      tag: clearTag ? null : (tag ?? this.tag),
      accountName: clearAccountName ? null : (accountName ?? this.accountName),
      cardName: clearCardName ? null : (cardName ?? this.cardName),
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDayOfMonth: clearRecurringDayOfMonth
          ? null
          : (recurringDayOfMonth ?? this.recurringDayOfMonth),
      installmentGroupId: clearInstallmentGroupId
          ? null
          : (installmentGroupId ?? this.installmentGroupId),
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentTotal: installmentTotal ?? this.installmentTotal,
      projectionParentId: clearProjectionParentId
          ? null
          : (projectionParentId ?? this.projectionParentId),
      projectionKind: clearProjectionKind
          ? null
          : (projectionKind ?? this.projectionKind),
    );
  }
}
