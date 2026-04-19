// ============================================================================
// FILE: lib/features/home/presentation/tabs/day_tab.dart
//
// O que este arquivo faz:
// - Mantém a Timeline do Meu Dia com os controles de período
// - Mostra a régua de dias da semana
// - Adiciona atalhos compactos para compras, casa, corpo e objetivos
// - Mantém o botão de adicionar por último
// - Usa o módulo corporal para colorir os cards dos dias
// - Mantém compras, tarefas da casa e timeline funcionando
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../data/models/timeline_block.dart';
import '../../../body_care/body_care_service.dart';
import '../../../body_care/presentation/pages/body_care_page.dart';
import '../../../goals/presentation/pages/goals_hub_page.dart';
import '../../../home_tasks/home_tasks_store.dart';
import '../../../notifications/application/notification_service.dart';
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
  final BodyCareService _bodyCare = BodyCareService();

  bool _loading = true;
  TimelineRange _range = TimelineRange.day;
  DateTime _selected = DateTime.now();
  late Future<Map<String, BodyCareEntry>> _weekBodyCareFuture;
  late Future<BodyCareOverview> _bodyOverviewFuture;

  @override
  void initState() {
    super.initState();
    _store = widget.timelineStore;
    _store.addListener(_onStoreChanged);
    _reloadAsyncData();

    Future.microtask(() async {
      await Future.wait([
        _store.load(),
        widget.shoppingStore.load(),
        widget.homeTasksStore.load(),
      ]);
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _reloadAsyncData() {
    _weekBodyCareFuture = _bodyCare.loadRangeMap(_stripDays());
    _bodyOverviewFuture = _bodyCare.loadOverview();
  }

  void _refreshBodyCareUi() {
    if (!mounted) return;
    setState(_reloadAsyncData);
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

  List<DateTime> _stripDays() {
    final base = _dayOnly(_selected);
    return List.generate(7, (i) => base.add(Duration(days: i - 3)));
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
    setState(() {
      _selected = _dayOnly(picked);
      _reloadAsyncData();
    });
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
      _reloadAsyncData();
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
      _reloadAsyncData();
    });
  }

  void _goToday() {
    setState(() {
      _selected = _dayOnly(DateTime.now());
      _reloadAsyncData();
    });
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

  Future<void> _openBodyCare() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BodyCarePage()));
    _refreshBodyCareUi();
  }

  Future<void> _openGoals() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GoalsHubPage()));
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
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EditBlockSheet(block: block),
    );
    if (result == null) return;
    if (result.delete == true) {
      await _store.removeById(block.id);
      return;
    }
    final TimelineBlock? updated = result.updated as TimelineBlock?;
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

  Color _bodyLevelColor(int? value) {
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
    required BodyCareEntry? entry,
  }) {
    final foodColor = _bodyLevelColor(entry?.food);
    final trainingColor = _bodyLevelColor(entry?.training);
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
                    Colors.black.withValues(alpha: selected ? 0.22 : 0.34),
                    Colors.black.withValues(alpha: selected ? 0.34 : 0.50),
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
    final days = _stripDays();
    return FutureBuilder<Map<String, BodyCareEntry>>(
      future: _weekBodyCareFuture,
      builder: (context, snapshot) {
        final map = snapshot.data ?? const <String, BodyCareEntry>{};
        return SizedBox(
          height: 88,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = _dayOnly(days[i]);
              final selected = d == _dayOnly(_selected);
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selected = d),
                child: _buildDayStatusCard(
                  day: d,
                  selected: selected,
                  entry: map[_bodyCare.keyForDay(d)],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsRow() {
    return FutureBuilder<BodyCareOverview>(
      future: _bodyOverviewFuture,
      builder: (context, snapshot) {
        final overview = snapshot.data ?? BodyCareOverview.empty();

        Widget actionTile({
          required String label,
          required IconData icon,
          required VoidCallback onTap,
          Color? accent,
          String? badge,
          bool highlighted = false,
        }) {
          final color = accent ?? Colors.white70;
          final tileWidth = highlighted ? 82.0 : 72.0;
          final tileHeight = highlighted ? 72.0 : 68.0;
          final iconSize = highlighted ? 18.0 : 16.0;
          final orbSize = highlighted ? 32.0 : 28.0;

          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: tileWidth,
              height: tileHeight,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: highlighted
                      ? [const Color(0xFF2B1240), const Color(0xFF160A24)]
                      : [
                          color.withValues(alpha: 0.14),
                          color.withValues(alpha: 0.04),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: highlighted
                      ? color.withValues(alpha: 0.42)
                      : color.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: highlighted ? 0.16 : 0.08),
                    blurRadius: highlighted ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: orbSize,
                          height: orbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(
                                  alpha: highlighted ? 0.94 : 0.86,
                                ),
                                color.withValues(
                                  alpha: highlighted ? 0.68 : 0.54,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Icon(icon, size: iconSize, color: Colors.white),
                        if (badge != null && badge.isNotEmpty)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.50),
                                ),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 6.2,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: highlighted ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: highlighted ? 8.2 : 8.0,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final streakLabel = overview.currentStreak > 0
            ? '${overview.currentStreak}d'
            : null;

        return SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            children: [
              actionTile(
                label: 'Compras',
                icon: Icons.shopping_cart_outlined,
                onTap: _openShopping,
                accent: const Color(0xFF60A5FA),
              ),
              const SizedBox(width: 8),
              actionTile(
                label: 'Casa',
                icon: Icons.home_rounded,
                onTap: _openHomeTasks,
                accent: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              actionTile(
                label: 'Corpo em dia',
                icon: Icons.fitness_center_rounded,
                onTap: _openBodyCare,
                accent: const Color(0xFFA855F7),
                badge: streakLabel,
                highlighted: true,
              ),
              const SizedBox(width: 8),
              actionTile(
                label: 'Objetivos',
                icon: Icons.flag_rounded,
                onTap: _openGoals,
                accent: const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              actionTile(
                label: 'Adicionar',
                icon: Icons.add_circle_outline,
                onTap: _addBlock,
                accent: const Color(0xFF22C55E),
              ),
            ],
          ),
        );
      },
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
              child: SegmentedButton<TimelineRange>(
                segments: const [
                  ButtonSegment(value: TimelineRange.day, label: Text('Dia')),
                  ButtonSegment(
                    value: TimelineRange.week,
                    label: Text('Semana'),
                  ),
                  ButtonSegment(value: TimelineRange.month, label: Text('Mês')),
                  ButtonSegment(value: TimelineRange.year, label: Text('Ano')),
                ],
                selected: {_range},
                onSelectionChanged: (s) {
                  setState(() => _range = s.first);
                },
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
            if (_range == TimelineRange.day) ...[
              _dateStrip(),
              _buildQuickActionsRow(),
            ],
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
