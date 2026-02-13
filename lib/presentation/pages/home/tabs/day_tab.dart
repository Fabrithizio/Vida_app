// lib/presentation/pages/home/tabs/day_tab.dart
import 'package:flutter/material.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/timeline/hive_timeline_repository.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';
import 'package:vida_app/services/notifications/notification_service.dart';

import 'timeline/create_block_sheet.dart';
import 'timeline/edit_block_sheet.dart';
import 'timeline/timeline_day_view.dart';
import 'timeline/timeline_summary_view.dart';

enum TimelineRange { day, week, month, year }

class DayTab extends StatefulWidget {
  const DayTab({super.key});

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

    _store = TimelineStore(repo: HiveTimelineRepository());

    Future.microtask(() async {
      await _store.load();

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
    final diff = day.weekday - DateTime.monday; // monday=1
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
    if (updated != null) {
      await _store.update(updated);
      await NotificationService.instance.cancelForBlock(block.id);
      await NotificationService.instance.scheduleTenMinutesBefore(updated);

      if (!mounted) return;
      setState(() {});
    }
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                        ButtonSegment(value: TimelineRange.day, label: Text('Dia')),
                        ButtonSegment(value: TimelineRange.week, label: Text('Semana')),
                        ButtonSegment(value: TimelineRange.month, label: Text('Mês')),
                        ButtonSegment(value: TimelineRange.year, label: Text('Ano')),
                      ],
                      selected: {_range},
                      onSelectionChanged: (s) => setState(() => _range = s.first),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Escolher data',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ),
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
