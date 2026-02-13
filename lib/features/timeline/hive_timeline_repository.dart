import 'package:hive_flutter/hive_flutter.dart';
import 'package:vida_app/data/models/timeline_block.dart';

import 'timeline_repository.dart';

class HiveTimelineRepository implements TimelineRepository {
  static const _boxName = 'timeline_box';
  static const _key = 'items';

  Future<Box<dynamic>> _open() async {
    return Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<List<TimelineBlock>> loadAll() async {
    final box = await _open();
    final raw = box.get(_key);

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((m) => _fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<void> saveAll(List<TimelineBlock> items) async {
    final box = await _open();
    final raw = items.map(_toMap).toList();
    await box.put(_key, raw);
  }

  Map<String, dynamic> _toMap(TimelineBlock b) {
    return {
      'id': b.id,
      'type': b.type.name,
      'title': b.title,
      'start': b.start.toIso8601String(),
      'end': b.end?.toIso8601String(),
    };
  }

  TimelineBlock _fromMap(Map<String, dynamic> m) {
    return TimelineBlock(
      id: m['id'] as String,
      type: TimelineBlockType.values.byName(m['type'] as String),
      title: m['title'] as String,
      start: DateTime.parse(m['start'] as String),
      end: m['end'] == null ? null : DateTime.parse(m['end'] as String),
    );
  }
}
