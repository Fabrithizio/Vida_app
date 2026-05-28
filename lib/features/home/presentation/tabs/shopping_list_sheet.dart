// ============================================================================
// FILE: lib/presentation/pages/home/tabs/shopping_list_sheet.dart
//
// O que faz:
// - mostra a lista de compras do Meu Dia
// - agora suporta múltiplas listas
// - permite quantidade, unidade, nota e favorito
// - mantém adição rápida por texto e compatibilidade com voz
//
// Ajuste desta versão:
// - visual mais rico, sem ficar pesado
// - troca rápida entre listas
// - criação/edição de lista
// - edição de item por toque
// ============================================================================

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
  final _searchController = TextEditingController();

  bool _showDone = false;
  bool _showOnlyFavorites = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    await widget.store.add(raw);
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

  IconData _iconForList(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home_rounded;
      case 'store':
        return Icons.storefront_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'shopping_basket':
        return Icons.shopping_basket_rounded;
      default:
        return Icons.shopping_cart_rounded;
    }
  }

  Future<void> _createList() async {
    final controller = TextEditingController();
    String iconName = 'shopping_cart';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111111),
              title: const Text(
                'Nova lista',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nome da lista',
                      hintText: 'Ex: Casa, Loja, Farmácia',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _IconChoiceChip(
                        selected: iconName == 'shopping_cart',
                        icon: Icons.shopping_cart_rounded,
                        onTap: () =>
                            setLocalState(() => iconName = 'shopping_cart'),
                      ),
                      _IconChoiceChip(
                        selected: iconName == 'home',
                        icon: Icons.home_rounded,
                        onTap: () => setLocalState(() => iconName = 'home'),
                      ),
                      _IconChoiceChip(
                        selected: iconName == 'store',
                        icon: Icons.storefront_rounded,
                        onTap: () => setLocalState(() => iconName = 'store'),
                      ),
                      _IconChoiceChip(
                        selected: iconName == 'pharmacy',
                        icon: Icons.local_pharmacy_rounded,
                        onTap: () => setLocalState(() => iconName = 'pharmacy'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Criar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await widget.store.createList(controller.text, iconName: iconName);
    }
  }

  Future<void> _renameCurrentList() async {
    final current = widget.store.selectedList;
    if (current == null) return;

    final controller = TextEditingController(text: current.name);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: const Text(
            'Renomear lista',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Nome',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await widget.store.renameList(current.id, controller.text);
    }

    controller.dispose();
  }

  Future<void> _editItem(ShoppingItem item) async {
    final nameCtrl = TextEditingController(text: item.text);
    final qtyCtrl = TextEditingController(
      text: item.quantity == null ? '' : item.quantity.toString(),
    );
    final noteCtrl = TextEditingController(text: item.note ?? '');
    ShoppingUnit unit = item.unit;
    ShoppingCategory category = item.category;
    String listId = item.listId;
    bool favorite = item.favorite;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101010),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 18),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Editar item',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Item',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Quantidade',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<ShoppingUnit>(
                            initialValue: unit,
                            dropdownColor: const Color(0xFF171717),
                            style: const TextStyle(color: Colors.white),
                            items: ShoppingUnit.values
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(shoppingUnitLabel(e)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setLocalState(() => unit = value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Unidade',
                              labelStyle: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ShoppingCategory>(
                      initialValue: category,
                      dropdownColor: const Color(0xFF171717),
                      style: const TextStyle(color: Colors.white),
                      items: ShoppingCategory.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(categoryLabel(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => category = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: listId,
                      dropdownColor: const Color(0xFF171717),
                      style: const TextStyle(color: Colors.white),
                      items: widget.store.lists
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => listId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Lista',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        hintText: 'Ex: marca, preferência, detalhe',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: favorite,
                      onChanged: (value) =>
                          setLocalState(() => favorite = value),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Favorito',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Aparece antes dos outros itens',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) {
      final parsedQuantity = double.tryParse(
        qtyCtrl.text.trim().replaceAll(',', '.'),
      );
      await widget.store.updateItem(
        item.id,
        text: nameCtrl.text.trim(),
        quantity: parsedQuantity,
        clearQuantity: qtyCtrl.text.trim().isEmpty,
        unit: unit,
        note: noteCtrl.text.trim(),
        clearNote: noteCtrl.text.trim().isEmpty,
        category: category,
        listId: listId,
        favorite: favorite,
      );
    }

    nameCtrl.dispose();
    qtyCtrl.dispose();
    noteCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final currentList = widget.store.selectedList;
          var items = widget.store.items;

          final search = _searchController.text.trim().toLowerCase();
          if (search.isNotEmpty) {
            items = items
                .where((e) {
                  return e.text.toLowerCase().contains(search) ||
                      (e.note ?? '').toLowerCase().contains(search) ||
                      categoryLabel(e.category).toLowerCase().contains(search);
                })
                .toList(growable: false);
          }

          if (!_showDone) {
            items = items.where((e) => !e.done).toList(growable: false);
          }
          if (_showOnlyFavorites) {
            items = items.where((e) => e.favorite).toList(growable: false);
          }

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
                  leading: CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(
                      _iconForList(currentList?.iconName ?? 'shopping_cart'),
                    ),
                  ),
                  title: Text(currentList?.name ?? 'Lista de compras'),
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
                      if (v == 'new_list') await _createList();
                      if (v == 'rename_list') await _renameCurrentList();
                      if (v == 'remove_list' && currentList != null) {
                        await widget.store.removeList(currentList.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'new_list',
                        child: Text('Nova lista'),
                      ),
                      const PopupMenuItem(
                        value: 'rename_list',
                        child: Text('Renomear lista'),
                      ),
                      if (widget.store.lists.length > 1)
                        const PopupMenuItem(
                          value: 'remove_list',
                          child: Text('Excluir lista atual'),
                        ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'recategorize',
                        child: Text('Reclassificar tudo'),
                      ),
                      const PopupMenuItem(
                        value: 'clear_done',
                        child: Text('Limpar feitos'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.store.lists.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == widget.store.lists.length) {
                        return OutlinedButton.icon(
                          onPressed: _createList,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nova'),
                        );
                      }

                      final list = widget.store.lists[index];
                      final selected = list.id == widget.store.selectedListId;
                      final pending = widget.store.pendingCountForList(list.id);

                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => widget.store.selectList(list.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(_iconForList(list.iconName), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                list.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$pending',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _add(),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.add_shopping_cart_outlined,
                                ),
                                labelText: 'Adicionar item',
                                hintText:
                                    'Ex: banana 2kg, leite 12 un, sabão em pó',
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          labelText: 'Buscar na lista',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilterChip(
                            selected: _showDone,
                            onSelected: (v) => setState(() => _showDone = v),
                            label: const Text('Mostrar feitos'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: _showOnlyFavorites,
                            onSelected: (v) =>
                                setState(() => _showOnlyFavorites = v),
                            label: const Text('Só favoritos'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.store.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 18),
                    child: Text('Sem itens. Adicione o primeiro acima 🙂'),
                  )
                else if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 18),
                    child: Text('Nada encontrado com o filtro atual.'),
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
                                      onTap: () => _editItem(it),
                                      leading: Checkbox(
                                        value: it.done,
                                        onChanged: (_) =>
                                            widget.store.toggle(it.id),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              it.text,
                                              style: TextStyle(
                                                decoration: it.done
                                                    ? TextDecoration.lineThrough
                                                    : TextDecoration.none,
                                                fontWeight: it.favorite
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (it.favorite)
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: Colors.amber,
                                            ),
                                        ],
                                      ),
                                      subtitle: Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          if (it.quantityLabel.isNotEmpty)
                                            _MiniMetaChip(
                                              label: it.quantityLabel,
                                            ),
                                          if ((it.note ?? '').trim().isNotEmpty)
                                            _MiniMetaChip(
                                              label: it.note!.trim(),
                                            ),
                                          if (widget.store.lists.length > 1)
                                            _MiniMetaChip(
                                              label: widget.store.lists
                                                  .firstWhere(
                                                    (e) => e.id == it.listId,
                                                    orElse: () => widget
                                                        .store
                                                        .selectedList!,
                                                  )
                                                  .name,
                                            ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Favoritar',
                                            onPressed: () => widget.store
                                                .toggleFavorite(it.id),
                                            icon: Icon(
                                              it.favorite
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Remover',
                                            onPressed: () =>
                                                widget.store.remove(it.id),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
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

class _MiniMetaChip extends StatelessWidget {
  const _MiniMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IconChoiceChip extends StatelessWidget {
  const _IconChoiceChip({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.white12,
          ),
        ),
        child: Icon(icon),
      ),
    );
  }
}
