// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas_tab.dart
//
// Correções:
// 1) Check-in obrigatório SOMENTE na aba Áreas (continua aqui)
// 2) Orbes atualizam cor imediatamente:
//    - Recarrega scores ao voltar do detalhe
//    - Recarrega scores ao concluir check-in obrigatório
// 3) Botão do HUD abre sheet de check-in VISUALIZÁVEL e FECHA tocando fora
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/areas/areas_store.dart';
import '../../../../features/areas/daily_checkin_service.dart';

import 'areas/daily_checkin_overlay.dart';
import 'areas/daily_checkin_sheet.dart';
import 'areas/area_balloon.dart';
import 'areas/area_detail_page.dart';
import 'areas/areas_balloon_config.dart';
import 'areas/areas_catalog.dart';
import 'areas/areas_model_assets.dart';

class AreasTab extends StatefulWidget {
  const AreasTab({super.key});

  @override
  State<AreasTab> createState() => _AreasTabState();
}

class _AreasTabState extends State<AreasTab> {
  final AreasStore _store = AreasStore();
  final DailyCheckinService _checkin = DailyCheckinService();

  late Future<UserSex> _sexFuture;
  late Future<Map<String, int?>> _scoreFuture;

  bool _checkinPrompted = false;

  @override
  void initState() {
    super.initState();
    _sexFuture = _loadUserSex();
    _scoreFuture = _loadScores(UserSex.female);
  }

  Future<UserSex> _loadUserSex() async {
    final prefs = await SharedPreferences.getInstance();
    final gender = (prefs.getString('gender') ?? '').toLowerCase().trim();
    if (gender.contains('homem')) return UserSex.male;
    if (gender.contains('mulher')) return UserSex.female;
    return UserSex.female;
  }

  Future<Map<String, int?>> _loadScores(UserSex sex) async {
    final specs = AreasBalloonConfig.specs(sex);
    final map = <String, int?>{};
    for (final s in specs) {
      final def = AreasCatalog.byId(s.areaId);
      map[s.areaId] = await _store.score(
        s.areaId,
        def.items.map((e) => e.id).toList(),
      );
    }
    return map;
  }

  Future<void> _refreshScores() async {
    final sex = await _sexFuture;
    if (!mounted) return;
    setState(() => _scoreFuture = _loadScores(sex));
  }

  int? _overallAverage(Map<String, int?> scores) {
    final vals = scores.values.whereType<int>().toList();
    if (vals.isEmpty) return null;
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    return avg.round().clamp(0, 100);
  }

  Future<void> _ensureDailyCheckin() async {
    if (_checkinPrompted) return;
    _checkinPrompted = true;

    // ✅ obrigatório só aqui (aba Áreas)
    final done = await _checkin.isCompleted(DateTime.now());
    if (!mounted) return;
    if (done) return;

    final finished = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DailyCheckinOverlay(),
    );

    // ✅ atualiza imediatamente quando terminar
    if (finished == true) {
      await _refreshScores();
    }
  }

  Future<void> _openArea(String areaId) async {
    final def = AreasCatalog.byId(areaId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailPage(areaId: areaId, title: def.title),
      ),
    );

    // ✅ ao voltar do detalhe, atualiza cores imediatamente
    await _refreshScores();
  }

  Future<void> _openCheckinSheet() async {
    // ✅ visualizável e fecha tocando fora
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1A),
      showDragHandle: true,
      builder: (_) => const DailyCheckinSheet(),
    );

    // Se respondeu algo dentro do sheet, pode influenciar score no futuro.
    await _refreshScores();
  }

  @override
  Widget build(BuildContext context) {
    // dispara overlay uma vez ao entrar na aba
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDailyCheckin());

    return FutureBuilder<UserSex>(
      future: _sexFuture,
      builder: (context, sexSnap) {
        final sex = sexSnap.data ?? UserSex.female;
        final specs = AreasBalloonConfig.specs(sex);
        final character = AreasModelAssets.character(sex);

        return FutureBuilder<Map<String, int?>>(
          future: _scoreFuture,
          builder: (context, scoreSnap) {
            final scores = scoreSnap.data ?? const <String, int?>{};
            final overall = _overallAverage(scores);

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;

                final centerX = w / 2;
                final centerY = h * 0.50;

                final slotH = (h * 0.56).clamp(320.0, 740.0);
                final slotW = (w * 0.58).clamp(240.0, 460.0);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/life_dashboard_bg.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 12,
                      right: 12,
                      top: 10,
                      child: _HudBar(
                        overall: overall,
                        onCheckin: _openCheckinSheet,
                      ),
                    ),

                    Positioned(
                      left: centerX - (slotW / 2),
                      top: centerY - (slotH / 2),
                      width: slotW,
                      height: slotH,
                      child: IgnorePointer(
                        child: ClipRect(
                          child: Align(
                            alignment: character.alignment,
                            widthFactor: character.cropWidthFactor,
                            heightFactor: character.cropHeightFactor,
                            child: Transform.scale(
                              scale: character.scale,
                              child: Image.asset(
                                character.path,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) =>
                                    const Center(child: Icon(Icons.person)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    for (final spec in specs)
                      _OrbPositioned(
                        spec: spec,
                        screenW: w,
                        screenH: h,
                        score: scores[spec.areaId],
                        onTap: () => _openArea(spec.areaId),
                      ),

                    if (scoreSnap.connectionState == ConnectionState.waiting)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Center(
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OrbPositioned extends StatelessWidget {
  const _OrbPositioned({
    required this.spec,
    required this.screenW,
    required this.screenH,
    required this.score,
    required this.onTap,
  });

  final BalloonSpec spec;
  final double screenW;
  final double screenH;
  final int? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final def = AreasCatalog.byId(spec.areaId);

    final size = (screenW * 0.16).clamp(56.0, 74.0);
    final x = spec.to.dx * screenW;
    final y = spec.to.dy * screenH;

    return Positioned(
      left: x - (size / 2),
      top: y - (size / 2),
      width: size,
      height: size,
      child: AreaBalloon(icon: def.icon, score: score, onTap: onTap),
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({required this.overall, required this.onCheckin});

  final int? overall;
  final VoidCallback onCheckin;

  Color _c() {
    final s = overall;
    if (s == null) return Colors.white24;
    if (s >= 70) return Colors.green;
    if (s >= 40) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final c = _c();
    final text = overall == null ? '--' : overall.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.14),
              border: Border.all(color: c.withValues(alpha: 0.45)),
            ),
            child: Icon(Icons.insights, color: c, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Painel de Vida',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withValues(alpha: 0.45)),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Check-in',
            onPressed: onCheckin,
            icon: const Icon(Icons.checklist),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
