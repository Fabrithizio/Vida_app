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
  TimelineRepeatType _repeatType = TimelineRepeatType.none;

  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _emoji = TextEditingController();

  late DateTime _day;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);

  int _reminderMinutes = 10;
  int? _colorValue;
  final Set<int> _weekdays = <int>{};

  static const _colors = <int>[
    0xFF4FC3F7,
    0xFF7E57C2,
    0xFF66BB6A,
    0xFFFF7043,
    0xFF26A69A,
    0xFFEF5350,
  ];

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
    _notes.dispose();
    _emoji.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_day.day.toString().padLeft(2, '0')}/${_day.month.toString().padLeft(2, '0')}/${_day.year}';

  String _weekdayLabel(int w) {
    switch (w) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      default:
        return 'Dom';
    }
  }

  String _typeLabel(TimelineBlockType t) {
    switch (t) {
      case TimelineBlockType.event:
        return 'Evento';
      case TimelineBlockType.goal:
        return 'Meta';
      case TimelineBlockType.note:
        return 'Nota';
      case TimelineBlockType.study:
        return 'Estudo';
      case TimelineBlockType.workout:
        return 'Treino';
      case TimelineBlockType.health:
        return 'Saúde';
      case TimelineBlockType.social:
        return 'Social';
      case TimelineBlockType.rest:
        return 'Descanso';
    }
  }

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

    if (_repeatType == TimelineRepeatType.customWeekdays && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ao menos um dia da semana.')),
      );
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
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      emoji: _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
      reminderMinutes: _reminderMinutes,
      repeatType: _repeatType,
      repeatWeekdays: _weekdays.toList()..sort(),
      colorValue: _colorValue,
    );

    Navigator.of(context).pop(block);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Novo item', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TimelineBlockType.values.map((t) {
                final selected = t == _type;
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
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
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas rápidas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emoji,
              maxLength: 2,
              decoration: const InputDecoration(
                labelText: 'Emoji pequeno (opcional)',
                border: OutlineInputBorder(),
                counterText: '',
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
            DropdownButtonFormField<int>(
              value: _reminderMinutes,
              decoration: const InputDecoration(
                labelText: 'Lembrete',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Sem lembrete')),
                DropdownMenuItem(value: 10, child: Text('10 min antes')),
                DropdownMenuItem(value: 30, child: Text('30 min antes')),
                DropdownMenuItem(value: 60, child: Text('1 hora antes')),
              ],
              onChanged: (v) => setState(() => _reminderMinutes = v ?? 10),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TimelineRepeatType>(
              value: _repeatType,
              decoration: const InputDecoration(
                labelText: 'Repetição',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: TimelineRepeatType.none,
                  child: Text('Não repetir'),
                ),
                DropdownMenuItem(
                  value: TimelineRepeatType.daily,
                  child: Text('Diariamente'),
                ),
                DropdownMenuItem(
                  value: TimelineRepeatType.weekly,
                  child: Text('Semanalmente'),
                ),
                DropdownMenuItem(
                  value: TimelineRepeatType.customWeekdays,
                  child: Text('Dias específicos'),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _repeatType = v ?? TimelineRepeatType.none),
            ),
            if (_repeatType == TimelineRepeatType.customWeekdays) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final weekday = i + 1;
                  final selected = _weekdays.contains(weekday);
                  return FilterChip(
                    label: Text(_weekdayLabel(weekday)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _weekdays.remove(weekday);
                        } else {
                          _weekdays.add(weekday);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: _colors.map((c) {
                  final selected = _colorValue == c;
                  return InkWell(
                    onTap: () => setState(() => _colorValue = c),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 3 : 1.2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }
}
