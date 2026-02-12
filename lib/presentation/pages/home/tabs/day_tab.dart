import 'package:flutter/material.dart';

import '../../../../data/models/timeline_block.dart';
import '../../../../features/timeline/timeline_store.dart';

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

    // Exemplo só pra ver funcionando
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
      builder: (_) => _CreateBlockSheet(initialDay: _selected),
    );

    if (created == null) return;
    setState(() => _store.add(created));
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
                        ? _DayTimelineView(items: items)
                        : Center(
                            child: Text(
                              'MVP: ${_range.name} ainda é só resumo.\n\n(Depois vamos desenhar bonito)',
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

class _DayTimelineView extends StatelessWidget {
  const _DayTimelineView({required this.items});

  final List<TimelineBlock> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _BlockCard(block: items[i]),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block});

  final TimelineBlock block;

  @override
  Widget build(BuildContext context) {
    final icon = switch (block.type) {
      TimelineBlockType.event => Icons.event_outlined,
      TimelineBlockType.goal => Icons.flag_outlined,
      TimelineBlockType.note => Icons.note_outlined,
    };

    final start = '${block.start.hour.toString().padLeft(2, '0')}:${block.start.minute.toString().padLeft(2, '0')}';
    final end = block.end == null
        ? null
        : '${block.end!.hour.toString().padLeft(2, '0')}:${block.end!.minute.toString().padLeft(2, '0')}';

    return ListTile(
      leading: Icon(icon),
      title: Text(block.title),
      subtitle: Text(end == null ? start : '$start → $end'),
    );
  }
}

class _CreateBlockSheet extends StatefulWidget {
  const _CreateBlockSheet({required this.initialDay});

  final DateTime initialDay;

  @override
  State<_CreateBlockSheet> createState() => _CreateBlockSheetState();
}

class _CreateBlockSheetState extends State<_CreateBlockSheet> {
  TimelineBlockType _type = TimelineBlockType.event;
  final _title = TextEditingController();

  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t == null) return;
    setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t == null) return;
    setState(() => _end = t);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um título.')),
      );
      return;
    }

    final d = widget.initialDay;
    final start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute);
    final end = DateTime(d.year, d.month, d.day, _end.hour, _end.minute);

    final block = TimelineBlock(
      id: 'b_${DateTime.now().microsecondsSinceEpoch}',
      type: _type,
      title: title,
      start: start,
      end: end.isAfter(start) ? end : start.add(const Duration(minutes: 30)),
    );

    Navigator.of(context).pop(block);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<TimelineBlockType>(
            segments: const [
              ButtonSegment(value: TimelineBlockType.event, label: Text('Evento')),
              ButtonSegment(value: TimelineBlockType.goal, label: Text('Meta')),
              ButtonSegment(value: TimelineBlockType.note, label: Text('Nota')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(Icons.schedule),
                  label: Text('Início: ${_start.format(context)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickEnd,
                  icon: const Icon(Icons.schedule),
                  label: Text('Fim: ${_end.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Adicionar bloco'),
          ),
        ],
      ),
    );
  }
}
