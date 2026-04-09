import 'package:flutter/material.dart';

import '../../../../data/models/timeline_block.dart';
import '../../../notifications/application/notification_service.dart';
import '../../../areas/daily_checkin_service.dart';
import '../../../home_tasks/home_tasks_store.dart';
import '../../../shopping/shopping_list_store.dart';
import '../../../timeline/timeline_store.dart';
import 'day/create_block_sheet.dart';
import 'day/edit_block_sheet.dart';
import 'day/timeline_day_view.dart';
import 'day/timeline_summary_view.dart';
import 'home_tasks_sheet.dart';
import 'shopping_list_sheet.dart';

enum TimelineRange { day, week, month, year }

class DayTab extends StatefulWidget {
  const DayTab({
    super.key,
    required this.shoppingStore,
    required this.timelineStore,
    required this.homeTasksStore,
  });

  final ShoppingListStore shoppingStore;
  final TimelineStore timelineStore;
  final HomeTasksStore homeTasksStore;

  @override
  State<DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<DayTab> {
  late final TimelineStore _store;
  final DailyCheckinService _dailyCheckinService = DailyCheckinService();
  bool _loading = true;
  TimelineRange _range = TimelineRange.day;
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    _store = widget.timelineStore;
    _store.addListener(_onStoreChanged);

    Future.microtask(() async {
      await _store.load();
      await widget.shoppingStore.load();
      await widget.homeTasksStore.load();
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final day = _dayOnly(d);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
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

  String _monthName(int month) {
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

  String _fullDateLabel(DateTime d) {
    return '${_weekdayName(d.weekday)}, ${d.day.toString().padLeft(2, '0')} de ${_monthName(d.month)} de ${d.year}';
  }

  Future<void> _pickVisibleDay() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecionar data',
      confirmText: 'OK',
      cancelText: 'Cancelar',
    );

    if (picked == null || !mounted) return;
    setState(() => _selected = _dayOnly(picked));
  }

  void _goPrev() {
    setState(() {
      _selected = switch (_range) {
        TimelineRange.day => _selected.subtract(const Duration(days: 1)),
        TimelineRange.week => _selected.subtract(const Duration(days: 7)),
        TimelineRange.month => DateTime(
          _selected.year,
          _selected.month - 1,
          _selected.day,
        ),
        TimelineRange.year => DateTime(
          _selected.year - 1,
          _selected.month,
          _selected.day,
        ),
      };
    });
  }

  void _goNext() {
    setState(() {
      _selected = switch (_range) {
        TimelineRange.day => _selected.add(const Duration(days: 1)),
        TimelineRange.week => _selected.add(const Duration(days: 7)),
        TimelineRange.month => DateTime(
          _selected.year,
          _selected.month + 1,
          _selected.day,
        ),
        TimelineRange.year => DateTime(
          _selected.year + 1,
          _selected.month,
          _selected.day,
        ),
      };
    });
  }

  void _goToday() {
    setState(() => _selected = _dayOnly(DateTime.now()));
  }

  Future<void> _openShopping() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ShoppingListSheet(store: widget.shoppingStore),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openHomeTasks() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => HomeTasksSheet(store: widget.homeTasksStore),
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
    await NotificationService.instance.scheduleForBlock(created);

    if (!mounted) return;
    setState(() => _selected = _dayOnly(created.start));
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
      if (!mounted) return;
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

    if (!mounted) return;
    setState(() => _selected = _dayOnly(updated.start));
  }

  Future<void> _toggleDone(TimelineBlock block) async {
    await _store.toggleDone(block.id);
  }

  Future<void> _updateByDrag(TimelineBlock updated) async {
    if (_store.hasConflict(updated, excludeId: updated.id)) return;
    await _store.update(updated);
  }

  List<TimelineBlock> _itemsForRange() {
    final sel = _dayOnly(_selected);

    switch (_range) {
      case TimelineRange.day:
        return _store.itemsForDay(sel);
      case TimelineRange.week:
        final start = _startOfWeek(sel);
        final end = start.add(const Duration(days: 7));
        return _store.itemsBetween(start, end);
      case TimelineRange.month:
        final start = DateTime(sel.year, sel.month, 1);
        final end = DateTime(sel.year, sel.month + 1, 1);
        return _store.itemsBetween(start, end);
      case TimelineRange.year:
        final start = DateTime(sel.year, 1, 1);
        final end = DateTime(sel.year + 1, 1, 1);
        return _store.itemsBetween(start, end);
    }
  }

  DateTime _sessionDayForLifeDay(DateTime d) =>
      _dayOnly(d).add(const Duration(days: 1));

  Future<_BodyCareDaySnapshot> _bodyCareSnapshotForLifeDay(DateTime d) async {
    final sessionDay = _sessionDayForLifeDay(d);
    final food = await _dailyCheckinService.getFoodAnswerForSessionDay(
      sessionDay,
    );
    final training = await _dailyCheckinService.getTrainingAnswerForSessionDay(
      sessionDay,
    );
    return _BodyCareDaySnapshot(food: food, training: training);
  }

  Color _bodyCareColor(int? value) {
    switch (value) {
      case 4:
        return const Color(0xFF22C55E);
      case 3:
        return const Color(0xFF84CC16);
      case 2:
        return const Color(0xFFF59E0B);
      case 1:
        return const Color(0xFFF97316);
      case 0:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF334155);
    }
  }

  Widget _buildDayStatusCard({
    required DateTime day,
    required bool selected,
    required _BodyCareDaySnapshot snapshot,
  }) {
    final foodColor = _bodyCareColor(snapshot.food);
    final trainingColor = _bodyCareColor(snapshot.training);
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)
        : Colors.white12;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomCenter,
                          colors: [
                            foodColor.withValues(alpha: 0.78),
                            foodColor.withValues(alpha: 0.26),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomCenter,
                          colors: [
                            trainingColor.withValues(alpha: 0.78),
                            trainingColor.withValues(alpha: 0.26),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: selected ? 0.24 : 0.34),
                    Colors.black.withValues(alpha: selected ? 0.34 : 0.48),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Icon(Icons.restaurant_rounded, size: 10, color: foodColor),
                    const Spacer(),
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 10,
                      color: trainingColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _weekdayName(day.weekday),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day.day.toString().padLeft(2, '0'),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _monthName(day.month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateStrip() {
    final base = _dayOnly(_selected);
    final days = List.generate(7, (i) => base.add(Duration(days: i - 3)));

    return SizedBox(
      height: 94,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = days[i];
          final selected = _dayOnly(d) == _dayOnly(_selected);

          return FutureBuilder<_BodyCareDaySnapshot>(
            future: _bodyCareSnapshotForLifeDay(d),
            builder: (context, snapshot) {
              final data = snapshot.data ?? const _BodyCareDaySnapshot();

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selected = d),
                child: _buildDayStatusCard(
                  day: d,
                  selected: selected,
                  snapshot: data,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _legend() {
    Widget chip(String label, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Evento', Icons.event_outlined, Colors.blueAccent),
          const SizedBox(width: 8),
          chip('Estudo', Icons.menu_book_outlined, Colors.purpleAccent),
          const SizedBox(width: 8),
          chip('Treino', Icons.fitness_center_outlined, Colors.greenAccent),
          const SizedBox(width: 8),
          chip('Saúde', Icons.health_and_safety_outlined, Colors.redAccent),
          const SizedBox(width: 8),
          chip('Social', Icons.people_alt_outlined, Colors.orangeAccent),
          const SizedBox(width: 8),
          chip('Descanso', Icons.nightlight_outlined, Colors.tealAccent),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
                      onSelectionChanged: (s) {
                        setState(() => _range = s.first);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Lista de compras',
                    onPressed: _openShopping,
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                  IconButton(
                    tooltip: 'Casa & organização',
                    onPressed: _openHomeTasks,
                    icon: const Icon(Icons.home_repair_service_outlined),
                  ),
                  IconButton(
                    tooltip: 'Adicionar',
                    onPressed: _addBlock,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goPrev,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickVisibleDay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fullDateLabel(_selected),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _range == TimelineRange.day
                                  ? 'Timeline do dia'
                                  : 'Resumo por ${_range.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _goNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: _goToday,
                    child: const Text('Hoje'),
                  ),
                ],
              ),
            ),
            if (_range == TimelineRange.day) _dateStrip(),
            _legend(),
            Expanded(
              child: _range == TimelineRange.day
                  ? TimelineDayView(
                      key: ValueKey(
                        '${_selected.toIso8601String()}_${items.length}',
                      ),
                      day: _selected,
                      items: items,
                      onTapBlock: _openEditBlock,
                      onToggleDone: _toggleDone,
                      onChangedByDrag: _updateByDrag,
                    )
                  : TimelineSummaryView(
                      items: items,
                      title: _range.name,
                      onTapItem: _openEditBlock,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyCareDaySnapshot {
  const _BodyCareDaySnapshot({this.food, this.training});

  final int? food;
  final int? training;
}
