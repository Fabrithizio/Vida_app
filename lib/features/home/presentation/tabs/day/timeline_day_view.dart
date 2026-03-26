import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../data/models/timeline_block.dart';

class TimelineDayView extends StatelessWidget {
  const TimelineDayView({
    super.key,
    required this.day,
    required this.items,
    required this.onTapBlock,
    required this.onToggleDone,
    required this.onChangedByDrag,
  });

  final DateTime day;
  final List<TimelineBlock> items;
  final ValueChanged<TimelineBlock> onTapBlock;
  final ValueChanged<TimelineBlock> onToggleDone;
  final ValueChanged<TimelineBlock> onChangedByDrag;

  IconData _iconForType(TimelineBlockType t) {
    switch (t) {
      case TimelineBlockType.event:
        return Icons.event_outlined;
      case TimelineBlockType.goal:
        return Icons.flag_outlined;
      case TimelineBlockType.note:
        return Icons.note_outlined;
      case TimelineBlockType.study:
        return Icons.menu_book_outlined;
      case TimelineBlockType.workout:
        return Icons.fitness_center_outlined;
      case TimelineBlockType.health:
        return Icons.health_and_safety_outlined;
      case TimelineBlockType.social:
        return Icons.people_alt_outlined;
      case TimelineBlockType.rest:
        return Icons.nightlight_outlined;
    }
  }

  Color _colorForType(TimelineBlock block) {
    if (block.colorValue != null) return Color(block.colorValue!);

    switch (block.type) {
      case TimelineBlockType.event:
        return Colors.blueAccent;
      case TimelineBlockType.goal:
        return Colors.amberAccent;
      case TimelineBlockType.note:
        return Colors.grey;
      case TimelineBlockType.study:
        return Colors.purpleAccent;
      case TimelineBlockType.workout:
        return Colors.greenAccent;
      case TimelineBlockType.health:
        return Colors.redAccent;
      case TimelineBlockType.social:
        return Colors.orangeAccent;
      case TimelineBlockType.rest:
        return Colors.tealAccent;
    }
  }

  Set<String> _conflictIds(List<TimelineBlock> list) {
    final ids = <String>{};

    DateTime endOrDefault(TimelineBlock b) =>
        b.end ?? b.start.add(const Duration(minutes: 30));

    bool overlaps(TimelineBlock a, TimelineBlock b) {
      return a.start.isBefore(endOrDefault(b)) &&
          b.start.isBefore(endOrDefault(a));
    }

    for (int i = 0; i < list.length; i++) {
      for (int j = i + 1; j < list.length; j++) {
        if (overlaps(list[i], list[j])) {
          ids.add(list[i].id);
          ids.add(list[j].id);
        }
      }
    }

    return ids;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = c.maxHeight;
        final hourHeight = math.max(56.0, height / 16.0);
        final conflicts = _conflictIds(items);

        final now = DateTime.now();
        final sameDay = _isSameDay(now, day);
        final nowTop = ((now.hour * 60 + now.minute) / 60.0) * hourHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            child: SizedBox(
              height: hourHeight * 24,
              child: Stack(
                children: [
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 24,
                    itemBuilder: (_, h) => SizedBox(
                      height: hourHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (sameDay)
                    Positioned(
                      left: 56,
                      right: 0,
                      top: nowTop,
                      child: IgnorePointer(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Agora',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Divider(
                                color: Colors.redAccent,
                                thickness: 1.5,
                                height: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  for (final b in items)
                    _BlockPositioned(
                      block: b,
                      icon: _iconForType(b.type),
                      color: _colorForType(b),
                      conflict: conflicts.contains(b.id),
                      hourHeight: hourHeight,
                      onTap: () => onTapBlock(b),
                      onToggleDone: () => onToggleDone(b),
                      onChangedByDrag: onChangedByDrag,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlockPositioned extends StatelessWidget {
  const _BlockPositioned({
    required this.block,
    required this.icon,
    required this.color,
    required this.conflict,
    required this.hourHeight,
    required this.onTap,
    required this.onToggleDone,
    required this.onChangedByDrag,
  });

  final TimelineBlock block;
  final IconData icon;
  final Color color;
  final bool conflict;
  final double hourHeight;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final ValueChanged<TimelineBlock> onChangedByDrag;

  DateTime _endOrDefault(TimelineBlock b) =>
      b.end ?? b.start.add(const Duration(minutes: 30));

  TimelineBlock _shiftByMinutes(TimelineBlock b, int minutes) {
    return b.copyWith(
      start: b.start.add(Duration(minutes: minutes)),
      end: _endOrDefault(b).add(Duration(minutes: minutes)),
    );
  }

  TimelineBlock _resizeBottomByMinutes(TimelineBlock b, int minutes) {
    final newEnd = _endOrDefault(b).add(Duration(minutes: minutes));
    final minEnd = b.start.add(const Duration(minutes: 15));
    return b.copyWith(end: newEnd.isAfter(minEnd) ? newEnd : minEnd);
  }

  @override
  Widget build(BuildContext context) {
    final startMinutes = block.start.hour * 60 + block.start.minute;
    final top = (startMinutes / 60.0) * hourHeight;

    final end = _endOrDefault(block);
    final endMinutes = end.hour * 60 + end.minute;
    final durMinutes = (endMinutes - startMinutes).clamp(15, 24 * 60);

    final visualHeight = math.max(54.0, (durMinutes / 60.0) * hourHeight);

    final isTiny = visualHeight < 72;
    final isSmall = visualHeight < 92;

    final startText =
        '${block.start.hour.toString().padLeft(2, '0')}:${block.start.minute.toString().padLeft(2, '0')}';
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    return Positioned(
      left: 64,
      right: 8,
      top: top,
      height: visualHeight,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          final vy = d.primaryVelocity ?? 0;
          if (vy.abs() < 60) return;
          final minutes = vy > 0 ? 15 : -15;
          onChangedByDrag(_shiftByMinutes(block, minutes));
        },
        child: Material(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: block.isDone ? 0.10 : 0.16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: conflict
                      ? Colors.redAccent
                      : color.withValues(alpha: 0.42),
                  width: conflict ? 1.8 : 1.2,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (d) {
                          final vy = d.primaryVelocity ?? 0;
                          if (vy.abs() < 60) return;
                          final minutes = vy > 0 ? 15 : -15;
                          onChangedByDrag(
                            _resizeBottomByMinutes(block, minutes),
                          );
                        },
                        child: Container(
                          width: 42,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      10,
                      isTiny ? 12 : 14,
                      10,
                      isTiny ? 6 : 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: onToggleDone,
                          borderRadius: BorderRadius.circular(999),
                          child: Icon(
                            block.isDone
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: isTiny ? 18 : 20,
                            color: block.isDone
                                ? Colors.greenAccent
                                : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(icon, size: isTiny ? 16 : 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: isTiny
                              ? _TinyBlockContent(
                                  title: block.title,
                                  emoji: block.emoji,
                                  startText: startText,
                                  endText: endText,
                                  done: block.isDone,
                                )
                              : _NormalBlockContent(
                                  title: block.title,
                                  emoji: block.emoji,
                                  notes: block.notes,
                                  startText: startText,
                                  endText: endText,
                                  conflict: conflict,
                                  done: block.isDone,
                                  compact: isSmall,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyBlockContent extends StatelessWidget {
  const _TinyBlockContent({
    required this.title,
    required this.emoji,
    required this.startText,
    required this.endText,
    required this.done,
  });

  final String title;
  final String? emoji;
  final String startText;
  final String endText;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${emoji ?? ''} $title'.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$startText - $endText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _NormalBlockContent extends StatelessWidget {
  const _NormalBlockContent({
    required this.title,
    required this.emoji,
    required this.notes,
    required this.startText,
    required this.endText,
    required this.conflict,
    required this.done,
    required this.compact,
  });

  final String title;
  final String? emoji;
  final String? notes;
  final String startText;
  final String endText;
  final bool conflict;
  final bool done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${emoji ?? ''} $title'.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$startText - $endText',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white70),
        ),
        if (!compact && (notes ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            notes!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white60),
          ),
        ],
        if (conflict && !compact) ...[
          const SizedBox(height: 3),
          const Text(
            'Conflito de horário',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
