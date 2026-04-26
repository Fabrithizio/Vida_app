// ============================================================================
// FILE: lib/features/areas/presentation/pages/area_detail_page.dart
//
// O que faz:
// - Mostra os detalhes de uma área do Areas
// - Exibe as subáreas com visual mais agradável
// - Abre o modal de detalhe de cada subárea
//
// Ajustes desta versão:
// - remove os círculos repetidos das subáreas
// - adiciona ícones próprios por subárea
// - melhora o topo do modal de detalhe sem poluir
// - mantém o botão de atualizar check-up
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/bootstrap/areas_bootstrap_service.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/areas/presentation/areas_catalog.dart';
import 'package:vida_app/features/areas/presentation/pages/area_detail_explainer_panel.dart';
import 'package:vida_app/features/areas/presentation/widgets/area_status_dot.dart';

class AreaDetailPage extends StatefulWidget {
  const AreaDetailPage({
    super.key,
    required this.areaId,
    required this.title,
    this.initialItemId,
  });

  final String areaId;
  final String title;
  final String? initialItemId;

  @override
  State<AreaDetailPage> createState() => _AreaDetailPageState();
}

class _AreaDetailPageState extends State<AreaDetailPage> {
  final AreasStore _store = AreasStore();
  final AreasBootstrapService _bootstrap = AreasBootstrapService();
  late Future<bool> _includeWomenCycleFuture;
  bool _didAutoOpenInitialItem = false;

  @override
  void initState() {
    super.initState();
    _includeWomenCycleFuture = _loadIncludeWomenCycle();
    _bootstrap.ensureBootstrappedFromOnboarding().then((_) {
      if (mounted) setState(() {});
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
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _scoreLabel(int? score) => score == null ? '—' : '$score';

  String _scoreClass(int? score) {
    if (score == null) return 'Sem dados';
    if (score >= 80) return 'Ótimo';
    if (score >= 60) return 'Bom';
    if (score >= 40) return 'Médio';
    if (score >= 20) return 'Ruim';
    return 'Crítico';
  }

  Color _scoreColor(int? score) {
    if (score == null) return const Color(0xFF94A3B8);
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 60) return const Color(0xFFF59E0B);
    if (score >= 40) return const Color(0xFFFB923C);
    if (score >= 20) return const Color(0xFFEF4444);
    return const Color(0xFFB91C1C);
  }

  Color _sourceColor(AreaDataSource source) {
    switch (source) {
      case AreaDataSource.manual:
        return const Color(0xFF7DD3FC);
      case AreaDataSource.onboarding:
        return const Color(0xFFC4B5FD);
      case AreaDataSource.dailyQuestions:
        return const Color(0xFFFF7AD9);
      case AreaDataSource.automatic:
        return const Color(0xFF4ADE80);
      case AreaDataSource.estimated:
        return const Color(0xFFFBBF24);
      case AreaDataSource.mixed:
        return const Color(0xFF60A5FA);
      case AreaDataSource.unknown:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _sourceIcon(AreaDataSource source) {
    switch (source) {
      case AreaDataSource.manual:
        return Icons.edit_rounded;
      case AreaDataSource.onboarding:
        return Icons.flag_rounded;
      case AreaDataSource.dailyQuestions:
        return Icons.quiz_rounded;
      case AreaDataSource.automatic:
        return Icons.auto_awesome_rounded;
      case AreaDataSource.estimated:
        return Icons.analytics_rounded;
      case AreaDataSource.mixed:
        return Icons.hub_rounded;
      case AreaDataSource.unknown:
        return Icons.help_outline_rounded;
    }
  }

  AreaStatus _statusFromScore(int? score) {
    if (score == null) return AreaStatus.noData;
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
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

  IconData _itemIcon(String itemId) {
    switch (itemId) {
      case 'energy':
        return Icons.bolt_rounded;
      case 'sleep':
        return Icons.nightlight_round_rounded;
      case 'movement':
        return Icons.directions_run_rounded;
      case 'nutrition':
        return Icons.restaurant_rounded;
      case 'hydration':
        return Icons.water_drop_rounded;
      case 'checkups':
        return Icons.medical_services_rounded;
      case 'imc':
      case 'bmi':
        return Icons.monitor_weight_rounded;
      case 'digital_night_use':
        return Icons.bedtime_rounded;
      case 'focus':
        return Icons.center_focus_strong_rounded;
      case 'constancy':
        return Icons.track_changes_rounded;
      case 'planning':
        return Icons.event_note_rounded;
      case 'progress':
        return Icons.trending_up_rounded;
      case 'social_connection':
        return Icons.people_alt_rounded;
      case 'affective_bond':
        return Icons.favorite_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
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
    final scoreColor = _statusColor(status);
    final sourceColor = _sourceColor(a?.source ?? AreaDataSource.unknown);
    final itemIcon = _itemIcon(item.id);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scoreColor.withValues(alpha: 0.26),
                              scoreColor.withValues(alpha: 0.10),
                            ],
                          ),
                          border: Border.all(
                            color: scoreColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(itemIcon, color: scoreColor, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scoreColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _scoreClass(a?.score),
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        label: 'Score',
                        value:
                            '${_scoreLabel(a?.score)} · ${_scoreClass(a?.score)}',
                        color: scoreColor,
                        icon: Icons.stacked_bar_chart_rounded,
                      ),
                      _InfoChip(
                        label: 'Fonte',
                        value: a != null ? _sourceLabel(a.source) : '—',
                        color: sourceColor,
                        icon: _sourceIcon(a?.source ?? AreaDataSource.unknown),
                      ),
                      if (trend != null && trend.trim().isNotEmpty)
                        _InfoChip(
                          label: 'Tendência',
                          value: trend,
                          color: const Color(0xFF60A5FA),
                          icon: Icons.trending_up_rounded,
                        ),
                      _InfoChip(
                        label: 'Atualizado',
                        value: _formatDate(a?.lastUpdatedAt),
                        color: const Color(0xFFF59E0B),
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (a != null)
                    AreaDetailExplainerPanel(
                      assessment: a,
                      title: 'Como essa subárea está sendo lida',
                    ),
                  if (area.id == 'body_health' && item.id == 'checkups') ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                          Navigator.of(sheetContext).pop();
                          setState(() {});
                        },
                        icon: const Icon(Icons.event_available_rounded),
                        label: const Text('Atualizar data do check-up'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  void _maybeAutoOpenInitialItem(AreaDef def, List<AreaItemDef> items) {
    if (_didAutoOpenInitialItem) return;
    final initialItemId = widget.initialItemId?.trim();
    if (initialItemId == null || initialItemId.isEmpty) return;
    AreaItemDef? item;
    for (final candidate in items) {
      if (candidate.id == initialItemId) {
        item = candidate;
        break;
      }
    }
    if (item == null) return;
    _didAutoOpenInitialItem = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final assessment = await _store.getComputedAssessment(def.id, item!.id);
      if (!mounted) return;
      await _openItemDetails(def, item!, assessment);
    });
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
        _maybeAutoOpenInitialItem(def, items);

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
                        final sourceColor = _sourceColor(
                          a?.source ?? AreaDataSource.unknown,
                        );
                        final reason = (a?.reason ?? '').trim();
                        final scoreClass = _scoreClass(a?.score);
                        final itemIcon = _itemIcon(item.id);

                        return InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _openItemDetails(def, item, a),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.14),
                                  const Color(0xFF0F0F1A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: color.withValues(alpha: 0.26),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        color.withValues(alpha: 0.22),
                                        color.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Icon(itemIcon, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
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
                                                fontWeight: FontWeight.w900,
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
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        reason.isEmpty
                                            ? item.description
                                            : reason,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _MiniPill(
                                            text: scoreClass,
                                            color: color,
                                            icon: Icons.bolt_rounded,
                                          ),
                                          _MiniPill(
                                            text: a != null
                                                ? _sourceLabel(a.source)
                                                : 'Sem fonte',
                                            color: sourceColor,
                                            icon: _sourceIcon(
                                              a?.source ??
                                                  AreaDataSource.unknown,
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
  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Column(
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
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
