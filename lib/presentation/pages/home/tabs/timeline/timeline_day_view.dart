import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../data/models/timeline_block.dart';

class TimelineDayView extends StatelessWidget {
  const TimelineDayView({
    super.key,
    required this.items,
    required this.onTapBlock,
  });

  final List<TimelineBlock> items;
  final ValueChanged<TimelineBlock> onTapBlock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final height = c.maxHeight;
        final hourHeight = math.max(36.0, height / 24);

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
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final b in items)
                    _BlockPositioned(
                      block: b,
                      hourHeight: hourHeight,
                      onTap: () => onTapBlock(b),
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
    required this.hourHeight,
    required this.onTap,
  });

  final TimelineBlock block;
  final double hourHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final startMinutes = block.start.hour * 60 + block.start.minute;
    final top = (startMinutes / 60.0) * hourHeight;

    final end = block.end ?? block.start.add(const Duration(minutes: 30));
    final endMinutes = end.hour * 60 + end.minute;

    final durMinutes = (endMinutes - startMinutes).clamp(15, 24 * 60);
    final height = math.max(56.0, (durMinutes / 60.0) * hourHeight);

    final icon = switch (block.type) {
      TimelineBlockType.event => Icons.event_outlined,
      TimelineBlockType.goal => Icons.flag_outlined,
      TimelineBlockType.note => Icons.note_outlined,
    };

    final startText =
        '${block.start.hour.toString().padLeft(2, '0')}:${block.start.minute.toString().padLeft(2, '0')}';
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    return Positioned(
      left: 64,
      right: 8,
      top: top,
      height: height,
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$startText → $endText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
