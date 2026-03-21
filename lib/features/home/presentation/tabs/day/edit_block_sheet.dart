import 'package:flutter/material.dart';

import '../../../../../data/models/timeline_block.dart';

class EditResult {
  const EditResult({this.updated, this.delete = false});
  final TimelineBlock? updated;
  final bool delete;
}

class EditBlockSheet extends StatefulWidget {
  const EditBlockSheet({super.key, required this.block});

  final TimelineBlock block;

  @override
  State<EditBlockSheet> createState() => _EditBlockSheetState();
}

class _EditBlockSheetState extends State<EditBlockSheet> {
  late TimelineBlockType _type;
  late TextEditingController _title;

  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();

    _type = widget.block.type;
    _title = TextEditingController(text: widget.block.title);

    _day = DateTime(
      widget.block.start.year,
      widget.block.start.month,
      widget.block.start.day,
    );

    _start = TimeOfDay(
      hour: widget.block.start.hour,
      minute: widget.block.start.minute,
    );

    final end = widget.block.end ?? widget.block.start.add(const Duration(minutes: 30));
    _end = TimeOfDay(hour: end.hour, minute: end.minute);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _day = picked);
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

    final start = DateTime(_day.year, _day.month, _day.day, _start.hour, _start.minute);
    final end = DateTime(_day.year, _day.month, _day.day, _end.hour, _end.minute);

    final updated = widget.block.copyWith(
      type: _type,
      title: title,
      start: start,
      end: end.isAfter(start) ? end : start.add(const Duration(minutes: 30)),
    );

    Navigator.of(context).pop(EditResult(updated: updated));
  }

  void _delete() {
    Navigator.of(context).pop(const EditResult(delete: true));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel =
        '${_day.day.toString().padLeft(2, '0')}/${_day.month.toString().padLeft(2, '0')}/${_day.year}';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Editar bloco', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
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
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text('Data: $dateLabel'),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
