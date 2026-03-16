// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/area_detail_page.dart
//
// Detalhe da macroárea (Painel de Vida):
// - Remove imports "package:vida_app" (nome antigo) -> usa imports relativos
// - Mostra status geral da macroárea no topo (ótimo/bom/ruim ou "sem dados")
// - Lista subitens (AreasCatalog) e permite avaliar via AreaAssessmentSheet
// - Não assume "bom" quando não tem avaliação (antes isso mascarava o estado)
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../../data/models/area_assessment.dart';
import '../../../../../data/models/area_status.dart';
import '../../../../../features/areas/areas_store.dart';

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

  Color _colorFor(AreaStatus s) {
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
      backgroundColor: const Color(0xFF0F0F1A),
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
    final def = AreasCatalog.byId(widget.areaId);
    final items = def.items;
    final bg = const Color(0xFF0F0F1A);

    return FutureBuilder<AreaStatus?>(
      future: _store.overallStatus(
        widget.areaId,
        items.map((e) => e.id).toList(),
      ),
      builder: (context, overallSnap) {
        final overall = overallSnap.data;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(widget.title),
          ),
          body: Column(
            children: [
              // Header da macroárea (status geral + explicação)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (overall == null)
                            ? Colors.white10
                            : _colorFor(overall).withValues(alpha: 0.18),
                        border: Border.all(
                          color: (overall == null)
                              ? Colors.white24
                              : _colorFor(overall).withValues(alpha: 0.55),
                        ),
                      ),
                      child: Icon(
                        def.icon,
                        color: overall == null
                            ? Colors.white70
                            : _colorFor(overall),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            def.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            overall == null
                                ? 'Sem avaliações ainda — toque nos itens para começar.'
                                : 'Status geral: ${overall.label}',
                            style: TextStyle(
                              color: overall == null
                                  ? Colors.white60
                                  : _colorFor(overall).withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            def.subtitle,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de subitens
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = items[i];

                    return FutureBuilder<AreaAssessment?>(
                      future: _store.getAssessment(widget.areaId, item.id),
                      builder: (context, snap) {
                        final assessment = snap.data;

                        final dotColor = assessment == null
                            ? Colors.white24
                            : _colorFor(assessment.status);

                        final subtitleText = assessment == null
                            ? 'Toque para avaliar'
                            : (assessment.status == AreaStatus.ruim &&
                                  (assessment.reason?.isNotEmpty ?? false))
                            ? assessment.reason!
                            : assessment.status.label;

                        return Card(
                          color: bg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white12),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: assessment == null
                                    ? Colors.white60
                                    : Colors.white70,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white30,
                            ),
                            onTap: () => _editItem(item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
