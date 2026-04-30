// lib/features/reflexo_card_game/presentation/widgets/reflexo_destiny_panel.dart

import 'package:flutter/material.dart';

import '../../domain/reflexo_models.dart';

class ReflexoDestinyPanel extends StatelessWidget {
  const ReflexoDestinyPanel({
    super.key,
    required this.player,
    required this.round,
    required this.options,
    required this.onSelect,
    required this.onRoll,
  });

  final ReflexoPlayerState player;
  final int round;
  final List<ReflexoDestinyOption> options;
  final ValueChanged<ReflexoDestinyOption> onSelect;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    final selected = player.selectedDestiny;
    final alreadyRolled = player.lastRollRound == round;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEA0B1020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${player.name} · escolha seu Destino',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _DiceButton(
                roll: player.lastRoll,
                enabled: selected != null && !alreadyRolled,
                onTap: onRoll,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: options.map((option) {
              final isSelected = selected?.id == option.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DestinyOptionCard(
                    option: option,
                    selected: isSelected,
                    disabled: alreadyRolled,
                    onTap: () => onSelect(option),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DestinyOptionCard extends StatelessWidget {
  const _DestinyOptionCard({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final ReflexoDestinyOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = option.requirement >= 18
        ? const Color(0xFFA855F7)
        : option.requirement >= 10
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22C55E);
    return Tooltip(
      message: option.fullText.isEmpty ? option.shortText : option.fullText,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 126,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.24 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.38),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.shortText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.casino_rounded, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '${option.requirement}+',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      option.durationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiceButton extends StatelessWidget {
  const _DiceButton({
    required this.roll,
    required this.enabled,
    required this.onTap,
  });

  final int? roll;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'Rola o d20 deste jogador. O valor fica visível até a próxima rolagem.',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: roll == null ? 58 : 66,
          height: roll == null ? 58 : 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8), Color(0xFF111827)],
              radius: 0.95,
            ),
            border: Border.all(color: Colors.white54),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0xAA2563EB),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Text(
              roll == null ? 'd20' : '$roll',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
