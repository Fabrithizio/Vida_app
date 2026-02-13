import 'package:flutter/material.dart';
import 'package:vida_app/data/models/timeline_block.dart';

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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text('$title: nenhum item'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = items[i];
        final start =
            '${b.start.day.toString().padLeft(2, '0')}/${b.start.month.toString().padLeft(2, '0')} '
            '${b.start.hour.toString().padLeft(2, '0')}:${b.start.minute.toString().padLeft(2, '0')}';

        final icon = switch (b.type) {
          TimelineBlockType.event => Icons.event_outlined,
          TimelineBlockType.goal => Icons.flag_outlined,
          TimelineBlockType.note => Icons.note_outlined,
        };

        return ListTile(
          leading: Icon(icon),
          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(start),
          onTap: () => onTapItem(b),
        );
      },
    );
  }
}
