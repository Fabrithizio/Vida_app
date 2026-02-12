import 'package:flutter/material.dart';

import '../../../../data/models/timeline_block.dart';
import '../../../../features/timeline/timeline_store.dart';
import 'timeline/create_block_sheet.dart';
import 'timeline/edit_block_sheet.dart';
import 'timeline/timeline_day_view.dart';

enum TimelineRange { day, week, month, year }

class DayTab extends StatefulWidget {
  const DayTab({super.key});

  @override
  State<DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<DayTab> {
  final TimelineStore _store = TimelineStore();

  TimelineRange _range = TimelineRange.day;
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _store.add(
      TimelineBlock(
        id: 'b1',
        type: TimelineBlockType.event,
        title: 'Consulta médica',
        start: DateTime(now.year, now.month, now.day, 10, 0),
        end: DateTime(now.year, now.month, now.day, 11, 0),
      ),
    );
    _store.add(
      TimelineBlock(
        id: 'b2',
        type: TimelineBlockType.goal,
        title: 'Treino (meta)',
        start: DateTime(now.year, now.month, now.day, 18, 30),
        end: DateTime(now.year, now.month, now.day, 19, 10),
      ),
    );
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
    setState(() => _store.add(created));
  }

  Future<void> _openEditBlock(TimelineBlock block) async {
    final result = await showModalBottomSheet<EditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EditBlockSheet(block: block),
    );

    if (result == null) return;

    setState(() {
      if (result.delete) {
        _store.removeById(block.id);
        return;
      }
      if (result.updated != null) {
        _store.update(result.updated!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _store.itemsForDay(_selected);

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
                    child: _range == TimelineRange.day
                        ? TimelineDayView(
                            items: items,
                            onTapBlock: _openEditBlock,
                          )
                        : Center(
                            child: Text(
                              'MVP: ${_range.name} ainda é só resumo.\n\n(Depois a gente desenha bonito)',
                              textAlign: TextAlign.center,
                            ),
                          ),
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
