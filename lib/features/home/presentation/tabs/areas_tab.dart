import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/local/session_storage.dart';
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
  final SessionStorage _session = SessionStorage();

  late Future<UserSex> _sexFuture;
  late Future<Map<String, int?>> _scoreFuture;
  late Future<String> _nameFuture;
  late Future<DateTime?> _birthDateFuture;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  void _refreshState() {
    _sexFuture = _loadUserSex();
    _nameFuture = _loadUserName();
    _birthDateFuture = _loadBirthDate();
    _scoreFuture = _sexFuture.then((sex) async {
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

    final raw =
        prefs.getString('birth_date_${user.uid}') ??
        prefs.getString('${user.uid}:birthDate') ??
        prefs.getString('${user.uid}:birthdate') ??
        prefs.getString('${user.uid}:dateOfBirth') ??
        prefs.getString('${user.uid}:dob');

    if (raw == null || raw.trim().isEmpty) return null;

    return DateTime.tryParse(raw.trim());
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

            return FutureBuilder<DateTime?>(
              future: _birthDateFuture,
              builder: (context, birthSnap) {
                final ageInfo = _AgeAccessInfo.fromBirthDate(
                  birthSnap.data,
                  DateTime.now(),
                );

                return FutureBuilder<Map<String, int?>>(
                  future: _scoreFuture,
                  builder: (context, scoreSnap) {
                    final scores = scoreSnap.data ?? <String, int?>{};
                    final avg = _averageScore(scores);
                    final defined = _definedStatusesCount(scores);
                    final classification = _classificationLabel(avg);

                    return LayoutBuilder(
                      builder: (context, c) {
                        final h = c.maxHeight;
                        final w = c.maxWidth;

                        const double hudEstimatedHeight = 176;
                        const double gridBottom = 4;

                        final double gridHeight =
                            ((w - 20 - 12) / 3) / 1.7 * 3 + 12;
                        final double gridTop = h - gridHeight - gridBottom;
                        final double characterHeight = h * 0.55;

                        final double safeTop =
                            MediaQuery.of(context).padding.top +
                            hudEstimatedHeight;

                        final double rawCharacterTop =
                            safeTop +
                            ((gridTop - safeTop - characterHeight) / 2);

                        final double minCharacterTop =
                            MediaQuery.of(context).padding.top + 112;
                        final double maxCharacterTop =
                            gridTop - characterHeight;

                        final double characterTop =
                            maxCharacterTop <= minCharacterTop
                            ? minCharacterTop
                            : rawCharacterTop
                                  .clamp(minCharacterTop, maxCharacterTop)
                                  .toDouble();

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
                              top: 4,
                              left: 8,
                              right: 8,
                              child: SafeArea(
                                bottom: false,
                                minimum: EdgeInsets.zero,
                                child: _TopHud(
                                  userName: userName,
                                  averageScore: avg,
                                  definedStatuses: defined,
                                  totalAreas: defs.length,
                                  classification: classification,
                                  ageInfo: ageInfo,
                                  onCheckinTap: _openCheckin,
                                  onQuestionsTap: _openCheckin,
                                  onAvatarTap: _openAvatarEditor,
                                  onAlertsTap: _openAlertsCenter,
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

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.userName,
    required this.averageScore,
    required this.definedStatuses,
    required this.totalAreas,
    required this.classification,
    required this.ageInfo,
    required this.onCheckinTap,
    required this.onQuestionsTap,
    required this.onAvatarTap,
    required this.onAlertsTap,
  });

  final String userName;
  final double averageScore;
  final int definedStatuses;
  final int totalAreas;
  final String classification;
  final _AgeAccessInfo ageInfo;
  final VoidCallback onCheckinTap;
  final VoidCallback onQuestionsTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onAlertsTap;

  Color _scoreColor() {
    if (averageScore >= 80) return const Color(0xFF22C55E);
    if (averageScore >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xF0181C30), Color(0xF0101324)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 8),
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
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
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
                          size: 28,
                        ),
                      ),
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F1120),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: scoreColor.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            classification,
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Painel da vida',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.30)),
                ),
                child: Column(
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
                        color: Colors.white.withValues(alpha: 0.78),
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
          Row(
            children: [
              Expanded(
                child: _HudActionCard(
                  icon: Icons.quiz_rounded,
                  title: 'Perguntas',
                  subtitle: 'do dia',
                  onTap: onQuestionsTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudActionCard(
                  icon: Icons.check_circle_rounded,
                  title: 'Check-in',
                  subtitle: 'rápido',
                  onTap: onCheckinTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudActionCard(
                  icon: Icons.notifications_active_rounded,
                  title: 'Alertas',
                  subtitle: 'em breve',
                  onTap: onAlertsTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cake_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Idade atual',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (ageInfo.hasBirthDate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
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
                                  ).withValues(alpha: 0.35)
                                : const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          ageInfo.canUnlock(18)
                              ? '18+ liberável'
                              : '18+ bloqueado',
                          style: TextStyle(
                            color: ageInfo.canUnlock(18)
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCD34D),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      ageInfo.ageLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ageInfo.secondaryLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: ageInfo.progressToNextBirthday.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF60A5FA),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ageInfo.progressLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Áreas avaliadas: $definedStatuses/$totalAreas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 10,
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

class _HudActionCard extends StatelessWidget {
  const _HudActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

  String get secondaryLabel {
    if (!hasBirthDate) {
      return 'Adicione a data de nascimento para ativar a barra.';
    }
    return age == 1 ? 'ano' : 'anos';
  }

  String get progressLabel {
    if (!hasBirthDate) return 'Barra anual indisponível';
    if (daysUntilBirthday == 0) return 'Hoje é seu aniversário';
    if (daysUntilBirthday == 1) {
      return 'Falta 1 dia para o próximo aniversário';
    }
    return 'Faltam $daysUntilBirthday dias para o próximo aniversário';
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
