// lib/features/reflexo_card_game/presentation/widgets/reflexo_duel_hud.dart

import 'package:flutter/material.dart';

import '../../domain/reflexo_models.dart';
import 'reflexo_card_widgets.dart';

class ReflexoDuelHud extends StatelessWidget {
  const ReflexoDuelHud({super.key, required this.player, required this.active});

  final ReflexoPlayerState player;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF38BDF8) : Colors.white24;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE60B1020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: active ? 1.6 : 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Tooltip(
                message:
                    '${player.name}: ${player.mainArchetype.label}. ${player.mainArchetype.basePassive}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: player.archetypeAwakened
                          ? const [Color(0xFFFBBF24), Color(0xFFA855F7)]
                          : const [Color(0xFF2563EB), Color(0xFF111827)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Icon(
                    player.mainArchetype.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.mainArchetype.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (player.archetypeAwakened) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFFBBF24),
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: player.archetypeAwakened
                            ? 1
                            : player.archetypeProgressRatio,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: player.archetypeAwakened
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      player.archetypeAwakened
                          ? 'Desperto: ${player.mainArchetype.awakenedPassive}'
                          : '${player.archetypeProgress}/${player.archetypeGoal} · ${player.mainArchetype.awakenCondition}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'Última rolagem de d20 deste jogador. Fica visível até a próxima rolagem.',
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF60A5FA),
                        Color(0xFF1D4ED8),
                        Color(0xFF111827),
                      ],
                      radius: 0.95,
                    ),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: Center(
                    child: Text(
                      player.lastRoll == null ? 'd20' : '${player.lastRoll}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _HudPill(
                icon: Icons.favorite_rounded,
                label: '${player.life}',
                color: const Color(0xFF22C55E),
                help: 'Vida do Reflexo. Se chegar a 0, perde.',
              ),
              _HudPill(
                icon: Icons.bolt_rounded,
                label: '${player.energy}',
                color: const Color(0xFF60A5FA),
                help: 'Energia atual para jogar cartas neste turno.',
              ),
              _HudPill(
                icon: Icons.inventory_2_rounded,
                label: '${player.reserve}',
                color: const Color(0xFF93C5FD),
                help: 'Reserva guardada para turnos futuros. Limite 10.',
              ),
              _HudPill(
                icon: Icons.style_rounded,
                label: '${player.hand.length}',
                color: const Color(0xFFA78BFA),
                help: 'Cartas na mão.',
              ),
              const SizedBox(width: 4),
              ReflexoTrapSlot(trapCount: player.traps.length),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ReflexoBuffChips(buffs: player.buffs),
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
    required this.help,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: help,
      child: Container(
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.34)),
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

class ReflexoTimelinePanel extends StatelessWidget {
  const ReflexoTimelinePanel({
    super.key,
    required this.round,
    required this.phase,
    required this.activePlayer,
    required this.logs,
    this.pressureEvent,
  });

  final int round;
  final ReflexoMatchPhase phase;
  final ReflexoPlayerId activePlayer;
  final List<String> logs;
  final ReflexoPressureEvent? pressureEvent;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      ReflexoMatchPhase.destiny => 'Destino',
      ReflexoMatchPhase.tactic => 'Tática',
      ReflexoMatchPhase.pressure => 'Pressão',
      ReflexoMatchPhase.playerTurn => 'Turno ${activePlayer.label}',
      ReflexoMatchPhase.gameOver => 'Fim',
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tooltip(
                message: 'Ciclo: Destino → Tática → Pressão → repete.',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'R$round · $label',
                    style: const TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (pressureEvent != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pressureEvent!.name}: ${pressureEvent!.shortText}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              logs.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
