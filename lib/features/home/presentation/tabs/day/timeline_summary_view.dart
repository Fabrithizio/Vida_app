import 'package:flutter/material.dart';

import '../../../../../data/models/timeline_block.dart';

class TimelineSummaryView extends StatelessWidget {
  const TimelineSummaryView({
    super.key,
    required this.title,
    required this.items,
    required this.onTapItem,
  });

  final String title;
  final List<TimelineBlock> items;
  final ValueChanged<TimelineBlock> onTapItem;

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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('$title: nenhum item'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemBuilder: (context, i) {
        final b = items[i];
        final end = b.end ?? b.start.add(const Duration(minutes: 30));

        final start =
            '${b.start.day.toString().padLeft(2, '0')}/${b.start.month.toString().padLeft(2, '0')} '
            '${b.start.hour.toString().padLeft(2, '0')}:${b.start.minute.toString().padLeft(2, '0')}';

        final endText =
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

        return Material(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            leading: Icon(_iconForType(b.type)),
            title: Text(
              '${b.emoji ?? ''} ${b.title}'.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$start → $endText'
              '${(b.notes ?? '').trim().isEmpty ? '' : '\n${b.notes}'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              b.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: b.isDone ? Colors.greenAccent : Colors.white54,
            ),
            onTap: () => onTapItem(b),
          ),
        );
      },
    );
  }
}
