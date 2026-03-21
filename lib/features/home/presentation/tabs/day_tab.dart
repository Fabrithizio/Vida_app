// ============================================================================
// FILE: lib/presentation/pages/home/tabs/day_tab.dart
//
// Mudança de UX:
// - Remove o calendário do topo (sem escolher data ali)
// - Ao clicar no +, o CreateBlockSheet permite escolher a data dentro do sheet
// - Corrige chamadas para TimelineDayView (items:) e TimelineSummaryView (sem range:)
// - Tudo em português
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../data/models/timeline_block.dart';
import '../../../shopping/shopping_list_store.dart';
import '../../../timeline/timeline_store.dart';
import '../../../../services/notifications/notification_service.dart';

import 'shopping_list_sheet.dart';
import 'day/create_block_sheet.dart';
import 'day/edit_block_sheet.dart';
import 'day/timeline_day_view.dart';
import 'day/timeline_summary_view.dart';

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

      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  Future<void> _openShopping() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ShoppingListSheet(store: widget.shoppingStore),
    );

    if (!mounted) return;
    setState(() {});
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
    await NotificationService.instance.scheduleTenMinutesBefore(created);

    if (!mounted) return;
    setState(() {
      _selected = DateTime(
        created.start.year,
        created.start.month,
        created.start.day,
      );
    });
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
    if (updated == null) return;

    if (_store.hasConflict(updated, excludeId: block.id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflito: já existe algo nesse horário.'),
        ),
      );
      return;
    }

    await _store.update(updated);
    await NotificationService.instance.cancelForBlock(block.id);
    await NotificationService.instance.scheduleTenMinutesBefore(updated);

    if (!mounted) return;
    setState(() {
      _selected = DateTime(
        updated.start.year,
        updated.start.month,
        updated.start.day,
      );
    });
  }

  List<TimelineBlock> _itemsForRange() {
    final sel = DateTime(_selected.year, _selected.month, _selected.day);

    switch (_range) {
      case TimelineRange.day:
        return _store.itemsForDay(sel);

      case TimelineRange.week:
        {
          final start = _startOfWeek(sel);
          final end = start.add(const Duration(days: 7));
          return _store.itemsBetween(start, end);
        }

      case TimelineRange.month:
        {
          final start = DateTime(sel.year, sel.month, 1);
          final end = DateTime(sel.year, sel.month + 1, 1);
          return _store.itemsBetween(start, end);
        }

      case TimelineRange.year:
        {
          final start = DateTime(sel.year, 1, 1);
          final end = DateTime(sel.year + 1, 1, 1);
          return _store.itemsBetween(start, end);
        }
    }
  }

  String _rangeTitle() {
    return switch (_range) {
      TimelineRange.day => 'Dia',
      TimelineRange.week => 'Semana',
      TimelineRange.month => 'Mês',
      TimelineRange.year => 'Ano',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final items = _itemsForRange();

    return Scaffold(
      backgroundColor: Colors.black,
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
                    tooltip: 'Adicionar',
                    onPressed: _addBlock,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _range == TimelineRange.day
                  ? TimelineDayView(
                      items: items, // ✅ correto no seu projeto
                      onTapBlock: _openEditBlock,
                    )
                  : TimelineSummaryView(
                      items: items,
                      title: _rangeTitle(), // ✅ sem "range:"
                      onTapItem: _openEditBlock,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
