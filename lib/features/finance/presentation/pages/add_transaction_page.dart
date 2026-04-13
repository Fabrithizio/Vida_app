// ============================================================================
// FILE: lib/features/finance/presentation/pages/add_transaction_page.dart
//
// Tela de criação/edição de lançamentos financeiros.
//
// O que este arquivo faz:
// - Mantém o fluxo simples para iniciantes.
// - Esconde opções mais avançadas em uma seção expansível.
// - Permite tag, subcategoria, recorrência mensal e parcelamento.
// - Quando o usuário lança uma compra parcelada, o arquivo cria as parcelas
//   automaticamente nos meses seguintes.
// ============================================================================

import 'package:flutter/material.dart';

import '../../data/models/finance_category.dart';
import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_transaction.dart';
import '../../data/models/finance_transaction_source.dart';
import '../stores/finance_store.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({
    super.key,
    required this.store,
    this.initialTransaction,
  });

  final FinanceStore store;
  final FinanceTransaction? initialTransaction;

  bool get isEditing => initialTransaction != null;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _subcategoryController = TextEditingController();
  final _tagController = TextEditingController();

  bool _isIncome = false;
  late FinanceEntryType _entryType;
  FinanceCategory? _category;
  bool _isSaving = false;
  late DateTime _selectedDate;

  bool _showAdvanced = false;
  bool _showAllCategories = false;
  bool _isRecurring = false;
  int _recurringDay = 5;
  int _installmentTotal = 1;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialTransaction;
    if (initial != null) {
      _titleController.text = initial.title;
      _amountController.text = initial.amount
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _subcategoryController.text = initial.subcategory ?? '';
      _tagController.text = initial.tag ?? '';
      _isIncome = initial.isIncome;
      _entryType = initial.entryType;
      _category = initial.category;
      _selectedDate = initial.date;
      _isRecurring = initial.isRecurring;
      _recurringDay = _clampRecurringDay(
        initial.recurringDayOfMonth ?? initial.date.day,
      );
      _installmentTotal = initial.installmentTotal;
      _showAdvanced =
          initial.subcategory != null ||
          initial.tag != null ||
          initial.isRecurring ||
          initial.installmentTotal > 1;
    } else {
      _selectedDate = DateTime.now();
      _entryType = FinanceEntryType.debit;
      _isIncome = false;
      _recurringDay = _clampRecurringDay(DateTime.now().day);
      _category = _defaultCategory(isIncome: false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _subcategoryController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  FinanceCategory? _defaultCategory({required bool isIncome}) {
    final options = _filteredCategories(isIncome: isIncome);
    if (options.isEmpty) return null;
    return options.first;
  }

  List<FinanceCategory> _filteredCategories({required bool isIncome}) {
    return widget.store.categories
        .where((item) => item.isIncomeCategory == isIncome)
        .toList();
  }

  static const Set<String> _primaryExpenseCategoryIds = {
    'food_market',
    'transport_fuel',
    'transport_public',
    'health_plan',
    'house_rent',
    'utility_energy',
    'utility_water',
    'utility_internet',
    'debt_credit_card',
    'future_emergency',
    'future_stocks',
    'leisure_restaurants',
    'leisure_delivery',
    'shopping_clothes',
    'subscription_video',
    'other_expense',
    'food',
    'transport',
    'health',
    'home',
    'education',
    'leisure',
    'shopping',
  };

  List<FinanceCategory> _visibleCategories({required bool isIncome}) {
    final all = _filteredCategories(isIncome: isIncome);
    if (isIncome || _showAllCategories) return all;

    final primary = all
        .where((item) => _primaryExpenseCategoryIds.contains(item.id))
        .toList();

    if (primary.isEmpty) return all;
    if (_category != null && !primary.any((item) => item.id == _category!.id)) {
      primary.add(_category!);
    }
    return primary;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _recurringDay = _clampRecurringDay(picked.day);
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );

    if (title.isEmpty || amount == null || amount <= 0 || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha descrição, valor e categoria corretamente.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final subcategory = _nullableText(_subcategoryController.text);
      final tag = _nullableText(_tagController.text);
      final initial = widget.initialTransaction;
      final note = _buildNote(tag: tag, subcategory: subcategory);

      if (widget.isEditing) {
        final updated = FinanceTransaction(
          id: initial!.id,
          title: title,
          amount: amount,
          date: _selectedDate,
          category: _category!,
          entryType: _entryType,
          source: initial.source,
          isIncome: _isIncome,
          note: note,
          subcategory: subcategory,
          tag: tag,
          isRecurring:
              _entryType == FinanceEntryType.credit && _installmentTotal > 1
              ? false
              : _isRecurring,
          recurringDayOfMonth: _isRecurring ? _recurringDay : null,
          installmentGroupId: initial.installmentGroupId,
          installmentIndex: initial.installmentIndex,
          installmentTotal: initial.installmentTotal,
        );

        await widget.store.updateTransaction(updated);
      } else {
        final shouldCreateInstallments =
            !_isIncome &&
            _entryType == FinanceEntryType.credit &&
            _installmentTotal > 1;

        if (shouldCreateInstallments) {
          final groupId = 'inst_${DateTime.now().microsecondsSinceEpoch}';
          final amounts = _splitInstallments(amount, _installmentTotal);

          for (var i = 0; i < _installmentTotal; i++) {
            final dueDate = _addMonthsKeepingDay(_selectedDate, i);
            final transaction = FinanceTransaction(
              id: '${groupId}_${i + 1}',
              title: title,
              amount: amounts[i],
              date: dueDate,
              category: _category!,
              entryType: _entryType,
              source: FinanceTransactionSource.manual,
              isIncome: false,
              note: note,
              subcategory: subcategory,
              tag: tag,
              installmentGroupId: groupId,
              installmentIndex: i + 1,
              installmentTotal: _installmentTotal,
            );
            await widget.store.addTransaction(transaction);
          }
        } else {
          final transaction = FinanceTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            amount: amount,
            date: _selectedDate,
            category: _category!,
            entryType: _entryType,
            source: FinanceTransactionSource.manual,
            isIncome: _isIncome,
            note: note,
            subcategory: subcategory,
            tag: tag,
            isRecurring: _isRecurring,
            recurringDayOfMonth: _isRecurring ? _recurringDay : null,
          );
          await widget.store.addTransaction(transaction);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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

  String? _nullableText(String raw) {
    final text = raw.trim();
    return text.isEmpty ? null : text;
  }

  String? _buildNote({String? tag, String? subcategory}) {
    final parts = <String>[];
    if (subcategory != null && subcategory.isNotEmpty) {
      parts.add('Subcategoria: $subcategory');
    }
    if (tag != null && tag.isNotEmpty) {
      parts.add('Tag: $tag');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = _filteredCategories(isIncome: _isIncome);
    final categories = _visibleCategories(isIncome: _isIncome);
    final canEditInstallments = !(widget.isEditing && _installmentTotal > 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar lançamento' : 'Novo lançamento'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('Saída')),
              ButtonSegment<bool>(value: true, label: Text('Entrada')),
            ],
            selected: {_isIncome},
            onSelectionChanged: (value) {
              final nextIsIncome = value.first;
              setState(() {
                _isIncome = nextIsIncome;
                _showAllCategories = false;
                _category = _defaultCategory(isIncome: nextIsIncome);
                if (_isIncome) {
                  _entryType = FinanceEntryType.transferIn;
                  _installmentTotal = 1;
                  _isRecurring = false;
                } else {
                  _entryType = FinanceEntryType.debit;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              hintText: 'Ex.: supermercado, salário, internet',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Valor',
              hintText: 'Ex.: 89,90',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data',
                border: OutlineInputBorder(),
              ),
              child: Text(_formatDate(_selectedDate)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FinanceCategory>(
            initialValue: categories.any((item) => item.id == _category?.id)
                ? categories.firstWhere((item) => item.id == _category?.id)
                : (_category != null &&
                          allCategories.any((item) => item.id == _category?.id)
                      ? allCategories.firstWhere(
                          (item) => item.id == _category?.id,
                        )
                      : _defaultCategory(isIncome: _isIncome)),
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
            ),
            items: categories
                .map(
                  (category) => DropdownMenuItem<FinanceCategory>(
                    value: category,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _category = value;
              });
            },
          ),
          if (!_isIncome && allCategories.length > categories.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllCategories = !_showAllCategories;
                  });
                },
                icon: Icon(
                  _showAllCategories
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _showAllCategories
                      ? 'Mostrar menos categorias'
                      : 'Mais categorias',
                ),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FinanceEntryType>(
            initialValue: _entryType,
            decoration: const InputDecoration(
              labelText: 'Como foi pago / recebido',
              border: OutlineInputBorder(),
            ),
            items: _entryTypesForCurrentMode()
                .map(
                  (entryType) => DropdownMenuItem<FinanceEntryType>(
                    value: entryType,
                    child: Text(entryType.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _entryType = value;
                if (_entryType != FinanceEntryType.credit) {
                  _installmentTotal = 1;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              initiallyExpanded: _showAdvanced,
              onExpansionChanged: (value) {
                setState(() {
                  _showAdvanced = value;
                });
              },
              title: const Text('Mais opções'),
              subtitle: const Text('Subcategoria, tag, recorrência e parcelas'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                TextField(
                  controller: _subcategoryController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Subcategoria',
                    hintText: 'Ex.: mercado, assinatura, combustível',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tagController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tag do evento',
                    hintText: 'Ex.: viagem, reforma, presente',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_isIncome) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Conta recorrente mensal'),
                    subtitle: const Text(
                      'Bom para aluguel, internet, streaming e outras contas fixas.',
                    ),
                    value: _isRecurring,
                    onChanged:
                        (_entryType == FinanceEntryType.credit &&
                            _installmentTotal > 1)
                        ? null
                        : (value) {
                            setState(() {
                              _isRecurring = value;
                              if (value) {
                                _installmentTotal = 1;
                              }
                            });
                          },
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _recurringDay,
                      decoration: const InputDecoration(
                        labelText: 'Dia do mês',
                        border: OutlineInputBorder(),
                      ),
                      items: List<int>.generate(28, (index) => index + 1)
                          .map(
                            (day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text('Todo dia $day'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _recurringDay = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _installmentTotal,
                    decoration: const InputDecoration(
                      labelText: 'Parcelamento',
                      border: OutlineInputBorder(),
                    ),
                    items: List<int>.generate(12, (index) => index + 1)
                        .map(
                          (count) => DropdownMenuItem<int>(
                            value: count,
                            child: Text(
                              count == 1 ? 'À vista / 1x' : '$count parcelas',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged:
                        (!canEditInstallments ||
                            _entryType != FinanceEntryType.credit)
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _installmentTotal = value;
                              if (_installmentTotal > 1) {
                                _isRecurring = false;
                              }
                            });
                          },
                  ),
                  if (_entryType != FinanceEntryType.credit)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Parcelamento só fica ativo em compras no crédito.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                  if (!canEditInstallments)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Este lançamento já faz parte de um parcelamento. Para evitar inconsistência, o total de parcelas fica travado na edição.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              widget.isEditing ? 'Salvar alterações' : 'Salvar lançamento',
            ),
          ),
        ],
      ),
    );
  }

  List<FinanceEntryType> _entryTypesForCurrentMode() {
    if (_isIncome) {
      return const [
        FinanceEntryType.pixIn,
        FinanceEntryType.transferIn,
        FinanceEntryType.cash,
        FinanceEntryType.other,
      ];
    }

    return const [
      FinanceEntryType.debit,
      FinanceEntryType.credit,
      FinanceEntryType.pixOut,
      FinanceEntryType.transferOut,
      FinanceEntryType.cash,
      FinanceEntryType.boleto,
      FinanceEntryType.other,
    ];
  }
}
