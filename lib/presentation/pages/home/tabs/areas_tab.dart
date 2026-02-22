import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/areas_store.dart';

import '../../../widgets/body_map.dart';
import 'areas/area_balloon.dart';
import 'areas/area_detail_page.dart';
import 'areas/areas_balloon_config.dart';
import 'areas/areas_catalog.dart';
import 'areas/areas_model_assets.dart';
import 'areas/balloon_connector_painter.dart';

class AreasTab extends StatefulWidget {
  const AreasTab({super.key});

  @override
  State<AreasTab> createState() => _AreasTabState();
}

class _AreasTabState extends State<AreasTab> {
  UserSex _sex = UserSex.female; // toggle de teste

  final AreasStore _store = AreasStore();

  void _openArea(
    BuildContext context, {
    required String areaId,
    required String title,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailPage(areaId: areaId, title: title),
      ),
    );
    if (!mounted) return;
    setState(() {}); // atualiza balões ao voltar
  }

  ({String areaId, String title})? _mapHitToArea(String hitId) {
    final key = hitId.trim(); // NÃO precisa lowerCase agora
    switch (key) {
      case 'head':
        return (areaId: 'head', title: 'Cabeça');
      case 'chest':
        return (areaId: 'chest', title: 'Peito');
      case 'abdomen':
        return (areaId: 'abdomen', title: 'Abdômen');
      case 'leftArm':
        return (areaId: 'leftArm', title: 'Braço E');
      case 'rightArm':
        return (areaId: 'rightArm', title: 'Braço D');
      case 'leftLeg':
        return (areaId: 'leftLeg', title: 'Perna E');
      case 'rightLeg':
        return (areaId: 'rightLeg', title: 'Perna D');
      case 'pelvis':
        return (areaId: 'pelvis', title: 'Pelve');
      default:
        return null;
    }
  }

  Color _statusColor(AreaStatus? s, BuildContext context) {
    if (s == null) return Theme.of(context).colorScheme.outlineVariant;
    return switch (s) {
      AreaStatus.otimo => Colors.green,
      AreaStatus.bom => Colors.amber,
      AreaStatus.ruim => Colors.red,
    };
  }

  Future<Map<String, AreaStatus?>> _loadStatuses(
    List<BalloonSpec> specs,
  ) async {
    final map = <String, AreaStatus?>{};
    for (final s in specs) {
      final itemIds = AreasCatalog.itemsFor(s.areaId).map((e) => e.id).toList();
      final status = await _store.overallStatus(s.areaId, itemIds);
      map[s.areaId] = status;
    }
    return map;
  }

  String _subtitleFor(AreaStatus? s) {
    if (s == null) return 'Sem avaliação';
    return switch (s) {
      AreaStatus.otimo => 'Tudo ótimo',
      AreaStatus.bom => 'Indo bem',
      AreaStatus.ruim => 'Precisa de atenção',
    };
  }

  @override
  Widget build(BuildContext context) {
    final base = AreasModelAssets.baseImage(_sex);
    final hitmap = AreasModelAssets.hitmapSvg(_sex);

    final specs = AreasBalloonConfig.specs(_sex);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Toggle de teste (depois liga no onboarding/perfil)
        Row(
          children: [
            Expanded(
              child: SegmentedButton<UserSex>(
                segments: const [
                  ButtonSegment(value: UserSex.female, label: Text('Mulher')),
                  ButtonSegment(value: UserSex.male, label: Text('Homem')),
                ],
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: FutureBuilder<Map<String, AreaStatus?>>(
                future: _loadStatuses(specs),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Erro: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final statusByArea =
                      snap.data ?? const <String, AreaStatus?>{};

                  return LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final h = c.maxHeight;

                      Offset toPx(Offset o) => Offset(o.dx * w, o.dy * h);

                      return Stack(
                        children: [
                          // 1) BodyMap embaixo (desenha a imagem + lê o hitmap)
                          Positioned.fill(
                            child: BodyMap(
                              imageAsset: base,
                              overlaySvgAsset: hitmap,
                              onHit: (hit) {
                                final mapped = _mapHitToArea(hit.id);
                                if (mapped == null) return;
                                _openArea(
                                  context,
                                  areaId: mapped.areaId,
                                  title: mapped.title,
                                );
                              },
                            ),
                          ),

                          // 2) Linhas por cima
                          for (final b in specs)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: BalloonConnectorPainter(
                                  from: toPx(b.from),
                                  to: toPx(b.to),
                                  color: _statusColor(
                                    statusByArea[b.areaId],
                                    context,
                                  ),
                                ),
                              ),
                            ),

                          // 3) Balões por cima (clicáveis)
                          for (final b in specs)
                            Positioned(
                              left: (b.to.dx * w) - (w * b.maxWidthFactor / 2),
                              top: (b.to.dy * h) - 22,
                              width: w * b.maxWidthFactor,
                              child: AreaBalloon(
                                title: b.title,
                                status: statusByArea[b.areaId],
                                subtitle: _subtitleFor(statusByArea[b.areaId]),
                                onTap: () => _openArea(
                                  context,
                                  areaId: b.areaId,
                                  title: b.title,
                                ),
                                maxWidth: w * b.maxWidthFactor,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
