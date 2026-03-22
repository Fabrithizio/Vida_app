// ============================================================================
// AREAS TAB (FIX REAL - overflow + grid colado)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/features/areas/areas_store.dart';

import 'package:vida_app/features/home/presentation/tabs/areas/area_detail_page.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_model_assets.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/daily_checkin_sheet.dart';

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
    final gender = (prefs.getString('gender') ?? '').toLowerCase();
    if (gender.contains('homem')) return UserSex.male;
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

  double _averageScore(Map<String, int?> scores) {
    final valid = scores.values.whereType<int>().toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  void _openCheckin() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const DailyCheckinSheet(),
    );
  }

  Future<void> _openArea(String areaId) async {
    final def = AreasCatalog.byId(areaId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AreaDetailPage(areaId: areaId, title: def.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defs = AreasCatalog.all();

    return FutureBuilder<UserSex>(
      future: _sexFuture,
      builder: (context, sexSnap) {
        final sex = sexSnap.data ?? UserSex.female;
        final character = AreasModelAssets.character(sex);

        return FutureBuilder<Map<String, int?>>(
          future: _scoreFuture,
          builder: (context, scoreSnap) {
            final scores = scoreSnap.data ?? {};
            final avg = _averageScore(scores);

            return LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight;

                return Stack(
                  children: [
                    /// FUNDO
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/life_dashboard_bg.png',
                        fit: BoxFit.cover,
                      ),
                    ),

                    /// 🔥 HUD (CORRIGIDO)
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12121C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 🔥 FIX
                            children: [
                              Row(
                                children: [
                                  Text(
                                    avg.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: _openCheckin,
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor: avg / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    /// 👤 PERSONAGEM (MENOR)
                    Positioned(
                      top: 120,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Image.asset(
                          character.path,
                          height: h * 0.26, // 🔥 MENOR
                        ),
                      ),
                    ),

                    /// 🔥 GRID COLADO NA BOTTOM BAR
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 4, // 🔥 DISTÂNCIA REAL (quase colado)
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: GridView.builder(
                          shrinkWrap: true, // 🔥 ESSENCIAL
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: defs.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childAspectRatio: 1.7,
                              ),
                          itemBuilder: (context, i) {
                            final def = defs[i];

                            return _AreaCard(
                              icon: def.icon,
                              score: scores[def.id],
                              onTap: () => _openArea(def.id),
                            );
                          },
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

/// 🔥 CARD FINAL
class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.icon,
    required this.score,
    required this.onTap,
  });

  final IconData icon;
  final int? score;
  final VoidCallback onTap;

  Color _color() {
    if (score == null) return Colors.grey;
    if (score! >= 80) return Colors.green;
    if (score! >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: RadialGradient(
            colors: [
              c.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.7),
            ],
            radius: 1.1,
          ),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(child: Icon(icon, color: c, size: 32)),
      ),
    );
  }
}
