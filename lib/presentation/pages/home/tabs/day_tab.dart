import 'package:flutter/material.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';
import 'package:vida_app/services/notifications/notification_service.dart';

import 'shopping_list_sheet.dart';
import 'timeline/create_block_sheet.dart';
import 'timeline/edit_block_sheet.dart';
import 'timeline/timeline_day_view.dart';
import 'timeline/timeline_summary_view.dart';

enum TimelineRange { day, week, month, year }

class DayTab extends StatefulWidget {
  const DayTab({
    super.key,
    required this.shoppingStore,
    required this.timelineStore,
  });

  final ShoppingListStore shoppingStore;
  final TimelineStore timelineStore;

  @override
  State<DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<DayTab> {
  late final TimelineStore _store;
  bool _loading = true;

  TimelineRange _range = TimelineRange.day;
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();

    _store = widget.timelineStore;

    Future.microtask(() async {
      await _store.load();
      await widget.shoppingStore.load();

      if (_store.all.isEmpty) {
        final now = DateTime.now();
        await _store.add(
          TimelineBlock(
            id: 'b1',
            type: TimelineBlockType.event,
            title: 'Consulta médica',
            start: DateTime(now.year, now.month, now.day, 10, 0),
            end: DateTime(now.year, now.month, now.day, 11, 0),
          ),
        );
        await _store.add(
          TimelineBlock(
            id: 'b2',
            type: TimelineBlockType.goal,
            title: 'Treino (meta)',
            start: DateTime(now.year, now.month, now.day, 18, 30),
            end: DateTime(now.year, now.month, now.day, 19, 10),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selected = picked);
  }

  Future<void> _addBlock() async {
    final created = await showModalBottomSheet<TimelineBlock>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => CreateBlockSheet(initialDay: _selected),
    );

    if (created == null) return;

    if (_store.hasConflict(created)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflito: já existe algo nesse horário.'),
        ),
      );
      return;
    }

    await _store.add(created);
    if (!mounted) return;
    setState(() {});
    await NotificationService.instance.scheduleTenMinutesBefore(created);
  }

  Future<void> _openEditBlock(TimelineBlock block) async {
    final result = await showModalBottomSheet<EditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EditBlockSheet(block: block),
    );

    if (result == null) return;

    if (result.delete) {
      await _store.removeById(block.id);
      await NotificationService.instance.cancelForBlock(block.id);
      if (!mounted) return;
      setState(() {});
      return;
    }

    final updated = result.updated;

    if (updated != null && _store.hasConflict(updated, excludeId: block.id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflito: já existe algo nesse horário.'),
        ),
      );
      return;
    }

    if (updated != null) {
      await _store.update(updated);
      await NotificationService.instance.cancelForBlock(block.id);
      await NotificationService.instance.scheduleTenMinutesBefore(updated);

      if (!mounted) return;
      setState(() {});
    }
  }

  void _openShopping() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ShoppingListSheet(store: widget.shoppingStore),
    );
  }

  Widget _buildShoppingPreviewCard() {
    return AnimatedBuilder(
      animation: widget.shoppingStore,
      builder: (context, _) {
        final items = widget.shoppingStore.items;
        final pending = items.where((e) => !e.done).toList(growable: false);
        final preview = pending.take(3).toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.shopping_cart_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Lista de compras',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            pending.isEmpty
                                ? 'ok'
                                : '${pending.length} pendente(s)',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (items.isEmpty)
                        const Text('Toque em “Abrir” para adicionar itens.')
                      else ...[
                        for (final it in preview)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• ${it.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (pending.length > preview.length)
                          Text('… +${pending.length - preview.length}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _openShopping,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRangeBody() {
    final weekStart = _startOfWeek(_selected);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final monthStart = DateTime(_selected.year, _selected.month, 1);
    final monthEnd = DateTime(_selected.year, _selected.month + 1, 1);

    final yearStart = DateTime(_selected.year, 1, 1);
    final yearEnd = DateTime(_selected.year + 1, 1, 1);

    return switch (_range) {
      TimelineRange.day => TimelineDayView(
        items: _store.itemsForDay(_selected),
        onTapBlock: _openEditBlock,
      ),
      TimelineRange.week => TimelineSummaryView(
        title: 'Semana',
        items: _store.itemsBetween(weekStart, weekEnd),
        onTapItem: _openEditBlock,
      ),
      TimelineRange.month => TimelineSummaryView(
        title: 'Mês',
        items: _store.itemsBetween(monthStart, monthEnd),
        onTapItem: _openEditBlock,
      ),
      TimelineRange.year => TimelineSummaryView(
        title: 'Ano',
        items: _store.itemsBetween(yearStart, yearEnd),
        onTapItem: _openEditBlock,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<TimelineRange>(
                      segments: const [
                        ButtonSegment(
                          value: TimelineRange.day,
                          label: Text('Dia'),
                        ),
                        ButtonSegment(
                          value: TimelineRange.week,
                          label: Text('Semana'),
                        ),
                        ButtonSegment(
                          value: TimelineRange.month,
                          label: Text('Mês'),
                        ),
                        ButtonSegment(
                          value: TimelineRange.year,
                          label: Text('Ano'),
                        ),
                      ],
                      selected: {_range},
                      onSelectionChanged: (s) =>
                          setState(() => _range = s.first),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Lista de compras',
                    onPressed: _openShopping,
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                  IconButton(
                    tooltip: 'Escolher data',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _buildShoppingPreviewCard(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildRangeBody(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar bloco',
        onPressed: _addBlock,
        child: const Icon(Icons.add),
      ),
    );
  }
}
