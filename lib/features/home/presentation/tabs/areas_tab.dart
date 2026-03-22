// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/areas_tab.dart
//
// Fixes:
// - Antes de calcular scores, chama ensureBootstrappedFromOnboarding()
// - Corrige imports para os paths reais do projeto (features/home/presentation/...)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/area_detail_page.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_model_assets.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/daily_checkin_sheet.dart';
import 'package:vida_app/data/local/session_storage.dart';

class AreasTab extends StatefulWidget {
  const AreasTab({super.key});

  @override
  State<AreasTab> createState() => _AreasTabState();
}

class _AreasTabState extends State<AreasTab> {
  final AreasStore _store = AreasStore();

  late Future<UserSex> _sexFuture;
  late Future<Map<String, int?>> _scoreFuture;
  late Future<String> _nameFuture;

  @override
  void initState() {
    super.initState();
    _sexFuture = _loadUserSex();
    _nameFuture = _loadUserName();

    _scoreFuture = _sexFuture.then((sex) async {
      // ✅ IMPORTANTE: este método precisa existir no AreasStore
      await _store.ensureBootstrappedFromOnboarding();
      return _loadScores(sex);
    });
  }

  UserSex _parseSex(String raw) {
    final g = raw.trim().toLowerCase();
    if (g.contains('mulher') || g.contains('femin')) return UserSex.female;
    if (g.contains('homem') || g.contains('masc')) return UserSex.male;
    return UserSex.female;
  }

  Future<UserSex> _loadUserSex() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return UserSex.female;

    final gender = (prefs.getString('${user.uid}:gender') ?? '').trim();
    return _parseSex(gender);
  }

  Future<String> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuário';

    final nick = (await SessionStorage().readNickname(user.uid))?.trim() ?? '';
    if (nick.isNotEmpty) return nick;

    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;

    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;

    return 'Usuário';
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

  int _definedStatusesCount(Map<String, int?> scores) {
    return scores.values.where((value) => value != null).length;
  }

  String _classificationLabel(double score) {
    if (score >= 80) return 'Ótimo';
    if (score >= 50) return 'Bom';
    if (score > 0) return 'Atenção';
    return 'Inicial';
  }

  void _openCheckin() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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

    if (!mounted) return;
    setState(() {
      _sexFuture = _loadUserSex();
      _nameFuture = _loadUserName();
      _scoreFuture = _sexFuture.then((sex) async {
        await _store.ensureBootstrappedFromOnboarding();
        return _loadScores(sex);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final defs = AreasCatalog.all();

    return FutureBuilder<UserSex>(
      future: _sexFuture,
      builder: (context, sexSnap) {
        final sex = sexSnap.data ?? UserSex.female;
        final character = AreasModelAssets.character(sex);

        return FutureBuilder<String>(
          future: _nameFuture,
          builder: (context, nameSnap) {
            final userName = (nameSnap.data ?? 'Usuário').trim();

            return FutureBuilder<Map<String, int?>>(
              future: _scoreFuture,
              builder: (context, scoreSnap) {
                final scores = scoreSnap.data ?? {};
                final avg = _averageScore(scores);
                final defined = _definedStatusesCount(scores);
                final classification = _classificationLabel(avg);

                return LayoutBuilder(
                  builder: (context, c) {
                    final h = c.maxHeight;
                    final w = c.maxWidth;

                    const double hudEstimatedHeight = 108;
                    const double gridBottom = 4;

                    final double gridHeight =
                        ((w - 20 - 12) / 3) / 1.7 * 3 + 12;

                    final double gridTop = h - gridHeight - gridBottom;

                    final double characterHeight = h * 0.55;
                    final double safeTop =
                        MediaQuery.of(context).padding.top + hudEstimatedHeight;

                    final double rawCharacterTop =
                        safeTop + ((gridTop - safeTop - characterHeight) / 2);

                    final double characterTop = rawCharacterTop.clamp(
                      MediaQuery.of(context).padding.top + 78,
                      gridTop - characterHeight,
                    );

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/life_dashboard_bg.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -30,
                          left: 6,
                          right: 6,
                          child: SafeArea(
                            bottom: false,
                            minimum: EdgeInsets.zero,
                            child: _TopHud(
                              userName: userName,
                              averageScore: avg,
                              definedStatuses: defined,
                              totalAreas: defs.length,
                              classification: classification,
                              onCheckinTap: _openCheckin,
                            ),
                          ),
                        ),
                        Positioned(
                          top: characterTop,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: Image.asset(
                                character.path,
                                height: characterHeight,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: gridBottom,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: GridView.builder(
                              shrinkWrap: true,
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
      },
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.userName,
    required this.averageScore,
    required this.definedStatuses,
    required this.totalAreas,
    required this.classification,
    required this.onCheckinTap,
  });

  final String userName;
  final double averageScore;
  final int definedStatuses;
  final int totalAreas;
  final String classification;
  final VoidCallback onCheckinTap;

  Color _scoreColor() {
    if (averageScore >= 80) return const Color(0xFF22C55E);
    if (averageScore >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor();
    final progress = totalAreas == 0 ? 0.0 : definedStatuses / totalAreas;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1120).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.14),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    averageScore.toStringAsFixed(0),
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Status geral: $classification',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onCheckinTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162A1B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF22C55E),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Check-in',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final s = score;
    if (s == null) return Colors.grey;
    if (s >= 80) return Colors.green;
    if (s >= 50) return Colors.orange;
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
