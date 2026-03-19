// ============================================================================
// FILE: lib/presentation/pages/home/tabs/timeline/create_block_sheet.dart
//
// Data/hora pt-BR:
// - Data exibida em dd/MM/aaaa
// - DatePicker em pt-BR
// - TimePicker em formato 24h (Brasil)
// ============================================================================

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

  late DateTime _day;

  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);

  @override
  void initState() {
    super.initState();
    _day = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_day.day.toString().padLeft(2, '0')}/${_day.month.toString().padLeft(2, '0')}/${_day.year}';

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecionar data',
      confirmText: 'OK',
      cancelText: 'Cancelar',
    );
    if (picked == null) return;
    setState(() => _day = picked);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _start,
      helpText: 'Selecionar horário de início',
      confirmText: 'OK',
      cancelText: 'Cancelar',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (t == null) return;
    setState(() => _start = t);
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _end,
      helpText: 'Selecionar horário de fim',
      confirmText: 'OK',
      cancelText: 'Cancelar',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (t == null) return;
    setState(() => _end = t);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite um título.')));
      return;
    }

    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _start.hour,
      _start.minute,
    );
    final end = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _end.hour,
      _end.minute,
    );

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
          Text('Novo item', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<TimelineBlockType>(
            segments: const [
              ButtonSegment(
                value: TimelineBlockType.event,
                label: Text('Evento'),
              ),
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
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Data: $_dateLabel'),
                ),
              ),
            ],
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
            label: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}
