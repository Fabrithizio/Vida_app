import 'package:flutter/foundation.dart';

enum TimelineBlockType {
  event,
  goal,
  note,
  study,
  workout,
  health,
  social,
  rest,
}

enum TimelineRepeatType { none, daily, weekly, customWeekdays }

const Object _unset = Object();

@immutable
class TimelineBlock {
  const TimelineBlock({
    required this.id,
    required this.type,
    required this.title,
    required this.start,
    this.end,
    this.notes,
    this.emoji,
    this.isDone = false,
    this.reminderMinutes = 10,
    this.repeatType = TimelineRepeatType.none,
    this.repeatWeekdays = const <int>[],
    this.colorValue,
  });

  final String id;
  final TimelineBlockType type;
  final String title;
  final DateTime start;
  final DateTime? end;

  final String? notes;
  final String? emoji;
  final bool isDone;
  final int reminderMinutes;

  final TimelineRepeatType repeatType;
  final List<int> repeatWeekdays;

  final int? colorValue;

  Duration get duration =>
      (end ?? start.add(const Duration(minutes: 30))).difference(start);

  DateTime get effectiveEnd => end ?? start.add(const Duration(minutes: 30));

  TimelineBlock copyWith({
    TimelineBlockType? type,
    String? title,
    DateTime? start,
    Object? end = _unset,
    Object? notes = _unset,
    Object? emoji = _unset,
    bool? isDone,
    int? reminderMinutes,
    TimelineRepeatType? repeatType,
    List<int>? repeatWeekdays,
    Object? colorValue = _unset,
  }) {
    return TimelineBlock(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end == _unset ? this.end : end as DateTime?,
      notes: notes == _unset ? this.notes : notes as String?,
      emoji: emoji == _unset ? this.emoji : emoji as String?,
      isDone: isDone ?? this.isDone,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      repeatType: repeatType ?? this.repeatType,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      colorValue: colorValue == _unset ? this.colorValue : colorValue as int?,
    );
  }

  bool occursOn(DateTime day) {
    final base = DateTime(start.year, start.month, start.day);
    final target = DateTime(day.year, day.month, day.day);

    if (target.isBefore(base)) return false;

    switch (repeatType) {
      case TimelineRepeatType.none:
        return base == target;
      case TimelineRepeatType.daily:
        return true;
      case TimelineRepeatType.weekly:
        return target.weekday == base.weekday;
      case TimelineRepeatType.customWeekdays:
        return repeatWeekdays.contains(target.weekday);
    }
  }

  TimelineBlock copyForDay(DateTime day) {
    final newStart = DateTime(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    );

    final newEnd = DateTime(
      day.year,
      day.month,
      day.day,
      effectiveEnd.hour,
      effectiveEnd.minute,
    );

    return copyWith(start: newStart, end: newEnd);
  }
}
