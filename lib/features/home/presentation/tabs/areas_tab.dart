// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas_tab.dart
//
// Layout novo (sem “caixa preta” do rodapé):
// - Personagem em cima
// - 9 cards pequenos organizados em grid no rodapé (40%)
// - Sem painel/container grande atrás dos itens
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../areas/areas_store.dart';

import 'areas/area_balloon.dart';
import 'areas/area_detail_page.dart';
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
    final defs = AreasCatalog.all();
    final map = <String, int?>{};
    for (final def in defs) {
      map[def.id] = await _store.score(
        def.id,
        def.items.map((e) => e.id).toList(),
      );
    }
    return map;
  }

  Future<void> _refresh() async {
    final sex = await _sexFuture;
    if (!mounted) return;
    setState(() => _scoreFuture = _loadScores(sex));
  }

  Future<void> _openArea(String areaId) async {
    final def = AreasCatalog.byId(areaId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailPage(areaId: areaId, title: def.title),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final defs = AreasCatalog.all(); // ordem fixa

    return FutureBuilder<UserSex>(
      future: _sexFuture,
      builder: (context, sexSnap) {
        final sex = sexSnap.data ?? UserSex.female;
        final character = AreasModelAssets.character(sex);

        return FutureBuilder<Map<String, int?>>(
          future: _scoreFuture,
          builder: (context, scoreSnap) {
            final scores = scoreSnap.data ?? const <String, int?>{};

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;

                // Área inferior só para layout (sem caixa)
                final bottomH = h * 0.40;
                final topH = h - bottomH;

                // Avatar maior e central em cima
                final avatarW = (w * 0.70).clamp(260.0, 520.0);
                final avatarH = (topH * 0.92).clamp(240.0, 680.0);

                return Stack(
                  children: [
                    // Fundo
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/life_dashboard_bg.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.black),
                      ),
                    ),

                    // Overlay leve (sem “caixa”)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.22),
                        ),
                      ),
                    ),

                    // Personagem (topo)
                    Positioned(
                      left: (w - avatarW) / 2,
                      top: 28,
                      width: avatarW,
                      height: avatarH,
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

                    // Grid dos 9 itens (SEM painel)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      height: bottomH - 10,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: defs.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                // ✅ boxes menores (mais compactos) sem encolher o ícone
                                childAspectRatio: 1.25,
                              ),
                          itemBuilder: (context, i) {
                            final def = defs[i];
                            final score = scores[def.id];

                            return AreaBalloon(
                              icon: def.icon,
                              score: score,
                              onTap: () => _openArea(def.id),
                            );
                          },
                        ),
                      ),
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
