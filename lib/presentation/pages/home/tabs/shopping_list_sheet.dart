// lib/presentation/pages/home/tabs/shopping_list_sheet.dart
import 'package:flutter/material.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';

class ShoppingListSheet extends StatefulWidget {
  const ShoppingListSheet({super.key, required this.store});

  final ShoppingListStore store;

  @override
  State<ShoppingListSheet> createState() => _ShoppingListSheetState();
}

class _ShoppingListSheetState extends State<ShoppingListSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await widget.store.add(_controller.text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final items = widget.store.items;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.shopping_cart_outlined),
                  title: const Text('Lista de compras'),
                  subtitle: Text(
                    widget.store.pendingCount == 0
                        ? 'Tudo em dia 🎉'
                        : '${widget.store.pendingCount} pendente(s)',
                  ),
                  trailing: TextButton.icon(
                    onPressed: items.any((e) => e.done)
                        ? widget.store.clearDone
                        : null,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Limpar feitos'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.add_shopping_cart_outlined),
                            labelText: 'Adicionar item',
                            hintText: 'Ex: leite, pão, frutas…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _add,
                        child: const Text('Adicionar'),
                      ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 18),
                    child: Text('Sem itens. Adicione o primeiro acima 🙂'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final it = items[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: it.done,
                            onChanged: (_) => widget.store.toggle(it.id),
                          ),
                          title: Text(
                            it.text,
                            style: TextStyle(
                              decoration: it.done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remover',
                            onPressed: () => widget.store.remove(it.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
