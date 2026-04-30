// lib/features/reflexo_card_game/presentation/widgets/reflexo_duel_hud.dart

import 'package:flutter/material.dart';

import '../../domain/reflexo_content.dart';
import '../../domain/reflexo_models.dart';
import 'reflexo_card_widgets.dart';

class ReflexoDuelHud extends StatelessWidget {
  const ReflexoDuelHud({super.key, required this.player, required this.active});

  final ReflexoPlayerState player;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF172554) : const Color(0xFF101827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? const Color(0xFF60A5FA) : Colors.white12,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Este é o Reflexo do jogador nesta partida.',
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _HudPill(
                icon: Icons.favorite_rounded,
                label: '${player.life}',
                color: const Color(0xFFEF4444),
                tooltip: 'Vida do Reflexo. Se chegar a 0, perde a partida.',
              ),
              const SizedBox(width: 5),
              _HudPill(
                icon: Icons.bolt_rounded,
                label: '${player.energy}',
                color: const Color(0xFFF59E0B),
                tooltip: 'Energia disponível neste turno para jogar cartas.',
              ),
              const SizedBox(width: 5),
              _HudPill(
                icon: Icons.inventory_2_rounded,
                label: '${player.reserve}',
                color: const Color(0xFF38BDF8),
                tooltip:
                    'Reserva: energia guardada de turnos anteriores. Limite normal: 10.',
              ),
              const SizedBox(width: 5),
              _HudPill(
                icon: Icons.style_rounded,
                label: '${player.hand.length}',
                color: const Color(0xFF22C55E),
                tooltip: 'Quantidade de cartas na mão.',
              ),
              const SizedBox(width: 5),
              _HudPill(
                icon: Icons.casino_rounded,
                label: player.lastRoll == null ? '-' : '${player.lastRoll}',
                color: const Color(0xFFA855F7),
                tooltip:
                    'Último resultado do d20 deste jogador. Ele fica visível até a próxima rolagem.',
              ),
            ],
          ),
          const SizedBox(height: 7),
          Tooltip(
            message:
                'Arquétipo principal + secundário. Eles definem o estilo base do deck e dos buffs.',
            child: Text(
              '${player.mainArchetype.label} + ${player.secondaryArchetype.label}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          ReflexoBuffChips(buffs: player.buffs),
        ],
      ),
    );
  }
}

class ReflexoTimelinePanel extends StatelessWidget {
  const ReflexoTimelinePanel({
    super.key,
    required this.round,
    required this.phase,
    required this.activePlayer,
    required this.logs,
  });

  final int round;
  final ReflexoMatchPhase phase;
  final ReflexoPlayerId activePlayer;
  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    final next = phase == ReflexoMatchPhase.destiny
        ? 'Depois: turno do Jogador 1'
        : activePlayer == ReflexoPlayerId.one
        ? 'Depois: turno do Jogador 2'
        : 'Depois: nova Fase de Destino';
    return Tooltip(
      message:
          'Linha do tempo: mostra a fase atual, o que vem depois e os últimos eventos da partida.',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xCC050816),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  phase == ReflexoMatchPhase.destiny
                      ? Icons.casino_rounded
                      : Icons.sports_martial_arts_rounded,
                  color: const Color(0xFF60A5FA),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rodada $round · ${_phaseLabel(phase, activePlayer)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              next,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 42,
              child: ListView.builder(
                reverse: false,
                itemCount: logs.take(3).length,
                itemBuilder: (context, index) {
                  return Text(
                    '• ${logs[index]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: index == 0 ? 0.92 : 0.60,
                      ),
                      fontSize: 10,
                      fontWeight: index == 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(ReflexoMatchPhase phase, ReflexoPlayerId active) {
    switch (phase) {
      case ReflexoMatchPhase.destiny:
        return 'Fase de Destino';
      case ReflexoMatchPhase.playerTurn:
        return 'Turno do ${active.label}';
      case ReflexoMatchPhase.gameOver:
        return 'Fim de jogo';
    }
  }
}

class ReflexoAttributesPanel extends StatelessWidget {
  const ReflexoAttributesPanel({super.key, required this.player});

  final ReflexoPlayerState player;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Atributos do ${player.name}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...player.attributes.entries.map((entry) {
            final value = entry.value / 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message:
                    '${entry.key.label}: atributo do Reflexo usado para modificar cartas, buffs e rolagens.',
                child: Row(
                  children: [
                    Icon(
                      entry.key.icon,
                      color: const Color(0xFF93C5FD),
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 82,
                      child: Text(
                        entry.key.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: value.clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            ReflexoContent.archetypePassive(player.mainArchetype, main: true),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ReflexoContent.archetypePassive(
              player.secondaryArchetype,
              main: false,
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
