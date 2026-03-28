// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/area_detail_page.dart
//
// O que faz:
// - Mostra os detalhes de uma área sem mudar o layout principal
// - Lista as subáreas válidas para o perfil atual
// - Exibe score, status, fonte, tendência e última atualização
// - Abre um painel com explicação objetiva de como cada subárea está sendo lida
//
// Correções desta versão:
// - Mantém a arquitetura original do projeto
// - Remove a divergência entre o score geral exibido e o status geral do topo
// - O topo agora deriva o status diretamente do SCORE da área
// - remove a dependência do overallStatus legado, que estava conflitando com a régua nova
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late Future<bool> _includeWomenCycleFuture;

  @override
  void initState() {
    super.initState();
    _includeWomenCycleFuture = _loadIncludeWomenCycle();
    _store.ensureBootstrappedFromOnboarding().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<bool> _loadIncludeWomenCycle() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    final raw = (prefs.getString('${user.uid}:gender') ?? '')
        .trim()
        .toLowerCase();
    return raw.contains('mulher') || raw.contains('femin');
  }

  Color _statusColor(AreaStatus s) => s.color;

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

  String _scoreClass(int? score) {
    if (score == null) return 'Sem dados';
    if (score >= 85) return 'Ótimo';
    if (score >= 68) return 'Bom';
    if (score >= 45) return 'Médio';
    if (score >= 25) return 'Ruim';
    return 'Crítico';
  }

  Color _scoreColor(int? score) {
    if (score == null) return const Color(0xFF94A3B8);
    if (score >= 85) return const Color(0xFF22C55E);
    if (score >= 68) return const Color(0xFFF59E0B);
    if (score >= 45) return const Color(0xFFFB923C);
    if (score >= 25) return const Color(0xFFEF4444);
    return const Color(0xFFB91C1C);
  }

  AreaStatus _statusFromScore(int? score) {
    if (score == null) return AreaStatus.noData;
    if (score >= 85) return AreaStatus.excellent;
    if (score >= 68) return AreaStatus.good;
    if (score >= 45) return AreaStatus.attention;
    return AreaStatus.critical;
  }

  String _sourceLabel(AreaDataSource source) {
    switch (source) {
      case AreaDataSource.manual:
        return 'Manual';
      case AreaDataSource.onboarding:
        return 'Onboarding';
      case AreaDataSource.dailyQuestions:
        return 'Perguntas diárias';
      case AreaDataSource.automatic:
        return 'Automático';
      case AreaDataSource.estimated:
        return 'Estimado';
      case AreaDataSource.mixed:
        return 'Misto';
      case AreaDataSource.unknown:
        return 'Desconhecida';
    }
  }

  Future<int?> _areaScore(AreaDef def, bool includeWomenCycle) {
    final items = AreasCatalog.itemsForArea(
      def.id,
      includeWomenCycle: includeWomenCycle,
    );
    return _store.score(def.id, items.map((e) => e.id).toList());
  }

  String _buildExplanation(AreaAssessment? assessment) {
    if (assessment == null || assessment.status == AreaStatus.noData) {
      return 'Ainda não há dados suficientes para essa subárea. Conforme você responder check-ins, registrar eventos ou usar as partes ligadas do app, essa leitura fica mais confiável.';
    }

    final parts = <String>[];
    final reason = (assessment.reason ?? '').trim();
    final details = (assessment.details ?? '').trim();
    final action = (assessment.recommendedAction ?? '').trim();

    if (reason.isNotEmpty) parts.add(reason);
    if (details.isNotEmpty) parts.add(details);
    if (action.isNotEmpty) parts.add('Próximo passo: $action');

    return parts.isEmpty
        ? 'Status calculado com base nos dados disponíveis.'
        : parts.join('\n\n');
  }

  Future<void> _openItemDetails(
    AreaDef area,
    AreaItemDef item,
    AreaAssessment? assessment,
  ) async {
    final a =
        assessment ?? await _store.getComputedAssessment(area.id, item.id);
    final trend = await _store.trendLabel(area.id, item.id);

    if (!mounted) return;

    final status = a?.status ?? AreaStatus.noData;
    final color = _statusColor(status);

    final navigator = Navigator.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
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
                        _scoreClass(a?.score),
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
                    _InfoChip(
                      label: 'Score',
                      value:
                          '${_scoreLabel(a?.score)} · ${_scoreClass(a?.score)}',
                    ),
                    _InfoChip(
                      label: 'Fonte',
                      value: a != null ? _sourceLabel(a.source) : '—',
                    ),
                    if (trend != null && trend.trim().isNotEmpty)
                      _InfoChip(label: 'Tendência', value: trend),
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
                          context: sheetContext,
                          initialDate: now,
                          firstDate: DateTime(now.year - 20),
                          lastDate: now,
                        );
                        if (picked == null) return;

                        await _store.updateLastCheckupDate(picked);
                        if (!mounted) return;
                        setState(() {});
                        navigator.pop();
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
                    onPressed: () => navigator.pop(),
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

    return FutureBuilder<bool>(
      future: _includeWomenCycleFuture,
      builder: (context, sexSnap) {
        final includeWomenCycle = sexSnap.data ?? true;
        final items = AreasCatalog.itemsForArea(
          def.id,
          includeWomenCycle: includeWomenCycle,
        );

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(widget.title),
          ),
          body: FutureBuilder<int?>(
            future: _areaScore(def, includeWomenCycle),
            builder: (context, scoreSnap) {
              final overallScore = scoreSnap.data;
              final overallStatus = _statusFromScore(overallScore);
              final overallColor = _scoreColor(overallScore);

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
                                  Text(
                                    _scoreClass(overallScore),
                                    style: const TextStyle(
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
                                    'Status geral: ${_scoreClass(overallScore)}',
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
                  ...items.map((item) {
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
                                          const SizedBox(width: 8),
                                          Text(
                                            _scoreLabel(a?.score),
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        a?.reason ?? item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _MiniPill(
                                            text: _scoreClass(a?.score),
                                            color: color,
                                          ),
                                          _MiniPill(
                                            text: a != null
                                                ? _sourceLabel(a.source)
                                                : 'Sem fonte',
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
