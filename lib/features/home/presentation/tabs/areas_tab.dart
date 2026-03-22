// ============================================================================
// AREAS TAB
// - layout base mantido
// - painel superior colado no topo
// - nome do usuário no topo
// - "Áreas feitas" -> "Status definidos"
// - "Média atual" -> "Classificação"
// - personagem com tamanho 0.55
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
  late Future<String> _nameFuture;

  UserSex _currentSex = UserSex.female;
  String _currentName = 'Usuário';

  @override
  void initState() {
    super.initState();
    _sexFuture = _loadUserSex();
    _nameFuture = _loadUserName();
    _scoreFuture = _loadScores(_currentSex);
  }

  Future<UserSex> _loadUserSex() async {
    final prefs = await SharedPreferences.getInstance();
    final gender = (prefs.getString('gender') ?? '').toLowerCase();
    final sex = gender.contains('homem') ? UserSex.male : UserSex.female;
    _currentSex = sex;
    return sex;
  }

  Future<String> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    final possibleName =
        prefs.getString('name') ??
        prefs.getString('user_name') ??
        prefs.getString('username') ??
        prefs.getString('display_name') ??
        prefs.getString('nome') ??
        prefs.getString('userNome');

    final name = (possibleName ?? '').trim();
    _currentName = name.isEmpty ? 'Usuário' : name;
    return _currentName;
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
      _scoreFuture = _loadScores(_currentSex);
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
                final definedStatuses = _definedStatusesCount(scores);
                final classification = _classificationLabel(avg);

                return LayoutBuilder(
                  builder: (context, c) {
                    final h = c.maxHeight;
                    final w = c.maxWidth;

                    // Painel mais colado no topo.
                    const double hudEstimatedHeight = 108;
                    const double gridBottom = 4;

                    final double gridHeight =
                        ((w - 20 - 12) / 3) / 1.7 * 3 + 12;

                    final double gridTop = h - gridHeight - gridBottom;

                    // Personagem no tamanho pedido.
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
                              definedStatuses: definedStatuses,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
              Material(
                color: Colors.transparent,
                child: InkWell(
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HudStatCard(
                  label: 'Status definidos',
                  value: '$definedStatuses/$totalAreas',
                  icon: Icons.fact_check_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudStatCard(
                  label: 'Classificação',
                  value: classification,
                  icon: Icons.workspace_premium_rounded,
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

class _HudStatCard extends StatelessWidget {
  const _HudStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
