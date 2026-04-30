// lib/features/reflexo_card_game/presentation/widgets/reflexo_card_widgets.dart

import 'package:flutter/material.dart';

import '../../domain/reflexo_models.dart';

class ReflexoCardTile extends StatelessWidget {
  const ReflexoCardTile({
    super.key,
    required this.card,
    required this.cost,
    required this.onTap,
    this.enabled = true,
  });

  final ReflexoCardDefinition card;
  final int cost;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => showReflexoCardDetails(context, card),
        child: Container(
          width: 106,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF18213D), Color(0xFF090D18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CardImageBox(
                      imageAsset: card.imageAsset,
                      icon: card.attribute.icon,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _StatPill(
                              label: 'C $cost',
                              color: const Color(0xFF60A5FA),
                            ),
                            const Spacer(),
                            _StatPill(
                              label: 'A ${card.attack}',
                              color: const Color(0xFFF97316),
                            ),
                            const SizedBox(width: 3),
                            _StatPill(
                              label: 'V ${card.health}',
                              color: const Color(0xFF22C55E),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!enabled)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'sem energia',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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

class ReflexoUnitCard extends StatelessWidget {
  const ReflexoUnitCard({
    super.key,
    required this.unit,
    required this.selected,
    this.isAttacker = false,
    this.isTarget = false,
    required this.onTap,
  });

  final ReflexoUnitInstance unit;
  final bool selected;
  final bool isAttacker;
  final bool isTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isTarget
        ? const Color(0xFFEF4444)
        : selected
        ? const Color(0xFF38BDF8)
        : unit.readyToAttack
        ? const Color(0xFF22C55E)
        : Colors.white24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      onLongPress: () => showReflexoUnitDetails(context, unit),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isAttacker
            ? 1.10
            : isTarget
            ? 0.94
            : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 68,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF1B2542), Color(0xFF0A0F1D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x8838BDF8),
                      blurRadius: 16,
                      offset: Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 25),
                  child: _CardImageBox(
                    imageAsset: unit.card.imageAsset,
                    icon: unit.card.attribute.icon,
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 3,
                child: _StatPill(
                  label: 'A ${unit.visibleAttack}',
                  color: const Color(0xFFF97316),
                ),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: _StatPill(
                  label: 'V ${unit.health}',
                  color: const Color(0xFF22C55E),
                ),
              ),
              if (unit.shield > 0)
                Positioned(
                  bottom: 21,
                  right: 3,
                  child: _StatPill(
                    label: 'E ${unit.shield}',
                    color: const Color(0xFF60A5FA),
                  ),
                ),
              if (unit.hasBarrier)
                const Positioned(
                  bottom: 21,
                  left: 4,
                  child: Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF93C5FD),
                    size: 14,
                  ),
                ),
              Positioned(
                left: 5,
                right: 5,
                bottom: 4,
                child: Text(
                  unit.card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: unit.readyToAttack ? Colors.white : Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
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

class ReflexoEmptySlot extends StatelessWidget {
  const ReflexoEmptySlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        color: Colors.white.withValues(alpha: 0.025),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white12),
    );
  }
}

class ReflexoBuffChips extends StatelessWidget {
  const ReflexoBuffChips({super.key, required this.buffs});

  final List<ReflexoActiveBuff> buffs;

  @override
  Widget build(BuildContext context) {
    if (buffs.isEmpty) {
      return Text(
        'Sem buffs ativos',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 11,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: buffs.map((buff) {
        final duration = buff.turnsRemaining == null
            ? '∞'
            : '${buff.turnsRemaining}T';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '${buff.summary} · $duration',
            style: const TextStyle(
              color: Color(0xFFBFDBFE),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CardImageBox extends StatelessWidget {
  const _CardImageBox({required this.imageAsset, required this.icon});

  final String? imageAsset;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    if (asset != null && asset.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const RadialGradient(
          colors: [Color(0xFF334155), Color(0xFF0F172A)],
          radius: 1.0,
        ),
      ),
      child: Center(child: Icon(icon, color: Colors.white70, size: 25)),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

void showReflexoCardDetails(BuildContext context, ReflexoCardDefinition card) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _CardDetailsSheet(card: card);
    },
  );
}

void showReflexoUnitDetails(BuildContext context, ReflexoUnitInstance unit) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _UnitDetailsSheet(unit: unit);
    },
  );
}

class _CardDetailsSheet extends StatelessWidget {
  const _CardDetailsSheet({required this.card});
  final ReflexoCardDefinition card;

  @override
  Widget build(BuildContext context) {
    return _DetailsShell(
      title: card.name,
      children: [
        _DetailLine('Custo', '${card.cost}'),
        _DetailLine('Ataque', '${card.attack}'),
        _DetailLine('Vida', '${card.health}'),
        _DetailLine('Escudo', '${card.shield}'),
        _DetailLine('Atributo', card.attribute.label),
        _DetailLine('Arquétipo', card.archetype.label),
        if (card.secondaryAttribute != null)
          _DetailLine('Secundário', card.secondaryAttribute!.label),
        if (card.abilities.isNotEmpty)
          _DetailLine(
            'Habilidades',
            card.abilities.map((e) => e.label).join(', '),
          ),
        if (card.text.isNotEmpty) _DetailParagraph(card.text),
      ],
    );
  }
}

class _UnitDetailsSheet extends StatelessWidget {
  const _UnitDetailsSheet({required this.unit});
  final ReflexoUnitInstance unit;

  @override
  Widget build(BuildContext context) {
    return _DetailsShell(
      title: unit.card.name,
      children: [
        _DetailLine('Ataque atual', '${unit.visibleAttack}'),
        _DetailLine('Vida atual', '${unit.health}/${unit.maxHealth}'),
        _DetailLine('Escudo', '${unit.shield}'),
        _DetailLine('Pode atacar', unit.readyToAttack ? 'Sim' : 'Não'),
        _DetailLine('Atributo', unit.card.attribute.label),
        if (unit.card.abilities.isNotEmpty)
          ...unit.card.abilities.map(
            (a) => _DetailParagraph('${a.label}: ${a.description}'),
          ),
        if (unit.temporaryBuffs.isNotEmpty)
          _DetailLine(
            'Buffs',
            unit.temporaryBuffs.map((e) => e.summary).join(', '),
          ),
      ],
    );
  }
}

class _DetailsShell extends StatelessWidget {
  const _DetailsShell({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1020),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailParagraph extends StatelessWidget {
  const _DetailParagraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          height: 1.3,
        ),
      ),
    );
  }
}
