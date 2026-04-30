// lib/features/reflexo_card_game/presentation/widgets/reflexo_destiny_panel.dart
//
// Painel da Fase de Destino do Reflexo Card Game.
// Correção desta versão:
// - Remove Spacer dentro dos cards de Destino, que quebrava layout em ListView.
// - Usa altura fixa/segura para as opções de Destino.
// - Mantém texto maior, direto e legível.
// - Evita tela preta causada por RenderBox/RenderFlex sem tamanho.

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
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${player.name} · Destino',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _DiceButton(
                roll: player.lastRoll,
                enabled: selected != null && !alreadyRolled,
                onTap: onRoll,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (options.isEmpty)
            Container(
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                'Nenhum Destino disponível.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SizedBox(
              height: 126,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: options.take(3).map((option) {
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
            ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            _SelectedStatusLine(player: player, selected: selected),
          ],
        ],
      ),
    );
  }
}

class _SelectedStatusLine extends StatelessWidget {
  const _SelectedStatusLine({required this.player, required this.selected});

  final ReflexoPlayerState player;
  final ReflexoDestinyOption selected;

  @override
  Widget build(BuildContext context) {
    final roll = player.lastRoll;
    final text = roll == null
        ? 'Selecionado: ${selected.name}. Role o d20.'
        : 'Rolagem: $roll · ${selected.requirement}+ necessário.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.76),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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

  Color get _riskColor {
    if (option.requirement >= 18) return const Color(0xFFA855F7);
    if (option.requirement >= 10) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  String get _riskLabel {
    if (option.requirement >= 18) return 'Arriscado';
    if (option.requirement >= 10) return 'Médio';
    return 'Seguro';
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
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
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 13, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _riskLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                option.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                option.shortText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.94),
                  fontSize: 15,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Expanded(child: SizedBox.shrink()),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      option.durationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
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
    final hasRoll = roll != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: hasRoll ? 66 : 58,
          height: hasRoll ? 66 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: enabled
                  ? const [
                      Color(0xFF93C5FD),
                      Color(0xFF2563EB),
                      Color(0xFF111827),
                    ]
                  : const [
                      Color(0xFF334155),
                      Color(0xFF1E293B),
                      Color(0xFF020617),
                    ],
              radius: 0.95,
            ),
            border: Border.all(
              color: enabled ? Colors.white70 : Colors.white24,
            ),
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
              hasRoll ? '$roll' : 'd20',
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
