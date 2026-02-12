import 'package:flutter/foundation.dart';

enum TimelineBlockType { event, goal, note }

@immutable
class TimelineBlock {
  const TimelineBlock({
    required this.id,
    required this.type,
    required this.title,
    required this.start,
    this.end,
    
  });

  final String id;
  final TimelineBlockType type;
  final String title;
  final DateTime start;
  final DateTime? end;

  TimelineBlock copyWith({
  TimelineBlockType? type,
  String? title,
  DateTime? start,
  DateTime? end,
}) {
  return TimelineBlock(
    id: id,
    type: type ?? this.type,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
  );
}

}
