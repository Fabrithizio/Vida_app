import 'package:flutter/foundation.dart';

import '../../data/models/timeline_block.dart';
import '../../services/notifications/notification_service.dart';
import 'timeline_repository.dart';

class TimelineStore extends ChangeNotifier {
  TimelineStore({required TimelineRepository repo}) : _repo = repo;

  final TimelineRepository _repo;
  final List<TimelineBlock> _items = [];

  List<TimelineBlock> get all => List.unmodifiable(_items);

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _repo.loadAll());

    for (final b in _items) {
      await NotificationService.instance.scheduleForBlock(b);
    }

    notifyListeners();
  }

  Future<void> _persist() async {
    await _repo.saveAll(_items);
  }

  Future<void> add(TimelineBlock block) async {
    _items.add(block);
    await _persist();
    await NotificationService.instance.scheduleForBlock(block);
    notifyListeners();
  }

  Future<void> update(TimelineBlock updated) async {
    final i = _items.indexWhere((e) => e.id == updated.id);
    if (i == -1) return;

    _items[i] = updated;
    await _persist();
    await NotificationService.instance.cancelForBlock(updated.id);
    await NotificationService.instance.scheduleForBlock(updated);
    notifyListeners();
  }

  Future<void> toggleDone(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;

    final item = _items[i];
    _items[i] = item.copyWith(isDone: !item.isDone);

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

    DateTime cursor = _d(start);
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

    for (final e in dayItems) {
      if (excludeId != null && e.id == excludeId) continue;
      if (_overlaps(e, candidate)) return true;
    }
    return false;
  }
}
