// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas_tab.dart
//
// Painel de Vida (Life Dashboard):
// - Usa imagem de fundo: assets/images/life_dashboard_bg.png
// - Overlay escuro + vinheta para manter contraste
// - Mantém glow e layout das orbes
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/areas/areas_store.dart';

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

  late Future<UserSex> _sexFuture;
  late Future<Map<String, int?>> _scoreFuture;

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

  Future<void> _openArea(String areaId) async {
    final def = AreasCatalog.byId(areaId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailPage(areaId: areaId, title: def.title),
      ),
    );

    final sex = await _sexFuture;
    if (!mounted) return;
    setState(() => _scoreFuture = _loadScores(sex));
  }

  @override
  Widget build(BuildContext context) {
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

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;

                final centerX = w / 2;
                final centerY = h * 0.43;

                final slotH = (h * 0.62).clamp(340.0, 760.0);
                final slotW = (w * 0.58).clamp(240.0, 460.0);

                return Stack(
                  children: [
                    // ✅ Imagem de fundo
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/life_dashboard_bg.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) {
                          // fallback se o asset ainda não existir
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF0A0A12), Colors.black],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ✅ Overlay escuro para contraste
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ),

                    // Glow suave atrás do personagem
                    Positioned(
                      left: centerX - (slotW * 0.70),
                      top: centerY - (slotH * 0.55),
                      width: slotW * 1.40,
                      height: slotH * 1.10,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF3B82F6).withValues(alpha: 0.14),
                                const Color(0xFF22C55E).withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Vinheta leve
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.1),
                              radius: 1.05,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Personagem (crop/scale)
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

                    // Orbes
                    for (final spec in specs)
                      _BalloonPositioned(
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

class _BalloonPositioned extends StatelessWidget {
  const _BalloonPositioned({
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

    final maxWidth = (screenW * spec.maxWidthFactor).clamp(150.0, 270.0);
    const height = 66.0;

    final x = spec.to.dx * screenW;
    final y = spec.to.dy * screenH;

    return Positioned(
      left: x - (maxWidth / 2),
      top: y - (height / 2),
      width: maxWidth,
      height: height,
      child: AreaBalloon(
        title: def.titleShort,
        subtitle: def.subtitle,
        icon: def.icon,
        score: score,
        onTap: onTap,
      ),
    );
  }
}
