// ============================================================================
// FILE: lib/features/timeline/timeline_store.dart
//
// O que faz:
// - mantém os blocos da timeline em memória
// - salva no repositório
// - agenda/cancela notificações dos blocos
//
// Melhoria de desempenho:
// - load() não reagenda todas as notificações de novo
// - agendamento fica só nas operações que realmente mudam os blocos
// ============================================================================

import 'package:flutter/foundation.dart';

import '../../data/models/timeline_block.dart';
import '../notifications/application/notification_service.dart';
import 'timeline_repository.dart';

class TimelineStore extends ChangeNotifier {
  TimelineStore({required TimelineRepository repo}) : _repo = repo;

  final TimelineRepository _repo;
  final List<TimelineBlock> _items = [];

  List<TimelineBlock> get all => List.unmodifiable(_items);

  Future<void> load() async {
    final loaded = await _repo.loadAll();

    _items
      ..clear()
      ..addAll(loaded);

    notifyListeners();
  }

  Future<void> _persist() async {
    await _repo.saveAll(_items);
  }

  Future<void> _rescheduleBlock(TimelineBlock block) async {
    await NotificationService.instance.cancelForBlock(block.id);
    await NotificationService.instance.scheduleForBlock(block);
  }

  Future<void> add(TimelineBlock block) async {
    _items.add(block);
    await _persist();
    await _rescheduleBlock(block);
    notifyListeners();
  }

  Future<void> update(TimelineBlock updated) async {
    final index = _items.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    _items[index] = updated;
    await _persist();
    await _rescheduleBlock(updated);
    notifyListeners();
  }

  Future<void> toggleDone(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final item = _items[index];
    _items[index] = item.copyWith(isDone: !item.isDone);
    await _persist();
    notifyListeners();
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
    await NotificationService.instance.cancelForBlock(id);
    notifyListeners();
  }

  DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  TimelineBlock _occurrenceForDay(TimelineBlock base, DateTime day) {
    return base.repeatType == TimelineRepeatType.none
        ? base
        : base.copyForDay(day);
  }

  List<TimelineBlock> itemsForDay(DateTime day) {
    final target = _d(day);
    final list = _items
        .where((e) => e.occursOn(target))
        .map((e) => _occurrenceForDay(e, target))
        .toList();

    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  List<TimelineBlock> itemsBetween(DateTime start, DateTime endExclusive) {
    final out = <TimelineBlock>[];
    var cursor = _d(start);
    final endDay = _d(endExclusive);

    while (cursor.isBefore(endDay)) {
      out.addAll(itemsForDay(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }

    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  DateTime _endOrDefault(TimelineBlock b) =>
      b.end ?? b.start.add(const Duration(minutes: 30));

  bool _overlaps(TimelineBlock a, TimelineBlock b) {
    final aStart = a.start;
    final aEnd = _endOrDefault(a);
    final bStart = b.start;
    final bEnd = _endOrDefault(b);

    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  bool hasConflict(TimelineBlock candidate, {String? excludeId}) {
    final dayItems = itemsForDay(candidate.start);

    for (final entry in dayItems) {
      if (excludeId != null && entry.id == excludeId) continue;
      if (_overlaps(entry, candidate)) return true;
    }

    return false;
  }
}
