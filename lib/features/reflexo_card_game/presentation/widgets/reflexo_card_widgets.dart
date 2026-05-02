// ============================================================================
// FILE: lib/features/reflexo_card_game/presentation/widgets/reflexo_card_widgets.dart
// ============================================================================

import 'package:flutter/material.dart';

import '../../domain/reflexo_models.dart';

class ReflexoCardTile extends StatelessWidget {
  const ReflexoCardTile({
    super.key,
    required this.card,
    required this.cost,
    required this.onTap,
    this.enabled = true,
    this.compact = false,
  });

  final ReflexoCardDefinition card;
  final int cost;
  final VoidCallback onTap;
  final bool enabled;
  final bool compact;

  Color get _typeColor {
    switch (card.type) {
      case ReflexoCardType.unit:
        return const Color(0xFF60A5FA);
      case ReflexoCardType.spell:
        return const Color(0xFFA78BFA);
      case ReflexoCardType.trap:
        return const Color(0xFFF472B6);
      case ReflexoCardType.equipment:
        return const Color(0xFFFBBF24);
    }
  }

  IconData get _typeIcon {
    switch (card.type) {
      case ReflexoCardType.unit:
        return Icons.person_rounded;
      case ReflexoCardType.spell:
        return Icons.auto_fix_high_rounded;
      case ReflexoCardType.trap:
        return Icons.visibility_off_rounded;
      case ReflexoCardType.equipment:
        return Icons.construction_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.42;
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => showReflexoCardDetails(context, card),
        child: Stack(
          children: [
            Container(
              width: compact ? 82 : 108,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF18213D), Color(0xFF090D18)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: _typeColor.withValues(alpha: 0.55)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _CardImageBox(
                      imageAsset: card.imageAsset,
                      icon: _typeIcon,
                      color: _typeColor,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 6 : 8,
                      compact ? 4 : 5,
                      compact ? 6 : 8,
                      compact ? 5 : 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 9 : 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StatPill(
                                label: '$cost',
                                color: const Color(0xFF60A5FA),
                              ),
                              const SizedBox(width: 3),
                              _LevelPill(level: card.level),
                              const SizedBox(width: 8),
                              if (card.isUnit) ...[
                                _StatPill(
                                  label: '${card.attack}',
                                  color: const Color(0xFFF97316),
                                ),
                                const SizedBox(width: 3),
                                _StatPill(
                                  label: '${card.health}',
                                  color: const Color(0xFF22C55E),
                                ),
                              ] else
                                _StatPill(
                                  label: _typeLabel(card.type),
                                  color: _typeColor,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (card.isHeavy)
              Positioned(
                top: 7,
                right: 15,
                child: _Badge(text: 'P', color: const Color(0xFFFBBF24)),
              ),
            if (!enabled)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'sem energia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(ReflexoCardType type) {
    switch (type) {
      case ReflexoCardType.unit:
        return 'UN';
      case ReflexoCardType.spell:
        return 'MAG';
      case ReflexoCardType.trap:
        return 'ARM';
      case ReflexoCardType.equipment:
        return 'EQP';
    }
  }
}

class ReflexoUnitCard extends StatelessWidget {
  const ReflexoUnitCard({
    super.key,
    required this.unit,
    required this.selected,
    required this.onTap,
    this.isAttacking = false,
    this.isTargeted = false,
    this.canBeTargeted = false,
    this.tooStrong = false,
  });

  final ReflexoUnitInstance unit;
  final bool selected;
  final VoidCallback onTap;
  final bool isAttacking;
  final bool isTargeted;
  final bool canBeTargeted;
  final bool tooStrong;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF38BDF8)
        : canBeTargeted
        ? const Color(0xFF22C55E)
        : tooStrong
        ? const Color(0xFFF97316)
        : isTargeted
        ? const Color(0xFFEF4444)
        : isAttacking
        ? const Color(0xFFFBBF24)
        : unit.readyToAttack
        ? const Color(0xFF22C55E)
        : Colors.white24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      onLongPress: () => showReflexoUnitDetails(context, unit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        transform: Matrix4.translationValues(0, isAttacking ? -7 : 0, 0)
          ..scale(isTargeted ? 0.95 : 1.0),
        width: 68,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B2542), Color(0xFF0A0F1D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: borderColor,
            width: selected || isTargeted || canBeTargeted ? 2 : 1,
          ),
          boxShadow: selected || isAttacking || isTargeted || canBeTargeted
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.55),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
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
                  color: const Color(0xFF60A5FA),
                ),
              ),
            ),
            Positioned(
              top: 3,
              left: 3,
              child: _StatPill(
                label: '${unit.visibleAttack}',
                color: const Color(0xFFF97316),
              ),
            ),
            Positioned(
              top: 3,
              right: 3,
              child: _StatPill(
                label: '${unit.health}',
                color: const Color(0xFF22C55E),
              ),
            ),
            if (unit.shield > 0)
              Positioned(
                bottom: 21,
                right: 3,
                child: _StatPill(
                  label: '${unit.shield}',
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
            if (unit.isHeavy)
              const Positioned(
                top: 22,
                left: 4,
                child: _Badge(text: 'P', color: Color(0xFFFBBF24)),
              ),
            if (canBeTargeted || tooStrong)
              Positioned(
                top: 35,
                left: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        (canBeTargeted
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFF97316))
                            .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    canBeTargeted ? 'ALVO' : 'FORTE',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
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
    );
  }
}

class ReflexoTrapSlot extends StatelessWidget {
  const ReflexoTrapSlot({super.key, required this.trapCount});

  final int trapCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Armadilhas preparadas. O adversário vê que existem, mas não sabe qual é.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(2, (index) {
          final active = index < trapCount;
          return Container(
            width: 28,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFFF472B6), Color(0xFF581C87)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: active ? null : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: active ? Colors.white38 : Colors.white10,
              ),
            ),
            child: Icon(
              active
                  ? Icons.visibility_off_rounded
                  : Icons.crop_portrait_rounded,
              color: active ? Colors.white : Colors.white24,
              size: 15,
            ),
          );
        }),
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
        return Tooltip(
          message: '${buff.name}: ${buff.summary}',
          child: Container(
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
          ),
        );
      }).toList(),
    );
  }
}

class _CardImageBox extends StatelessWidget {
  const _CardImageBox({
    required this.imageAsset,
    required this.icon,
    required this.color,
  });

  final String? imageAsset;
  final IconData icon;
  final Color color;

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
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.70), const Color(0xFF0F172A)],
          radius: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.80),
          size: 25,
        ),
      ),
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

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Nível $level: indica o peso/custo geral da carta.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          'N$level',
          style: const TextStyle(
            color: Color(0xFFFBBF24),
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Carta pesada: forte, mas vulnerável a ataque combinado e anti-tanque.',
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

void showReflexoCardDetails(BuildContext context, ReflexoCardDefinition card) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _CardDetailsSheet(card: card),
  );
}

void showReflexoUnitDetails(BuildContext context, ReflexoUnitInstance unit) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _UnitDetailsSheet(unit: unit),
  );
}

class _CardDetailsSheet extends StatelessWidget {
  const _CardDetailsSheet({required this.card});
  final ReflexoCardDefinition card;

  @override
  Widget build(BuildContext context) {
    return _DetailsShell(
      title: card.name,
      imageAsset: card.imageAsset,
      children: [
        _DetailLine('Tipo', _typeName(card.type)),
        _DetailLine('Nível', '${card.level}'),
        _DetailLine('Custo', '${card.cost}'),
        if (card.isUnit) ...[
          _DetailLine('Ataque', '${card.attack}'),
          _DetailLine('Vida', '${card.health}'),
          _DetailLine('Escudo', '${card.shield}'),
        ],
        _DetailLine('Atributo', card.attribute.label),
        _DetailLine('Arquétipo', card.archetype.label),
        if (card.isHeavy)
          const _DetailParagraph(
            'Pesada: pode dominar o campo, mas sofre contra ataque combinado e cartas anti-tanque.',
          ),
        if (card.abilities.isNotEmpty)
          _DetailLine(
            'Habilidades',
            card.abilities.map((e) => e.label).join(', '),
          ),
        if (card.text.isNotEmpty) _DetailParagraph(card.text),
      ],
    );
  }

  String _typeName(ReflexoCardType type) {
    switch (type) {
      case ReflexoCardType.unit:
        return 'Unidade';
      case ReflexoCardType.spell:
        return 'Feitiço';
      case ReflexoCardType.trap:
        return 'Armadilha virada';
      case ReflexoCardType.equipment:
        return 'Equipamento';
    }
  }
}

class _UnitDetailsSheet extends StatelessWidget {
  const _UnitDetailsSheet({required this.unit});
  final ReflexoUnitInstance unit;

  @override
  Widget build(BuildContext context) {
    return _DetailsShell(
      title: unit.card.name,
      imageAsset: unit.card.imageAsset,
      children: [
        _DetailLine('Ataque atual', '${unit.visibleAttack}'),
        _DetailLine('Vida atual', '${unit.health}/${unit.maxHealth}'),
        _DetailLine('Escudo', '${unit.shield}'),
        _DetailLine('Pode atacar', unit.readyToAttack ? 'Sim' : 'Não'),
        _DetailLine('Atributo', unit.card.attribute.label),
        if (unit.isHeavy)
          const _DetailParagraph(
            'Pesada: ataque combinado é o melhor jeito de derrubar esta carta.',
          ),
        if (unit.card.abilities.isNotEmpty)
          ...unit.card.abilities.map(
            (a) => _DetailParagraph('${a.label}: ${a.description}'),
          ),
      ],
    );
  }
}

class _DetailsShell extends StatelessWidget {
  const _DetailsShell({
    required this.title,
    required this.children,
    this.imageAsset,
  });
  final String title;
  final String? imageAsset;
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
            Row(
              children: [
                if (imageAsset != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imageAsset!,
                      width: 58,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 0),
                    ),
                  ),
                if (imageAsset != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
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
