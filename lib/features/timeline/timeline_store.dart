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
        .where((e) => e.start.isAfter(d0.subtract(const Duration(seconds: 1))) && e.start.isBefore(d1))
        .toList();

    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }
}
