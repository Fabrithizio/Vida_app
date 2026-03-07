import 'package:flutter/material.dart';

import '../../data/models/finance_category.dart';
import '../../data/models/finance_entry_type.dart';
import '../../data/models/finance_transaction.dart';
import '../../data/models/finance_transaction_source.dart';
import '../stores/finance_store.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key, required this.store});

  final FinanceStore store;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isIncome = false;
  late FinanceEntryType _entryType;
  FinanceCategory? _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entryType = FinanceEntryType.debit;
    _category = widget.store.categories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
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

    final transaction = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: DateTime.now(),
      category: _category!,
      entryType: _entryType,
      source: FinanceTransactionSource.manual,
      isIncome: _isIncome,
    );

    await widget.store.addTransaction(transaction);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.store.categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova transação')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Descrição',
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
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FinanceCategory>(
            initialValue: _category,
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
          const SizedBox(height: 12),
          DropdownButtonFormField<FinanceEntryType>(
            initialValue: _entryType,
            decoration: const InputDecoration(
              labelText: 'Tipo de pagamento',
              border: OutlineInputBorder(),
            ),
            items: FinanceEntryType.values
                .map(
                  (type) => DropdownMenuItem<FinanceEntryType>(
                    value: type,
                    child: Text(_entryTypeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _entryType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('É entrada de dinheiro'),
            value: _isIncome,
            onChanged: (value) {
              setState(() {
                _isIncome = value;
              });
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Salvando...' : 'Salvar transação'),
          ),
        ],
      ),
    );
  }

  String _entryTypeLabel(FinanceEntryType type) {
    switch (type) {
      case FinanceEntryType.debit:
        return 'Débito';
      case FinanceEntryType.credit:
        return 'Crédito';
      case FinanceEntryType.pixIn:
        return 'PIX recebido';
      case FinanceEntryType.pixOut:
        return 'PIX enviado';
      case FinanceEntryType.transferIn:
        return 'Transferência recebida';
      case FinanceEntryType.transferOut:
        return 'Transferência enviada';
      case FinanceEntryType.cash:
        return 'Dinheiro';
      case FinanceEntryType.boleto:
        return 'Boleto';
      case FinanceEntryType.other:
        return 'Outro';
    }
  }
}
