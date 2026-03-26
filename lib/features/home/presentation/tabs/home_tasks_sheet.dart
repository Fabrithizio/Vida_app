import 'package:flutter/material.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';

class HomeTasksSheet extends StatefulWidget {
  const HomeTasksSheet({super.key, required this.store});

  final HomeTasksStore store;

  @override
  State<HomeTasksSheet> createState() => _HomeTasksSheetState();
}

class _HomeTasksSheetState extends State<HomeTasksSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _focusNode = FocusNode();

  HomeTaskEffort _effort = HomeTaskEffort.quick;
  HomeTaskCategory _category = HomeTaskCategory.cleaning;
  HomeTaskArea _area = HomeTaskArea.wholeHouse;

  HomeTaskEffort? _filterEffort;
  HomeTaskArea? _filterArea;
  bool _showDone = true;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await widget.store.add(
      title: _titleController.text,
      effort: _effort,
      category: _category,
      area: _area,
      notes: _notesController.text,
    );

    _titleController.clear();
    _notesController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _editItem(HomeTaskItem item) async {
    final title = TextEditingController(text: item.title);
    final notes = TextEditingController(text: item.notes ?? '');
    var effort = item.effort;
    var category = item.category;
    var area = item.area;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Editar tarefa',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<HomeTaskEffort>(
                      value: effort,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: HomeTaskEffort.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(homeTaskEffortLabel(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModal(() => effort = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<HomeTaskCategory>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: HomeTaskCategory.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(homeTaskCategoryLabel(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModal(() => category = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<HomeTaskArea>(
                      value: area,
                      decoration: const InputDecoration(
                        labelText: 'Cômodo / local',
                        border: OutlineInputBorder(),
                      ),
                      items: HomeTaskArea.values
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(homeTaskAreaLabel(e)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModal(() => area = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await widget.store.remove(item.id);
                              if (mounted) Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Excluir'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await widget.store.updateItem(
                                item.id,
                                title: title.text,
                                effort: effort,
                                category: category,
                                area: area,
                                notes: notes.text,
                              );
                              if (mounted) Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    title.dispose();
    notes.dispose();
  }

  List<HomeTaskItem> _filteredItems(List<HomeTaskItem> items) {
    return items.where((item) {
      if (!_showDone && item.done) return false;
      if (_filterEffort != null && item.effort != _filterEffort) return false;
      if (_filterArea != null && item.area != _filterArea) return false;
      return true;
    }).toList();
  }

  Map<HomeTaskArea, List<HomeTaskItem>> _groupByArea(List<HomeTaskItem> items) {
    final map = <HomeTaskArea, List<HomeTaskItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.area, () => <HomeTaskItem>[]).add(item);
    }
    return map;
  }

  Color _effortColor(HomeTaskEffort effort) {
    switch (effort) {
      case HomeTaskEffort.quick:
        return Colors.lightBlueAccent;
      case HomeTaskEffort.major:
        return Colors.orangeAccent;
    }
  }

  IconData _categoryIcon(HomeTaskCategory category) {
    switch (category) {
      case HomeTaskCategory.cleaning:
        return Icons.cleaning_services_outlined;
      case HomeTaskCategory.organization:
        return Icons.checklist_rounded;
      case HomeTaskCategory.maintenance:
        return Icons.home_repair_service_outlined;
    }
  }

  Widget _buildAddSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.add_task),
                SizedBox(width: 8),
                Text(
                  'Adicionar tarefa da casa',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(
                labelText: 'O que precisa ser feito?',
                hintText: 'Ex: limpar fogão, trocar torneira...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                hintText: 'Ex: verificar vazamento perto da pia',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<HomeTaskEffort>(
              value: _effort,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: HomeTaskEffort.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(homeTaskEffortLabel(e)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _effort = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<HomeTaskCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: HomeTaskCategory.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(homeTaskCategoryLabel(e)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<HomeTaskArea>(
              value: _area,
              decoration: const InputDecoration(
                labelText: 'Cômodo / local',
                border: OutlineInputBorder(),
              ),
              items: HomeTaskArea.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(homeTaskAreaLabel(e)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _area = value);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar tarefa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          runSpacing: 8,
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Mostrar concluídas'),
              selected: _showDone,
              onSelected: (value) {
                setState(() => _showDone = value);
              },
            ),
            ...HomeTaskEffort.values.map(
              (effort) => ChoiceChip(
                label: Text(homeTaskEffortLabel(effort)),
                selected: _filterEffort == effort,
                onSelected: (_) {
                  setState(() {
                    _filterEffort = _filterEffort == effort ? null : effort;
                  });
                },
              ),
            ),
            ...HomeTaskArea.values.map(
              (area) => ChoiceChip(
                label: Text(homeTaskAreaLabel(area)),
                selected: _filterArea == area,
                onSelected: (_) {
                  setState(() {
                    _filterArea = _filterArea == area ? null : area;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.home_repair_service_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Casa & Organização',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.store.pendingCount} pendente(s) • '
                    '${widget.store.doneCount} concluída(s)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'clear_done') {
                  await widget.store.clearDone();
                }
                if (value == 'reset_seed') {
                  await widget.store.resetAndSeedAgain();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'clear_done',
                  child: Text('Limpar concluídas'),
                ),
                PopupMenuItem(
                  value: 'reset_seed',
                  child: Text('Restaurar lista base'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(HomeTaskItem item) {
    final effortColor = _effortColor(item.effort);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: item.done,
        onChanged: (_) => widget.store.toggle(item.id),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          decoration: item.done
              ? TextDecoration.lineThrough
              : TextDecoration.none,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MiniTag(
                icon: _categoryIcon(item.category),
                text: homeTaskCategoryLabel(item.category),
              ),
              _MiniTag(
                color: effortColor,
                text: homeTaskEffortLabel(item.effort),
              ),
              _MiniTag(text: homeTaskAreaLabel(item.area)),
            ],
          ),
          if ((item.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.notes!, style: const TextStyle(color: Colors.white70)),
          ],
        ],
      ),
      trailing: IconButton(
        tooltip: 'Editar',
        onPressed: () => _editItem(item),
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final all = _filteredItems(widget.store.items);
          final groups = _groupByArea(all);
          final orderedAreas = HomeTaskArea.values
              .where((area) => (groups[area]?.isNotEmpty ?? false))
              .toList();

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    children: [
                      _buildSummary(),
                      const SizedBox(height: 10),
                      _buildAddSection(),
                      const SizedBox(height: 10),
                      _buildFilters(),
                      const SizedBox(height: 10),
                      if (all.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(
                            child: Text(
                              'Nenhuma tarefa encontrada.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      else
                        ...orderedAreas.map((area) {
                          final list = groups[area]!;
                          final pending = list.where((e) => !e.done).length;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            homeTaskAreaLabel(area),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          pending == 0
                                              ? 'Tudo em dia'
                                              : '$pending pendente(s)',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...list.map(_buildTaskTile),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
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

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tagColor = color ?? Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tagColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tagColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              color: tagColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
