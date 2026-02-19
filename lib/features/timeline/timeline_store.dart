import 'package:vida_app/data/models/timeline_block.dart';

import 'timeline_repository.dart';

class TimelineStore {
  TimelineStore({required TimelineRepository repo}) : _repo = repo;

  final TimelineRepository _repo;
  final List<TimelineBlock> _items = [];

  List<TimelineBlock> get all => List.unmodifiable(_items);

  Future<void> load() async {
    _items
      ..clear()
      ..addAll(await _repo.loadAll());
  }

  Future<void> _persist() async {
    await _repo.saveAll(_items);
  }

  Future<void> add(TimelineBlock block) async {
    _items.add(block);
    await _persist();
  }

  List<TimelineBlock> itemsForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final d1 = d0.add(const Duration(days: 1));

    final list = _items
        .where(
          (e) =>
              e.start.isAfter(d0.subtract(const Duration(seconds: 1))) &&
              e.start.isBefore(d1),
        )
        .toList();

    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  List<TimelineBlock> itemsBetween(DateTime start, DateTime endExclusive) {
    final list = _items
        .where(
          (e) => !e.start.isBefore(start) && e.start.isBefore(endExclusive),
        )
        .toList();

    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  Future<bool> update(TimelineBlock updated) async {
    final i = _items.indexWhere((e) => e.id == updated.id);
    if (i == -1) return false;
    _items[i] = updated;
    await _persist();
    return true;
  }

  Future<bool> removeById(String id) async {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    final changed = _items.length != before;
    if (changed) await _persist();
    return changed;
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
    for (final e in _items) {
      if (excludeId != null && e.id == excludeId) continue;
      if (_overlaps(e, candidate)) return true;
    }
    return false;
  }
}
