// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas_tab.dart
//
// O que faz:
// - Mostra a aba Areas com avatar, top bar e grid das áreas
// - Exibe score geral, idade e barra anual
// - Abre detalhes de cada área
// - Bloqueia o uso do Areas até o usuário responder o check-in diário
// - Adiciona o ícone do livro com explicação clara do sistema de score
//
// Correções desta versão:
// - women_cycle só entra no cálculo para perfil feminino
// - score usa apenas as subáreas visíveis e realmente válidas
// - atalho do livro mantido sem mexer no layout principal do app
// - classificação visual unificada com o sistema novo:
//   85+ Ótimo | 68+ Bom | 45+ Médio | 25+ Ruim | abaixo disso Crítico
//
// Correção (bug atual):
// - score geral agora é média das 9 áreas (null conta como 0)
// - cor do score geral agora fica cinza quando score == 0 ("Inicial")
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/local/session_storage.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/device/device_usage_service.dart';
import 'package:vida_app/features/device/usage_access_overlay.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/area_detail_page.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_model_assets.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/daily_checkin_overlay.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/daily_checkin_sheet.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/score_rules_sheet.dart';

class AreasTab extends StatefulWidget {
  const AreasTab({super.key});

  @override
  State<AreasTab> createState() => _AreasTabState();
}

class _AreasTabState extends State<AreasTab> {
  final AreasStore _store = AreasStore();
  final SessionStorage _session = SessionStorage();
  final DailyCheckinService _dailyCheckinService = DailyCheckinService();
  final DeviceUsageService _deviceUsage = DeviceUsageService();

  bool _dailyGateAlreadyChecked = false;
  bool _usageOverlayOpen = false;

  late Future<UserSex> _sexFuture;
  late Future<Map<String, int?>> _scoreFuture;
  late Future<String> _nameFuture;
  late Future<DateTime?> _birthDateFuture;

  UserSex? _resolvedSex;
  String? _resolvedName;
  DateTime? _resolvedBirthDate;
  Map<String, int?>? _resolvedScores;

  @override
  void initState() {
    super.initState();
    _refreshState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkDailyGate();
      await _checkUsageAccessGate();
    });
  }

  void _refreshState() {
    _sexFuture = _loadUserSex().then((value) {
      _resolvedSex = value;
      return value;
    });

    _nameFuture = _loadUserName().then((value) {
      _resolvedName = value;
      return value;
    });

    _birthDateFuture = _loadBirthDate().then((value) {
      _resolvedBirthDate = value;
      return value;
    });

    _scoreFuture = _sexFuture
        .then((_) async {
          await _store.ensureBootstrappedFromOnboarding();
          try {
            await _deviceUsage.refreshAndPersistDigitalBuckets();
          } catch (_) {}
          return _loadScores();
        })
        .then((value) {
          _resolvedScores = value;
          return value;
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

    final uid = user.uid;
    final gender = (prefs.getString('$uid:gender') ?? '').trim();
    return _parseSex(gender);
  }

  Future<String> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuário';

    final nick = (await _session.readNickname(user.uid))?.trim() ?? '';
    if (nick.isNotEmpty) return nick;

    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;

    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;

    return 'Usuário';
  }

  Future<DateTime?> _loadBirthDate() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final uid = user.uid;
    final raw =
        prefs.getString('birth_date_$uid') ??
        prefs.getString('$uid:birthDate') ??
        prefs.getString('$uid:birthdate') ??
        prefs.getString('$uid:dateOfBirth') ??
        prefs.getString('$uid:dob');

    if (raw == null || raw.trim().isEmpty) return null;

    return DateTime.tryParse(raw.trim());
  }

  Future<Map<String, int?>> _loadScores() async {
    final defs = AreasCatalog.all();
    final includeWomenCycle =
        (_resolvedSex ?? UserSex.female) == UserSex.female;
    final map = <String, int?>{};

    for (final def in defs) {
      final items = AreasCatalog.itemsForArea(
        def.id,
        includeWomenCycle: includeWomenCycle,
      );

      map[def.id] = await _store.score(def.id, items.map((e) => e.id).toList());
    }

    return map;
  }

  // FIX: média real das áreas (null conta como 0)
  double _averageScore(Map<String, int?> scores, {required int totalAreas}) {
    if (totalAreas <= 0) return 0;
    final sum = scores.values.fold<int>(0, (acc, value) => acc + (value ?? 0));
    return sum / totalAreas;
  }

  int _definedStatusesCount(Map<String, int?> scores) {
    return scores.values.where((value) => value != null).length;
  }

  String _classificationLabel(double score) {
    if (score >= 85) return 'Ótimo';
    if (score >= 68) return 'Bom';
    if (score >= 45) return 'Médio';
    if (score >= 25) return 'Ruim';
    if (score > 0) return 'Crítico';
    return 'Inicial';
  }

  Future<void> _openCheckin() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DailyCheckinSheet(),
    );

    if (!mounted) return;
    setState(() {});
  }

  void _showSoonMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  void _openAvatarEditor() {
    _showSoonMessage('Editor de avatar será ligado aqui em breve.');
  }

  void _openAlertsCenter() {
    _showSoonMessage('Central de alertas será ligada aqui em breve.');
  }

  Future<void> _openScoreRules() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ScoreRulesSheet(),
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
    setState(_refreshState);
  }

  Future<void> _checkDailyGate() async {
    if (_dailyGateAlreadyChecked) return;

    final today = DateTime.now();
    final canUse = await _dailyCheckinService.canUseAreas(today);

    if (!mounted) return;
    _dailyGateAlreadyChecked = true;

    if (canUse) return;

    final unlocked = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const DailyCheckinOverlay(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (!mounted) return;

    if (unlocked == true) {
      setState(() {});
    }
  }

  Future<void> _checkUsageAccessGate() async {
    if (_usageOverlayOpen) return;

    final supported = await _deviceUsage.isAndroidSupported();
    if (!supported) return;

    final has = await _deviceUsage.hasUsageAccess();
    if (!mounted) return;

    if (has) return;

    _usageOverlayOpen = true;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsageAccessOverlay(
        onGranted: () async {
          try {
            await _deviceUsage.refreshAndPersistDigitalBuckets();
          } catch (_) {}

          _refreshState();
          if (mounted) setState(() {});
        },
      ),
    );

    _usageOverlayOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final defs = AreasCatalog.all();

    return FutureBuilder<UserSex>(
      future: _sexFuture,
      initialData: _resolvedSex,
      builder: (context, sexSnap) {
        final sex = sexSnap.data ?? _resolvedSex ?? UserSex.female;
        final character = AreasModelAssets.character(sex);

        return FutureBuilder<String>(
          future: _nameFuture,
          initialData: _resolvedName,
          builder: (context, nameSnap) {
            final userName = (nameSnap.data ?? _resolvedName ?? 'Usuário')
                .trim();

            return FutureBuilder<DateTime?>(
              future: _birthDateFuture,
              initialData: _resolvedBirthDate,
              builder: (context, birthSnap) {
                final ageInfo = _AgeAccessInfo.fromBirthDate(
                  birthSnap.data ?? _resolvedBirthDate,
                  DateTime.now(),
                );

                return FutureBuilder<Map<String, int?>>(
                  future: _scoreFuture,
                  initialData: _resolvedScores,
                  builder: (context, scoreSnap) {
                    final scores =
                        scoreSnap.data ?? _resolvedScores ?? <String, int?>{};

                    final avg = _averageScore(scores, totalAreas: defs.length);
                    final defined = _definedStatusesCount(scores);
                    final classification = _classificationLabel(avg);

                    return LayoutBuilder(
                      builder: (context, c) {
                        final h = c.maxHeight;
                        final w = c.maxWidth;

                        const double gridBottom = 4;
                        const double hudTopGap = 2;
                        const double hudHeight = 126;

                        final double gridHeight =
                            ((w - 20 - 12) / 3) / 1.7 * 3 + 12;

                        final double gridTop = h - gridHeight - gridBottom;
                        final double characterHeight = h * 0.47;

                        final double avatarTopMin =
                            MediaQuery.of(context).padding.top + hudHeight + 18;

                        final double avatarTopMax =
                            gridTop - characterHeight - 4;

                        final double avatarTop = avatarTopMax <= avatarTopMin
                            ? avatarTopMin
                            : ((avatarTopMin + avatarTopMax) / 2);

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/life_dashboard_bg.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    color: const Color(0xFF0B1020),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: hudTopGap,
                              left: 8,
                              right: 8,
                              child: SafeArea(
                                bottom: false,
                                minimum: EdgeInsets.zero,
                                child: _TopHudCompact(
                                  userName: userName,
                                  averageScore: avg,
                                  definedStatuses: defined,
                                  totalAreas: defs.length,
                                  classification: classification,
                                  ageInfo: ageInfo,
                                  onCheckinTap: _openCheckin,
                                  onAvatarTap: _openAvatarEditor,
                                  onAlertsTap: _openAlertsCenter,
                                  onScoreRulesTap: _openScoreRules,
                                ),
                              ),
                            ),
                            Positioned(
                              top: avatarTop,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
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
      },
    );
  }
}

class _TopHudCompact extends StatelessWidget {
  const _TopHudCompact({
    required this.userName,
    required this.averageScore,
    required this.definedStatuses,
    required this.totalAreas,
    required this.classification,
    required this.ageInfo,
    required this.onCheckinTap,
    required this.onAvatarTap,
    required this.onAlertsTap,
    required this.onScoreRulesTap,
  });

  final String userName;
  final double averageScore;
  final int definedStatuses;
  final int totalAreas;
  final String classification;
  final _AgeAccessInfo ageInfo;
  final VoidCallback onCheckinTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onScoreRulesTap;

  Color _scoreColor() {
    if (averageScore <= 0) return const Color(0xFF94A3B8);
    if (averageScore >= 85) return const Color(0xFF22C55E);
    if (averageScore >= 68) return const Color(0xFFF59E0B);
    if (averageScore >= 45) return const Color(0xFFFB923C);
    if (averageScore >= 25) return const Color(0xFFEF4444);
    return const Color(0xFFB91C1C);
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xF0141830), Color(0xF00E1225)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x45000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onAvatarTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF101423),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scoreColor.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Text(
                            classification,
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Painel da vida',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _MiniActionButton(
                    icon: Icons.check_circle_rounded,
                    onTap: onCheckinTap,
                  ),
                  const SizedBox(width: 6),
                  _MiniActionButton(
                    icon: Icons.menu_book_rounded,
                    onTap: onScoreRulesTap,
                  ),
                  const SizedBox(width: 6),
                  _MiniActionButton(
                    icon: Icons.notifications_active_rounded,
                    onTap: onAlertsTap,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          averageScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          'Score',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cake_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Idade',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ageInfo.ageLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    if (ageInfo.hasBirthDate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ageInfo.canUnlock(18)
                              ? const Color(0xFF16A34A).withValues(alpha: 0.18)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: ageInfo.canUnlock(18)
                                ? const Color(
                                    0xFF16A34A,
                                  ).withValues(alpha: 0.34)
                                : const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.34),
                          ),
                        ),
                        child: Text(
                          ageInfo.canUnlock(18) ? '18+' : 'menor',
                          style: TextStyle(
                            color: ageInfo.canUnlock(18)
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCD34D),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: ageInfo.progressToNextBirthday.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF60A5FA),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ageInfo.progressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$definedStatuses/$totalAreas áreas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
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
    if (s == null) return const Color(0xFF94A3B8);
    if (s >= 85) return const Color(0xFF22C55E);
    if (s >= 68) return const Color(0xFFF59E0B);
    if (s >= 45) return const Color(0xFFFB923C);
    if (s >= 25) return const Color(0xFFEF4444);
    return const Color(0xFFB91C1C);
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

class _AgeAccessInfo {
  const _AgeAccessInfo({
    required this.hasBirthDate,
    required this.age,
    required this.progressToNextBirthday,
    required this.daysUntilBirthday,
  });

  final bool hasBirthDate;
  final int age;
  final double progressToNextBirthday;
  final int daysUntilBirthday;

  String get ageLabel => hasBirthDate ? '$age' : '--';

  String get progressLabel {
    if (!hasBirthDate) return 'Sem data de nascimento';
    if (daysUntilBirthday == 0) return 'Aniversário hoje';
    if (daysUntilBirthday == 1) return 'Falta 1 dia';
    return 'Faltam $daysUntilBirthday dias';
  }

  bool canUnlock(int minimumAge) => hasBirthDate && age >= minimumAge;

  static _AgeAccessInfo fromBirthDate(DateTime? birthDate, DateTime now) {
    if (birthDate == null) {
      return const _AgeAccessInfo(
        hasBirthDate: false,
        age: 0,
        progressToNextBirthday: 0,
        daysUntilBirthday: 0,
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);

    final thisYearBirthday = _safeDate(today.year, birth.month, birth.day);

    int age = today.year - birth.year;
    if (today.isBefore(thisYearBirthday)) {
      age--;
    }

    final lastBirthday = today.isBefore(thisYearBirthday)
        ? _safeDate(today.year - 1, birth.month, birth.day)
        : thisYearBirthday;

    final nextBirthday = today.isBefore(thisYearBirthday)
        ? thisYearBirthday
        : _safeDate(today.year + 1, birth.month, birth.day);

    final totalDays = nextBirthday.difference(lastBirthday).inDays;
    final elapsedDays = today.difference(lastBirthday).inDays;

    final progress = totalDays <= 0 ? 0.0 : elapsedDays / totalDays;
    final daysUntilBirthday = nextBirthday.difference(today).inDays;

    return _AgeAccessInfo(
      hasBirthDate: true,
      age: age < 0 ? 0 : age,
      progressToNextBirthday: progress.clamp(0.0, 1.0),
      daysUntilBirthday: daysUntilBirthday < 0 ? 0 : daysUntilBirthday,
    );
  }

  static DateTime _safeDate(int year, int month, int day) {
    final cappedDay = day.clamp(1, _daysInMonth(year, month));
    return DateTime(year, month, cappedDay);
  }

  static int _daysInMonth(int year, int month) {
    final firstDayNextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return firstDayNextMonth.subtract(const Duration(days: 1)).day;
  }
}
