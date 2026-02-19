// lib/presentation/pages/home/tabs/areas/area_detail_page.dart
import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/areas_store.dart';

import 'area_assessment_sheet.dart';
import 'areas_catalog.dart';

class AreaDetailPage extends StatefulWidget {
  const AreaDetailPage({super.key, required this.areaId, required this.title});

  final String areaId;
  final String title;

  @override
  State<AreaDetailPage> createState() => _AreaDetailPageState();
}

class _AreaDetailPageState extends State<AreaDetailPage> {
  final AreasStore _store = AreasStore();

  Color _colorFor(AreaStatus s, BuildContext context) {
    return switch (s) {
      AreaStatus.otimo => Colors.green,
      AreaStatus.bom => Colors.amber,
      AreaStatus.ruim => Colors.red,
    };
  }

  Future<void> _editItem(AreaItemDef item) async {
    final current = await _store.getAssessment(widget.areaId, item.id);

    if (!mounted) return;
    final result = await showModalBottomSheet<AreaAssessmentResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AreaAssessmentSheet(title: item.title, initial: current),
    );

    if (result == null) return;

    if (result.clear) {
      await _store.clearAssessment(widget.areaId, item.id);
    } else {
      await _store.setAssessment(
        widget.areaId,
        item.id,
        status: result.assessment.status,
        reason: result.assessment.reason,
      );
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = AreasCatalog.itemsFor(widget.areaId);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i];

          return FutureBuilder<AreaAssessment?>(
            future: _store.getAssessment(widget.areaId, item.id),
            builder: (context, snap) {
              final assessment = snap.data;

              final status = assessment?.status ?? AreaStatus.bom;
              final dotColor = assessment == null
                  ? Theme.of(context).colorScheme.outline
                  : _colorFor(status, context);

              return Card(
                child: ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(item.title),
                  subtitle:
                      assessment?.status == AreaStatus.ruim &&
                          (assessment?.reason?.isNotEmpty ?? false)
                      ? Text(
                          assessment!.reason!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          assessment == null
                              ? 'Toque para avaliar'
                              : status.label,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editItem(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
