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

  Map<ShoppingCategory, List<ShoppingItem>> _groupByCategory(
    List<ShoppingItem> items,
  ) {
    final map = <ShoppingCategory, List<ShoppingItem>>{};
    for (final it in items) {
      map.putIfAbsent(it.category, () => <ShoppingItem>[]).add(it);
    }
    return map;
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
          final groups = _groupByCategory(items);

          final orderedCats = ShoppingCategory.values.where((c) {
            final list = groups[c];
            return list != null && list.isNotEmpty;
          }).toList();

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
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opções',
                    onSelected: (v) async {
                      if (v == 'clear_done') await widget.store.clearDone();
                      if (v == 'recategorize')
                        await widget.store.recategorizeAll();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'recategorize',
                        child: Text('Reclassificar tudo'),
                      ),
                      PopupMenuItem(
                        value: 'clear_done',
                        child: Text('Limpar feitos'),
                      ),
                    ],
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
                            hintText: 'Ex: sabão em pó, banana, frango…',
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: orderedCats.length,
                      itemBuilder: (context, idx) {
                        final cat = orderedCats[idx];
                        final list = groups[cat]!;
                        final pending = list.where((e) => !e.done).length;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          categoryLabel(cat),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        pending == 0
                                            ? 'ok'
                                            : '$pending pendente(s)',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...list.map((it) {
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Checkbox(
                                        value: it.done,
                                        onChanged: (_) =>
                                            widget.store.toggle(it.id),
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
                                        onPressed: () =>
                                            widget.store.remove(it.id),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
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
