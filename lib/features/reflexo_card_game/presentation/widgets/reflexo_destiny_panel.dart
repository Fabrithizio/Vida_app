// ============================================================================
// FILE: lib/features/reflexo_card_game/presentation/widgets/reflexo_destiny_panel.dart
// ============================================================================

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
    final rolled = player.lastRollRound == round;
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
                  '${player.name} · Destino',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  player.lastRoll == null ? 'd20' : 'd20: ${player.lastRoll}',
                  style: const TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((option) {
              final isSelected = selected?.id == option.id;
              final palette = _paletteFor(option.requirement);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: option.fullText.isEmpty
                        ? option.shortText
                        : option.fullText,
                    child: InkWell(
                      onTap: rolled ? null : () => onSelect(option),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 114,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: palette.background.withValues(
                            alpha: isSelected ? 0.36 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? palette.border : Colors.white12,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.border.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                palette.label,
                                style: TextStyle(
                                  color: palette.border,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              option.name,
                              maxLines: 1,
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
                                color: palette.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Precisa: ${option.requirement}+',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: selected != null && !rolled ? onRoll : null,
            icon: const Icon(Icons.casino_rounded),
            label: Text(rolled ? 'Dado rolado' : 'Rolar d20'),
          ),
        ],
      ),
    );
  }

  _DestinyPalette _paletteFor(int requirement) {
    if (requirement <= 7) {
      return const _DestinyPalette(
        background: Color(0xFF14532D),
        border: Color(0xFF4ADE80),
        text: Color(0xFFBBF7D0),
        label: 'COMUM',
      );
    }
    if (requirement <= 12) {
      return const _DestinyPalette(
        background: Color(0xFF4C1D95),
        border: Color(0xFFC084FC),
        text: Color(0xFFE9D5FF),
        label: 'RARO',
      );
    }
    return const _DestinyPalette(
      background: Color(0xFF78350F),
      border: Color(0xFFFBBF24),
      text: Color(0xFFFDE68A),
      label: 'ÉPICO',
    );
  }
}

class _DestinyPalette {
  const _DestinyPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color text;
  final String label;
}
