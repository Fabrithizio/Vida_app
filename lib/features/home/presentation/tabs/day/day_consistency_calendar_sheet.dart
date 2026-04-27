// ============================================================================
// FILE: lib/features/home/presentation/tabs/day/day_consistency_calendar_sheet.dart
//
// O que faz:
// - Mostra o calendário bonito de constância do Meu Dia
// - Resume streak atual, melhor streak, proteções e ritmo recente
// - Permite trocar a data selecionada sem abrir o date picker padrão
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/timeline/application/day_consistency_service.dart';

class DayConsistencyCalendarSheet extends StatefulWidget {
  const DayConsistencyCalendarSheet({
    super.key,
    required this.initialSelectedDay,
    required this.summary,
  });

  final DateTime initialSelectedDay;
  final DayConsistencySummary summary;

  @override
  State<DayConsistencyCalendarSheet> createState() =>
      _DayConsistencyCalendarSheetState();
}

class _DayConsistencyCalendarSheetState
    extends State<DayConsistencyCalendarSheet> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dayOnly(widget.initialSelectedDay);
    _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, DayConsistencyEntry> get _entryMap {
    return {for (final entry in widget.summary.entries) _key(entry.day): entry};
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _goMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  List<DateTime> _calendarCells() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekday = firstDay.weekday;
    final startOffset = firstWeekday - DateTime.monday;
    final start = firstDay.subtract(Duration(days: startOffset));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }

  Color _levelColor(DayConsistencyLevel? level) {
    switch (level) {
      case DayConsistencyLevel.strong:
        return const Color(0xFF22C55E);
      case DayConsistencyLevel.good:
        return const Color(0xFFF59E0B);
      case DayConsistencyLevel.light:
        return const Color(0xFF60A5FA);
      case DayConsistencyLevel.empty:
      case null:
        return const Color(0xFF334155);
    }
  }

  String _monthLabel(DateTime d) {
    const months = [
      '',
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${months[d.month]} de ${d.year}';
  }

  String _rateLabel(double rate) {
    return '${(rate * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final cells = _calendarCells();
    final today = _dayOnly(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white12),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.12),
                      Colors.blue.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Constância do Meu Dia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Aqui você vê ritmo, sequência e proteção da sua constância recente.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryChip(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Sequência',
                          value: '${widget.summary.currentStreak} dias',
                          color: const Color(0xFFF59E0B),
                        ),
                        _summaryChip(
                          icon: Icons.emoji_events_rounded,
                          label: 'Recorde',
                          value: '${widget.summary.bestStreak} dias',
                          color: const Color(0xFF22C55E),
                        ),
                        _summaryChip(
                          icon: Icons.shield_rounded,
                          label: 'Proteções',
                          value: '${widget.summary.availableProtections}',
                          color: const Color(0xFF60A5FA),
                        ),
                        _summaryChip(
                          icon: Icons.insights_rounded,
                          label: '14 dias',
                          value: _rateLabel(widget.summary.goodRate14),
                          color: const Color(0xFFA78BFA),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _goMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _monthLabel(_visibleMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _goMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Seg',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Ter',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Qua',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Qui',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Sex',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Sáb',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Dom',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (_, index) {
                  final day = cells[index];
                  final inMonth = day.month == _visibleMonth.month;
                  final isSelected = _dayOnly(day) == _selectedDay;
                  final isToday = _dayOnly(day) == today;
                  final entry = _entryMap[_key(day)];
                  final color = _levelColor(entry?.level);

                  return InkWell(
                    onTap: () => setState(() => _selectedDay = _dayOnly(day)),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: inMonth ? 0.16 : 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : isToday
                              ? color.withValues(alpha: 0.85)
                              : Colors.white12,
                          width: isSelected ? 1.4 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.20),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: inMonth ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: 4,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _SelectedDayCard(
                day: _selectedDay,
                entry: _entryMap[_key(_selectedDay)],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _LegendChip(label: 'Vazio', color: Color(0xFF334155)),
                  _LegendChip(label: 'Leve', color: Color(0xFF60A5FA)),
                  _LegendChip(label: 'Bom', color: Color(0xFFF59E0B)),
                  _LegendChip(label: 'Forte', color: Color(0xFF22C55E)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDay),
                  child: const Text('Usar esta data'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({required this.day, required this.entry});

  final DateTime day;
  final DayConsistencyEntry? entry;

  String _weekday(DateTime d) {
    const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return names[d.weekday - 1];
  }

  String _month(int month) {
    const names = [
      '',
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return names[month];
  }

  String _levelLabel(DayConsistencyLevel? level) {
    switch (level) {
      case DayConsistencyLevel.strong:
        return 'Forte';
      case DayConsistencyLevel.good:
        return 'Bom';
      case DayConsistencyLevel.light:
        return 'Leve';
      case DayConsistencyLevel.empty:
      case null:
        return 'Vazio';
    }
  }

  Color _levelColor(DayConsistencyLevel? level) {
    switch (level) {
      case DayConsistencyLevel.strong:
        return const Color(0xFF22C55E);
      case DayConsistencyLevel.good:
        return const Color(0xFFF59E0B);
      case DayConsistencyLevel.light:
        return const Color(0xFF60A5FA);
      case DayConsistencyLevel.empty:
      case null:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(entry?.level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_weekday(day)}, ${day.day.toString().padLeft(2, '0')} de ${_month(day.month)} de ${day.year}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.30)),
                ),
                child: Text(
                  _levelLabel(entry?.level),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Score: ${entry?.score ?? 0}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Corpo: ${entry?.bodyPoints ?? 0} • Treino: ${entry?.trainingPoints ?? 0} • Timeline: ${entry?.timelinePoints ?? 0} • Check-in: ${entry?.checkinPoints ?? 0}',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
