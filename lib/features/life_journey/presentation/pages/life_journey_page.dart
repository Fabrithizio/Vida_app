// ============================================================================
// FILE: lib/features/life_journey/presentation/pages/life_journey_page.dart
//
// O que este arquivo faz:
// - Mostra a Linha da Vida em uma tela separada e ligada à idade do usuário
// - Exibe marcos grandes e pequenos desbloqueados pela data de nascimento
// - Corrige o overflow dos cards pequenos sem mudar a ideia visual da tela
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_model_assets.dart';
import 'package:vida_app/features/life_journey/data/life_journey_catalog.dart';
import 'package:vida_app/features/life_journey/domain/life_journey_milestone.dart';

class LifeJourneyPage extends StatefulWidget {
  const LifeJourneyPage({
    super.key,
    required this.userName,
    required this.sex,
    required this.birthDate,
  });

  final String userName;
  final UserSex sex;
  final DateTime? birthDate;

  @override
  State<LifeJourneyPage> createState() => _LifeJourneyPageState();
}

class _LifeJourneyPageState extends State<LifeJourneyPage> {
  static const double _timelineItemWidth = 146;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrentPoint());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _focusCurrentPoint() {
    final birthDate = widget.birthDate;
    if (birthDate == null || !_scrollController.hasClients) return;

    final now = DateTime.now();
    final milestones = _sortedMilestones(birthDate);
    if (milestones.isEmpty) return;

    int latestUnlockedIndex = 0;
    for (var i = 0; i < milestones.length; i++) {
      if (milestones[i].isUnlocked(birthDate, now)) {
        latestUnlockedIndex = i;
      }
    }

    final offset = math.max(
      0.0,
      (latestUnlockedIndex * _timelineItemWidth) - 90,
    );
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = offset.clamp(0.0, maxScroll).toDouble();

    _scrollController.jumpTo(target);
  }

  List<LifeJourneyMilestone> _sortedMilestones(DateTime birthDate) {
    final items = LifeJourneyCatalog.all()
        .where((item) => item.appliesTo(widget.sex))
        .toList();

    items.sort(
      (a, b) => a.unlockDate(birthDate).compareTo(b.unlockDate(birthDate)),
    );

    return items;
  }

  void _openMilestone(
    BuildContext context,
    LifeJourneyMilestone milestone,
    DateTime birthDate,
    bool unlocked,
  ) {
    if (!unlocked) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LifeJourneyMilestoneSheet(
        milestone: milestone,
        unlockDate: milestone.unlockDate(birthDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthDate = widget.birthDate;
    final now = DateTime.now();

    if (birthDate == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF060A14),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Linha da Vida'),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: _MissingBirthDateView(),
          ),
        ),
      );
    }

    final milestones = _sortedMilestones(birthDate);
    final ageInfo = _LifeJourneyAgeInfo.fromBirthDate(birthDate, now);
    final unlockedCount = milestones
        .where((item) => item.isUnlocked(birthDate, now))
        .length;

    final nextMilestone = milestones.cast<LifeJourneyMilestone?>().firstWhere(
      (item) => !(item?.isUnlocked(birthDate, now) ?? true),
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Linha da Vida'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _JourneyOverviewCard(
                userName: widget.userName,
                ageInfo: ageInfo,
                unlockedCount: unlockedCount,
                totalCount: milestones.length,
                nextMilestone: nextMilestone,
                birthDate: birthDate,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: const [
                  _LegendChip(
                    label: 'Grande = marco importante',
                    icon: Icons.crop_square_rounded,
                  ),
                  SizedBox(width: 8),
                  _LegendChip(
                    label: 'Pequeno = dia a dia',
                    icon: Icons.stop_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                itemCount: milestones.length,
                itemBuilder: (context, index) {
                  final milestone = milestones[index];
                  final unlocked = milestone.isUnlocked(birthDate, now);
                  final showAbove = index.isEven;
                  final isLatestUnlocked =
                      unlocked &&
                      milestones
                          .skip(index + 1)
                          .where((item) => item.isUnlocked(birthDate, now))
                          .isEmpty;

                  return _TimelineMilestoneItem(
                    width: _timelineItemWidth,
                    milestone: milestone,
                    unlocked: unlocked,
                    showAbove: showAbove,
                    isLatestUnlocked: isLatestUnlocked,
                    unlockDate: milestone.unlockDate(birthDate),
                    onTap: () =>
                        _openMilestone(context, milestone, birthDate, unlocked),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingBirthDateView extends StatelessWidget {
  const _MissingBirthDateView();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10182B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cake_rounded, color: Color(0xFF60A5FA), size: 34),
          const SizedBox(height: 14),
          const Text(
            'A Linha da Vida precisa da data de nascimento',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cadastre a data de nascimento do usuário para o app saber o que já foi liberado, o que ainda falta e onde a pessoa está na linha.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              'Quando a data existir, essa tela passa a desbloquear automaticamente os marcos e os conteúdos por idade.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyOverviewCard extends StatelessWidget {
  const _JourneyOverviewCard({
    required this.userName,
    required this.ageInfo,
    required this.unlockedCount,
    required this.totalCount,
    required this.nextMilestone,
    required this.birthDate,
  });

  final String userName;
  final _LifeJourneyAgeInfo ageInfo;
  final int unlockedCount;
  final int totalCount;
  final LifeJourneyMilestone? nextMilestone;
  final DateTime birthDate;

  @override
  Widget build(BuildContext context) {
    final nextLabel = nextMilestone == null
        ? 'Tudo que existe hoje já foi liberado.'
        : '${nextMilestone!.title} • ${_formatDate(nextMilestone!.unlockDate(birthDate))}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131C33), Color(0xFF0A1120)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jornada por idade',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OverviewBadge(
                icon: Icons.cake_rounded,
                text: '${ageInfo.age} anos',
              ),
              _OverviewBadge(
                icon: Icons.lock_open_rounded,
                text: '$unlockedCount de $totalCount liberados',
              ),
              _OverviewBadge(
                icon: Icons.flag_rounded,
                text: ageInfo.daysUntilBirthday == 0
                    ? 'Aniversário hoje'
                    : ageInfo.progressLabel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ageInfo.progressToNextBirthday.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF60A5FA),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Próximo desbloqueio',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewBadge extends StatelessWidget {
  const _OverviewBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMilestoneItem extends StatelessWidget {
  const _TimelineMilestoneItem({
    required this.width,
    required this.milestone,
    required this.unlocked,
    required this.showAbove,
    required this.isLatestUnlocked,
    required this.unlockDate,
    required this.onTap,
  });

  final double width;
  final LifeJourneyMilestone milestone;
  final bool unlocked;
  final bool showAbove;
  final bool isLatestUnlocked;
  final DateTime unlockDate;
  final VoidCallback onTap;

  static const double _centerLineTop = 168;

  Color get _majorColor =>
      unlocked ? const Color(0xFFB91C3C) : const Color(0xFF6B7280);

  Color get _minorColor =>
      unlocked ? const Color(0xFFFB7185) : const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final accent = milestone.isMajor ? _majorColor : _minorColor;
    final nodeSize = milestone.isMajor ? 28.0 : 18.0;
    final cardHeight = milestone.isMajor ? 128.0 : 92.0;
    final cardWidth = milestone.isMajor ? 126.0 : 110.0;
    final cardLeft = (width - cardWidth) / 2;
    final cardTop = showAbove
        ? _centerLineTop - cardHeight - 28
        : _centerLineTop + 24;

    final connectorHeight = showAbove
        ? _centerLineTop - (cardTop + cardHeight) - 4
        : cardTop - (_centerLineTop + nodeSize) + 2;

    final cardColor = unlocked ? accent : const Color(0xFF9CA3AF);
    final lineColor = unlocked ? accent : Colors.white.withValues(alpha: 0.12);

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _centerLineTop,
            child: Container(
              height: milestone.isMajor ? 10 : 7,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: 0.18),
                    lineColor,
                    lineColor.withValues(alpha: 0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: lineColor.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          Positioned(
            left: (width / 2) - 1,
            top: showAbove
                ? cardTop + cardHeight + 2
                : _centerLineTop + nodeSize,
            child: Container(
              width: 2,
              height: math.max(0, connectorHeight),
              color: lineColor.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            left: (width - nodeSize) / 2,
            top: _centerLineTop - (nodeSize / 2) + 4,
            child: Container(
              width: nodeSize,
              height: nodeSize,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF090F1F), width: 2),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.34),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                milestone.icon,
                color: Colors.white,
                size: milestone.isMajor ? 15 : 10,
              ),
            ),
          ),
          Positioned(
            left: cardLeft,
            top: cardTop,
            child: GestureDetector(
              onTap: unlocked ? onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: cardWidth,
                height: cardHeight,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: unlocked
                      ? cardColor.withValues(
                          alpha: milestone.isMajor ? 0.18 : 0.14,
                        )
                      : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(
                    milestone.isMajor ? 22 : 18,
                  ),
                  border: Border.all(
                    color: unlocked
                        ? cardColor.withValues(alpha: 0.58)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: isLatestUnlocked
                      ? [
                          BoxShadow(
                            color: cardColor.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MilestoneTopRow(
                      unlocked: unlocked,
                      label: milestone.label,
                      isMajor: milestone.isMajor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      milestone.title,
                      maxLines: milestone.isMajor ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white70,
                        fontSize: milestone.isMajor ? 13 : 11,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        unlocked
                            ? milestone.summary
                            : 'Bloqueado até ${_formatDate(unlockDate)}',
                        maxLines: milestone.isMajor ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (unlocked ? Colors.white : Colors.white70)
                              .withValues(alpha: 0.84),
                          fontSize: milestone.isMajor ? 11 : 10,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (unlocked)
                      Text(
                        milestone.isMajor ? 'Toque para abrir' : 'Abrir',
                        style: TextStyle(
                          color: cardColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneTopRow extends StatelessWidget {
  const _MilestoneTopRow({
    required this.unlocked,
    required this.label,
    required this.isMajor,
  });

  final bool unlocked;
  final String label;
  final bool isMajor;

  String get _displayLabel {
    if (isMajor) return label;
    if (label.length <= 12) return label;

    final parts = label.split('+');
    if (parts.length > 1) {
      return '+${parts.last.trim()}';
    }

    return label;
  }

  @override
  Widget build(BuildContext context) {
    final maxChipWidth = isMajor ? 78.0 : 60.0;

    return Row(
      children: [
        Icon(
          unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          color: unlocked ? Colors.white : Colors.white54,
          size: 14,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxChipWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LifeJourneyMilestoneSheet extends StatelessWidget {
  const _LifeJourneyMilestoneSheet({
    required this.milestone,
    required this.unlockDate,
  });

  final LifeJourneyMilestone milestone;
  final DateTime unlockDate;

  @override
  Widget build(BuildContext context) {
    final accent = milestone.isMajor
        ? const Color(0xFFB91C3C)
        : const Color(0xFFFB7185);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1221),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.34)),
                    ),
                    child: Icon(milestone.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${milestone.category} • ${_formatDate(unlockDate)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  milestone.summary,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.26)),
                ),
                child: Text(
                  milestone.body,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifeJourneyAgeInfo {
  const _LifeJourneyAgeInfo({
    required this.age,
    required this.progressToNextBirthday,
    required this.daysUntilBirthday,
  });

  final int age;
  final double progressToNextBirthday;
  final int daysUntilBirthday;

  String get progressLabel {
    if (daysUntilBirthday == 0) return 'Aniversário hoje';
    if (daysUntilBirthday == 1) return 'Falta 1 dia';
    return 'Faltam $daysUntilBirthday dias';
  }

  static _LifeJourneyAgeInfo fromBirthDate(DateTime birthDate, DateTime now) {
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

    return _LifeJourneyAgeInfo(
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

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}
