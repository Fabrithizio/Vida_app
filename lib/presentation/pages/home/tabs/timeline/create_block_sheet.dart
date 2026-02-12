import 'package:flutter/material.dart';

import '../../../../../data/models/timeline_block.dart';

class CreateBlockSheet extends StatefulWidget {
  const CreateBlockSheet({super.key, required this.initialDay});

  final DateTime initialDay;

  @override
  State<CreateBlockSheet> createState() => _CreateBlockSheetState();
}

class _CreateBlockSheetState extends State<CreateBlockSheet> {
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
