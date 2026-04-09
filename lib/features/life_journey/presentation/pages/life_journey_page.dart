// ============================================================================
// FILE: lib/features/life_journey/presentation/pages/life_journey_page.dart
//
// O que este arquivo faz:
// - Exibe a Linha da Vida com visual mais chamativo e educativo.
// - Usa cores por categoria para os marcos, não só vermelho fixo.
// - Mostra cabeçalho de fase, progresso, trilha horizontal e detalhes ricos.
// - Mantém a integração atual com nome, sexo e data de nascimento do usuário.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/presentation/widgets/areas_model_assets.dart';
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
  static const double _timelineItemWidth = 216;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToLatestUnlocked(),
    );
  }

  @override
  void didUpdateWidget(covariant LifeJourneyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.birthDate != widget.birthDate ||
        oldWidget.sex != widget.sex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToLatestUnlocked(),
      );
    }
  }

  void _scrollToLatestUnlocked() {
    final birthDate = widget.birthDate;
    if (birthDate == null || !_scrollController.hasClients) return;

    final now = DateTime.now();
    final milestones = _sortedMilestones(birthDate);
    var latestUnlockedIndex = 0;

    for (var i = 0; i < milestones.length; i++) {
      if (milestones[i].isUnlocked(birthDate, now)) {
        latestUnlockedIndex = i;
      }
    }

    final offset = math.max(
      0.0,
      (latestUnlockedIndex * _timelineItemWidth) - 120,
    );
    final target = offset
        .clamp(0.0, _scrollController.position.maxScrollExtent)
        .toDouble();
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
    final phase = _phaseForAge(ageInfo.age);
    final character = AreasModelAssets.character(widget.sex);

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Linha da Vida'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _LifeJourneyBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroJourneyCard(
                    userName: widget.userName,
                    sex: widget.sex,
                    birthDate: birthDate,
                    ageInfo: ageInfo,
                    unlockedCount: unlockedCount,
                    totalCount: milestones.length,
                    nextMilestone: nextMilestone,
                    characterPath: character.path,
                    phase: phase,
                  ),
                  const SizedBox(height: 16),
                  _AlicerceCard(sex: widget.sex),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    title: 'Fases da maturidade',
                    subtitle:
                        'Uma trilha por idade para te ensinar o que a escola quase nunca ensina.',
                  ),
                  const SizedBox(height: 10),
                  _PhaseStrip(currentAge: ageInfo.age),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    title: 'Trilha desbloqueável',
                    subtitle:
                        'Cada marco traz cor, contexto e uma aprendizagem ligada ao momento da vida.',
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 308,
                    child: _TimelineStrip(
                      controller: _scrollController,
                      milestones: milestones,
                      birthDate: birthDate,
                      now: now,
                      onTapMilestone: (milestone, unlocked) {
                        _openMilestone(context, milestone, birthDate, unlocked);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle(
                    title: 'Grandes verdades',
                    subtitle:
                        'Alguns princípios não têm uma idade única. Eles vão ficando mais claros conforme a vida aperta.',
                  ),
                  const SizedBox(height: 10),
                  const _TruthGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeJourneyBackground extends StatelessWidget {
  const _LifeJourneyBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF060A14), Color(0xFF0A1020), Color(0xFF10192E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              size: 220,
              color: const Color(0xFF60A5FA).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 130,
            left: -50,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFFA78BFA).withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -40,
            child: _GlowOrb(
              size: 200,
              color: const Color(0xFF34D399).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, spreadRadius: 26),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _HeroJourneyCard extends StatelessWidget {
  const _HeroJourneyCard({
    required this.userName,
    required this.sex,
    required this.birthDate,
    required this.ageInfo,
    required this.unlockedCount,
    required this.totalCount,
    required this.nextMilestone,
    required this.characterPath,
    required this.phase,
  });

  final String userName;
  final UserSex sex;
  final DateTime birthDate;
  final _LifeJourneyAgeInfo ageInfo;
  final int unlockedCount;
  final int totalCount;
  final LifeJourneyMilestone? nextMilestone;
  final String characterPath;
  final _PhaseInfo phase;

  @override
  Widget build(BuildContext context) {
    final accent = _LifeJourneyColors.forCategory(phase.colorHint);
    final progress = totalCount == 0 ? 0.0 : unlockedCount / totalCount;
    final nextLabel = nextMilestone == null
        ? 'Tudo que existe hoje já foi liberado.'
        : '${nextMilestone!.title} • ${_formatDate(nextMilestone!.unlockDate(birthDate))}';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.primary.withValues(alpha: 0.30),
            const Color(0xFF0D1527),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jornada de $userName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phase.title,
                      style: TextStyle(
                        color: accent.soft,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phase.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 96,
                height: 136,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.black.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    characterPath,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroBadge(icon: Icons.cake_rounded, text: '${ageInfo.age} anos'),
              _HeroBadge(
                icon: Icons.lock_open_rounded,
                text: '$unlockedCount/$totalCount marcos',
              ),
              _HeroBadge(icon: Icons.calendar_today_rounded, text: nextLabel),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(accent.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A Linha da Vida não é só idade. É contexto, preparação e consciência para cada fase.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlicerceCard extends StatelessWidget {
  const _AlicerceCard({required this.sex});

  final UserSex sex;

  @override
  Widget build(BuildContext context) {
    final accent = _LifeJourneyColors.forCategory('Base');
    final everyone = const [
      'Gestão financeira real',
      'Comunicação assertiva',
      'Culinária básica',
      'Manutenção de vida',
      'Fracasso é dado',
      'Leitura de caráter',
    ];
    final specific = sex == UserSex.female
        ? const [
            'Intuição e segurança',
            'Independência financeira',
            'Domínio do ciclo biológico',
            'Limites com firmeza',
          ]
        : const [
            'Autocontrole e firmeza',
            'Alfabetização emocional',
            'Responsabilidade radical',
            'Respeito nas relações',
          ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.primary.withValues(alpha: 0.16),
            const Color(0xFF10182B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.primary.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.hub_rounded, color: accent.soft, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'O Alicerce',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'As engrenagens do mundo real que servem para toda a linha da vida.',
                      style: TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: everyone.map((item) => _PillLabel(text: item)).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            sex == UserSex.female
                ? 'Pontos que ganham destaque extra para mulher'
                : 'Pontos que ganham destaque extra para homem',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specific
                .map((item) => _PillLabel(text: item, filled: true))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.text, this.filled = false});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withValues(alpha: 0.11)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.94),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.currentAge});

  final int currentAge;

  @override
  Widget build(BuildContext context) {
    const phases = [
      _PhaseInfo(title: '12–15', description: 'Juventude', colorHint: 'Saúde'),
      _PhaseInfo(
        title: '16–20',
        description: 'Adolescência',
        colorHint: 'Digital',
      ),
      _PhaseInfo(
        title: '21–29',
        description: 'Jovem adulto',
        colorHint: 'Finanças',
      ),
      _PhaseInfo(
        title: '30–38',
        description: 'Adulto consolidado',
        colorHint: 'Legado',
      ),
    ];

    return Row(
      children: phases.map((phase) {
        final selected = phase.contains(currentAge);
        final palette = _LifeJourneyColors.forCategory(phase.colorHint);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: phase == phases.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: selected
                    ? [
                        palette.primary.withValues(alpha: 0.34),
                        palette.secondary.withValues(alpha: 0.22),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? palette.primary.withValues(alpha: 0.34)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                Text(
                  phase.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phase.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? palette.soft
                        : Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimelineStrip extends StatelessWidget {
  const _TimelineStrip({
    required this.controller,
    required this.milestones,
    required this.birthDate,
    required this.now,
    required this.onTapMilestone,
  });

  final ScrollController controller;
  final List<LifeJourneyMilestone> milestones;
  final DateTime birthDate;
  final DateTime now;
  final void Function(LifeJourneyMilestone milestone, bool unlocked)
  onTapMilestone;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 140,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
        ),
        ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          scrollDirection: Axis.horizontal,
          itemCount: milestones.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final milestone = milestones[index];
            final unlocked = milestone.isUnlocked(birthDate, now);
            return SizedBox(
              width: _LifeJourneyPageState._timelineItemWidth,
              child: _MilestoneCard(
                milestone: milestone,
                unlockDate: milestone.unlockDate(birthDate),
                unlocked: unlocked,
                onTap: () => onTapMilestone(milestone, unlocked),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.unlockDate,
    required this.unlocked,
    required this.onTap,
  });

  final LifeJourneyMilestone milestone;
  final DateTime unlockDate;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _LifeJourneyColors.forCategory(milestone.category);
    final showAbove = milestone.isMajor;
    final nodeTop = 134.0;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: nodeTop,
            child: Center(
              child: Container(
                width: milestone.isMajor ? 28 : 22,
                height: milestone.isMajor ? 28 : 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked ? palette.primary : const Color(0xFF64748B),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.36),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.26),
                    width: 2,
                  ),
                ),
                child: Icon(
                  unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: Colors.white,
                  size: milestone.isMajor ? 14 : 11,
                ),
              ),
            ),
          ),
          Positioned(
            left: (_LifeJourneyPageState._timelineItemWidth - 2) / 2,
            top: showAbove ? 56 : 150,
            child: Container(
              width: 2,
              height: showAbove ? 78 : 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color:
                    (unlocked
                            ? palette.primary
                            : Colors.white.withValues(alpha: 0.14))
                        .withValues(alpha: 0.75),
              ),
            ),
          ),
          Positioned(
            top: showAbove ? 0 : 164,
            left: 8,
            right: 8,
            child: Opacity(
              opacity: unlocked ? 1 : 0.70,
              child: Container(
                height: showAbove ? 122 : 112,
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: unlocked
                        ? [
                            palette.primary.withValues(alpha: 0.24),
                            palette.secondary.withValues(alpha: 0.18),
                            const Color(0xFF10182B),
                          ]
                        : [const Color(0xFF182234), const Color(0xFF10182B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: unlocked
                        ? palette.primary.withValues(alpha: 0.32)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              milestone.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unlocked ? palette.soft : Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(milestone.icon, color: Colors.white, size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      milestone.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        milestone.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 114,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  _formatMilestoneChip(milestone, unlockDate),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruthGrid extends StatelessWidget {
  const _TruthGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      _TruthItem(
        icon: Icons.visibility_rounded,
        title: 'Ninguém pensa tanto em você quanto parece',
        body:
            'As pessoas estão ocupadas com a própria vida. Isso é libertador e ajuda você a agir com mais coragem.',
      ),
      _TruthItem(
        icon: Icons.analytics_rounded,
        title: 'Erro é dado, não sentença',
        body:
            'O fracasso ensina melhor quando deixa de ser identidade e vira informação para ajustar a rota.',
      ),
      _TruthItem(
        icon: Icons.live_help_rounded,
        title: 'A vida premia boas perguntas',
        body:
            'Maturidade não é ter todas as respostas, e sim aprender a perguntar melhor para si e para o mundo.',
      ),
      _TruthItem(
        icon: Icons.workspace_premium_rounded,
        title: 'Autonomia é parte da paz',
        body:
            'Quanto mais você sabe se virar no básico, menos depende do humor do mundo para funcionar.',
      ),
    ];

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TruthCard(item: item),
            ),
          )
          .toList(),
    );
  }
}

class _TruthItem {
  const _TruthItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _TruthCard extends StatelessWidget {
  const _TruthCard({required this.item});

  final _TruthItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: Colors.white, size: 20),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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
          const Text(
            'Cadastre sua data de nascimento',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A Linha da Vida depende da sua idade para liberar marcos no tempo certo. Sem esse dado, o app não consegue montar a sua trilha por fase.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
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
    final palette = _LifeJourneyColors.forCategory(milestone.category);
    final tips = _tipsForCategory(milestone.category);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.primary.withValues(alpha: 0.18),
                    ),
                    child: Icon(milestone.icon, color: palette.soft, size: 28),
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
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SheetBadge(
                              text: milestone.category,
                              color: palette.primary,
                            ),
                            _SheetBadge(
                              text: _formatDate(unlockDate),
                              color: palette.secondary,
                            ),
                            _SheetBadge(
                              text: milestone.label,
                              color: palette.primary.withValues(alpha: 0.82),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                milestone.summary,
                style: TextStyle(
                  color: palette.soft,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                milestone.body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Como isso pode te orientar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ...tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetBadge extends StatelessWidget {
  const _SheetBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LifeJourneyAgeInfo {
  const _LifeJourneyAgeInfo({required this.age});

  final int age;

  static _LifeJourneyAgeInfo fromBirthDate(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    final thisYearBirthday = DateTime(now.year, birthDate.month, birthDate.day);
    if (DateTime(now.year, now.month, now.day).isBefore(thisYearBirthday)) {
      age--;
    }
    return _LifeJourneyAgeInfo(age: age < 0 ? 0 : age);
  }
}

class _PhaseInfo {
  const _PhaseInfo({
    required this.title,
    required this.description,
    required this.colorHint,
    this.minAge = 0,
    this.maxAge = 200,
  });

  final String title;
  final String description;
  final String colorHint;
  final int minAge;
  final int maxAge;

  bool contains(int age) => age >= minAge && age <= maxAge;
}

_PhaseInfo _phaseForAge(int age) {
  if (age <= 15) {
    return const _PhaseInfo(
      title: 'Juventude (12–15)',
      description:
          'Fase de base: corpo, higiene, limites, telas e primeiros passos de autonomia.',
      colorHint: 'Saúde',
      minAge: 12,
      maxAge: 15,
    );
  }
  if (age <= 20) {
    return const _PhaseInfo(
      title: 'Adolescência (16–20)',
      description:
          'Postura, educação digital, documentos, consentimento, dinheiro básico e direção.',
      colorHint: 'Digital',
      minAge: 16,
      maxAge: 20,
    );
  }
  if (age <= 29) {
    return const _PhaseInfo(
      title: 'Jovem adulto (21–29)',
      description:
          'Tempo, saúde preventiva, networking, trabalho, dinheiro e relações adultas.',
      colorHint: 'Finanças',
      minAge: 21,
      maxAge: 29,
    );
  }
  return const _PhaseInfo(
    title: 'Adulto consolidado (30+)',
    description:
        'Autoconhecimento, luto, legado, liderança e construção de vida com mais intenção.',
    colorHint: 'Legado',
    minAge: 30,
    maxAge: 200,
  );
}

class _JourneyPalette {
  const _JourneyPalette({
    required this.primary,
    required this.secondary,
    required this.soft,
  });

  final Color primary;
  final Color secondary;
  final Color soft;
}

class _LifeJourneyColors {
  static _JourneyPalette forCategory(String category) {
    switch (category.toLowerCase()) {
      case 'saúde':
        return const _JourneyPalette(
          primary: Color(0xFF22C55E),
          secondary: Color(0xFF10B981),
          soft: Color(0xFFBBF7D0),
        );
      case 'finanças':
        return const _JourneyPalette(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFF97316),
          soft: Color(0xFFFDE68A),
        );
      case 'digital':
        return const _JourneyPalette(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF2563EB),
          soft: Color(0xFFBAE6FD),
        );
      case 'relações':
        return const _JourneyPalette(
          primary: Color(0xFFEC4899),
          secondary: Color(0xFFFB7185),
          soft: Color(0xFFFBCFE8),
        );
      case 'trabalho':
        return const _JourneyPalette(
          primary: Color(0xFFFB923C),
          secondary: Color(0xFFEF4444),
          soft: Color(0xFFFED7AA),
        );
      case 'emoções':
        return const _JourneyPalette(
          primary: Color(0xFFA78BFA),
          secondary: Color(0xFF8B5CF6),
          soft: Color(0xFFDDD6FE),
        );
      case 'segurança':
        return const _JourneyPalette(
          primary: Color(0xFFF43F5E),
          secondary: Color(0xFFEF4444),
          soft: Color(0xFFFDA4AF),
        );
      case 'legado':
        return const _JourneyPalette(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF6366F1),
          soft: Color(0xFFC4B5FD),
        );
      case 'autonomia':
        return const _JourneyPalette(
          primary: Color(0xFF14B8A6),
          secondary: Color(0xFF06B6D4),
          soft: Color(0xFF99F6E4),
        );
      case 'tempo':
        return const _JourneyPalette(
          primary: Color(0xFFEAB308),
          secondary: Color(0xFFF59E0B),
          soft: Color(0xFFFEF08A),
        );
      case 'cidadania':
        return const _JourneyPalette(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF3B82F6),
          soft: Color(0xFFC7D2FE),
        );
      case 'propósito':
        return const _JourneyPalette(
          primary: Color(0xFF818CF8),
          secondary: Color(0xFFA78BFA),
          soft: Color(0xFFDDD6FE),
        );
      case 'marco importante':
        return const _JourneyPalette(
          primary: Color(0xFF60A5FA),
          secondary: Color(0xFFA78BFA),
          soft: Color(0xFFDBEAFE),
        );
      case 'base':
      default:
        return const _JourneyPalette(
          primary: Color(0xFF60A5FA),
          secondary: Color(0xFF34D399),
          soft: Color(0xFFBFDBFE),
        );
    }
  }
}

List<String> _tipsForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'finanças':
      return const [
        'Transforme conhecimento em pequenas regras práticas para o seu mês, não só em teoria bonita.',
        'Use esse marco para criar um padrão que proteja sua liberdade futura.',
        'O app pode te lembrar que clareza vale mais do que impulso.',
      ];
    case 'saúde':
      return const [
        'O melhor uso desse conteúdo é virar rotina possível, não cobrança perfeita.',
        'Corpo bem cuidado aumenta foco, humor e consistência em outras áreas.',
        'Pequenos ajustes sustentados costumam vencer grandes promessas curtas.',
      ];
    case 'digital':
      return const [
        'Aprenda a usar a tecnologia com intenção, não só por reflexo.',
        'Boa educação digital protege reputação, foco e paz mental.',
        'O app pode cruzar isso com seus dados de tela e te dar alertas mais inteligentes.',
      ];
    case 'relações':
      return const [
        'Relação boa não elimina limites; ela melhora quando eles existem.',
        'Observe atitudes mais do que promessas para avaliar segurança e respeito.',
        'Esse aprendizado ajuda tanto em família quanto em amizade e namoro.',
      ];
    case 'emoções':
      return const [
        'Nomear o que sente dá mais controle do que fingir que nada acontece.',
        'Autoconhecimento bem usado reduz repetição de padrões ruins.',
        'Esse tema conversa muito com estresse, humor e constância dentro do app.',
      ];
    case 'autonomia':
      return const [
        'Saber se virar no básico diminui dependência e aumenta confiança real.',
        'Autonomia prática não é glamour, é paz mental no cotidiano.',
        'Esse tipo de habilidade costuma sustentar melhor todas as outras áreas.',
      ];
    case 'legado':
      return const [
        'Pense menos em imagem e mais no que permanece quando o dia acaba.',
        'Legado pode ser caráter, presença, trabalho bem feito ou cuidado com quem depende de você.',
        'Esse tema ajuda a tirar a vida do modo apenas reativo.',
      ];
    default:
      return const [
        'Use esse marco como guia para o momento da vida em que ele aparece.',
        'A ideia não é saber tudo agora, e sim receber o conteúdo certo perto da hora certa.',
        'Quanto mais isso vira prática, mais a Linha da Vida faz sentido dentro do app.',
      ];
  }
}

String _formatDate(DateTime date) {
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatMilestoneChip(
  LifeJourneyMilestone milestone,
  DateTime unlockDate,
) {
  if (milestone.isMajor) {
    return '${unlockDate.year} • ${milestone.label}';
  }
  return milestone.label;
}
