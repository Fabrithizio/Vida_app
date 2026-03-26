// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/area_detail_page.dart
//
// O que faz:
// - Mostra os detalhes de uma área
// - Lista as subáreas
// - Exibe status, score, motivo, fonte, ação sugerida e última atualização
// - Mostra um resumo melhor da área no topo
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/area_status_dot.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';

class AreaDetailPage extends StatefulWidget {
  const AreaDetailPage({super.key, required this.areaId, required this.title});

  final String areaId;
  final String title;

  @override
  State<AreaDetailPage> createState() => _AreaDetailPageState();
}

class _AreaDetailPageState extends State<AreaDetailPage> {
  final AreasStore _store = AreasStore();

  @override
  void initState() {
    super.initState();
    _store.ensureBootstrappedFromOnboarding().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _statusTitle(AreaStatus s) {
    switch (s) {
      case AreaStatus.excellent:
        return 'Ótimo';
      case AreaStatus.good:
        return 'Bom';
      case AreaStatus.attention:
        return 'Atenção';
      case AreaStatus.critical:
        return 'Crítico';
      case AreaStatus.noData:
        return 'Sem dados';
    }
  }

  Color _statusColor(AreaStatus s) {
    switch (s) {
      case AreaStatus.excellent:
        return const Color(0xFF22C55E);
      case AreaStatus.good:
        return const Color(0xFFF59E0B);
      case AreaStatus.attention:
        return const Color(0xFFFB923C);
      case AreaStatus.critical:
        return const Color(0xFFEF4444);
      case AreaStatus.noData:
        return const Color(0xFF94A3B8);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _scoreLabel(int? score) {
    if (score == null) return '—';
    return '$score';
  }

  String _buildExplanation(AreaAssessment? a) {
    if (a == null || a.status == AreaStatus.noData) {
      return 'Ainda não há dados suficientes para essa subárea. Conforme você responder o check-in, registrar informações ou usar outras partes do app, essa leitura ficará mais completa.';
    }

    final parts = <String>[];

    final reason = (a.reason ?? '').trim();
    final details = (a.details ?? '').trim();
    final action = (a.recommendedAction ?? '').trim();

    if (reason.isNotEmpty) {
      parts.add(reason);
    }

    if (details.isNotEmpty) {
      parts.add(details);
    }

    if (action.isNotEmpty) {
      parts.add('Próximo passo: $action');
    }

    if (parts.isEmpty) {
      return 'Status calculado com base nos dados disponíveis.';
    }

    return parts.join('\n\n');
  }

  Future<int?> _areaScore(AreaDef def) async {
    return _store.score(def.id, def.items.map((e) => e.id).toList());
  }

  Future<AreaStatus?> _areaOverallStatus(AreaDef def) async {
    return _store.overallStatus(def.id, def.items.map((e) => e.id).toList());
  }

  Future<void> _openItemDetails(
    AreaDef area,
    AreaItemDef item,
    AreaAssessment? assessment,
  ) async {
    final a =
        assessment ?? await _store.getComputedAssessment(area.id, item.id);
    if (!mounted) return;

    final status = a?.status ?? AreaStatus.noData;
    final color = _statusColor(status);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AreaStatusDot(status: status, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _statusTitle(status),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(label: 'Score', value: _scoreLabel(a?.score)),
                    _InfoChip(label: 'Fonte', value: a?.source.label ?? '—'),
                    _InfoChip(
                      label: 'Atualizado',
                      value: _formatDate(a?.lastUpdatedAt),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if ((a?.recommendedAction ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Ação sugerida',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a!.recommendedAction!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Explicação',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _buildExplanation(a),
                  style: const TextStyle(color: Colors.white70, height: 1.38),
                ),
                const SizedBox(height: 16),
                if (area.id == 'body_health' && item.id == 'checkups') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(now.year - 20),
                          lastDate: now,
                        );
                        if (picked == null) return;

                        await _store.updateLastCheckupDate(picked);

                        if (!mounted) return;
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                      child: const Text('Atualizar data do check-up'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = AreasCatalog.byId(widget.areaId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: FutureBuilder<int?>(
        future: _areaScore(def),
        builder: (context, scoreSnap) {
          return FutureBuilder<AreaStatus?>(
            future: _areaOverallStatus(def),
            builder: (context, statusSnap) {
              final overallStatus = statusSnap.data ?? AreaStatus.noData;
              final overallColor = _statusColor(overallStatus);
              final overallScore = scoreSnap.data;

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          overallColor.withValues(alpha: 0.18),
                          const Color(0xFF0F0F1A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: overallColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white10,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Icon(def.icon, color: Colors.white),
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
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    def.subtitle,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: overallColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: overallColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _scoreLabel(overallScore),
                                    style: TextStyle(
                                      color: overallColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Score',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                def.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  AreaStatusDot(
                                    status: overallStatus,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Status geral: ${_statusTitle(overallStatus)}',
                                    style: TextStyle(
                                      color: overallColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Subáreas',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...def.items.map((item) {
                    return FutureBuilder<AreaAssessment?>(
                      future: _store.getComputedAssessment(def.id, item.id),
                      builder: (context, snap) {
                        final a = snap.data;
                        final status = a?.status ?? AreaStatus.noData;
                        final color = _statusColor(status);

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openItemDetails(def, item, a),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F0F1A),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: color.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AreaStatusDot(status: status, size: 14),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _statusTitle(status),
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        (a?.reason ?? item.description),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MiniMetaChip(
                                            text:
                                                'Score ${_scoreLabel(a?.score)}',
                                          ),
                                          _MiniMetaChip(
                                            text:
                                                a?.source.label ?? 'Sem fonte',
                                          ),
                                          _MiniMetaChip(
                                            text: _formatDate(a?.lastUpdatedAt),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniMetaChip extends StatelessWidget {
  const _MiniMetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
