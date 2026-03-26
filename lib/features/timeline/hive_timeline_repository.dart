import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vida_app/data/models/timeline_block.dart';

import 'timeline_repository.dart';

class HiveTimelineRepository implements TimelineRepository {
  static const _boxPrefix = 'timeline_box_';
  static const _key = 'items';

  String _uidOrAnon() {
    final u = FirebaseAuth.instance.currentUser;
    return (u?.uid ?? 'anon').trim().isEmpty ? 'anon' : u!.uid;
  }

  Future<Box> _open() async {
    return Hive.openBox('$_boxPrefix${_uidOrAnon()}');
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
    await box.put(_key, items.map(_toMap).toList());
  }

  Map<String, dynamic> _toMap(TimelineBlock b) {
    return {
      'id': b.id,
      'type': b.type.name,
      'title': b.title,
      'start': b.start.toIso8601String(),
      'end': b.end?.toIso8601String(),
      'notes': b.notes,
      'emoji': b.emoji,
      'isDone': b.isDone,
      'reminderMinutes': b.reminderMinutes,
      'repeatType': b.repeatType.name,
      'repeatWeekdays': b.repeatWeekdays,
      'colorValue': b.colorValue,
    };
  }

  TimelineBlock _fromMap(Map<String, dynamic> m) {
    return TimelineBlock(
      id: m['id'] as String,
      type: TimelineBlockType.values.byName(m['type'] as String),
      title: m['title'] as String,
      start: DateTime.parse(m['start'] as String),
      end: m['end'] == null ? null : DateTime.parse(m['end'] as String),
      notes: m['notes'] as String?,
      emoji: m['emoji'] as String?,
      isDone: (m['isDone'] as bool?) ?? false,
      reminderMinutes: (m['reminderMinutes'] as int?) ?? 10,
      repeatType: TimelineRepeatType.values.byName(
        (m['repeatType'] as String?) ?? TimelineRepeatType.none.name,
      ),
      repeatWeekdays:
          (m['repeatWeekdays'] as List?)?.whereType<int>().toList() ??
          const <int>[],
      colorValue: m['colorValue'] as int?,
    );
  }
}
