import '../../data/models/timeline_block.dart';

class TimelineStore {
  final List<TimelineBlock> _items = [];

  void add(TimelineBlock block) {
    _items.add(block);
  }

  List<TimelineBlock> itemsForDay(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final d1 = d0.add(const Duration(days: 1));

    final list = _items
        .where((e) =>
            e.start.isAfter(d0.subtract(const Duration(seconds: 1))) &&
            e.start.isBefore(d1))
        .toList();

    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  bool update(TimelineBlock updated) {
    final i = _items.indexWhere((e) => e.id == updated.id);
    if (i == -1) return false;
    _items[i] = updated;
    return true;
  }

  bool removeById(String id) {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    return _items.length != before;
  }
}
