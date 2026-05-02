// ============================================================================
// FILE: lib/features/reflexo_card_game/presentation/pages/reflexo_duel_page.dart
// ============================================================================

import 'package:flutter/material.dart';

import '../../application/reflexo_duel_controller.dart';
import '../../domain/reflexo_models.dart';
import '../widgets/reflexo_card_widgets.dart';
import '../widgets/reflexo_destiny_panel.dart';
import '../widgets/reflexo_duel_hud.dart';

class ReflexoDuelPage extends StatefulWidget {
  const ReflexoDuelPage({
    super.key,
    this.vsBot = false,
    this.playerDeckIds,
    this.playerArchetype,
  });

  final bool vsBot;
  final List<String>? playerDeckIds;
  final ReflexoArchetype? playerArchetype;

  @override
  State<ReflexoDuelPage> createState() => _ReflexoDuelPageState();
}

class _ReflexoDuelPageState extends State<ReflexoDuelPage> {
  late final ReflexoDuelController controller;
  int _lastBannerSerial = -1;

  @override
  void initState() {
    super.initState();
    controller = ReflexoDuelController(
      vsBot: widget.vsBot,
      playerDeckIds: widget.playerDeckIds,
      playerArchetype: widget.playerArchetype,
    );
    controller.addListener(_showBannerIfNeeded);
  }

  @override
  void dispose() {
    controller.removeListener(_showBannerIfNeeded);
    controller.dispose();
    super.dispose();
  }

  void _showBannerIfNeeded() {
    final state = controller.state;
    final banner = state.lastBanner;
    if (!mounted || banner == null || state.eventSerial == _lastBannerSerial) {
      return;
    }
    _lastBannerSerial = state.eventSerial;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(banner),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _rollAndRevealDestiny(ReflexoPlayerId playerId) async {
    final round = controller.state.round;
    controller.rollDestiny(playerId);
    if (!mounted) return;
    final player = controller.state.player(playerId);
    if (player.lastRollRound != round || player.lastRoll == null) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dado',
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _DiceRevealDialog(player: player),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final p1 = state.player(ReflexoPlayerId.one);
        final p2 = state.player(ReflexoPlayerId.two);

        return Scaffold(
          backgroundColor: const Color(0xFF050816),
          appBar: AppBar(
            backgroundColor: const Color(0xFF050816),
            foregroundColor: Colors.white,
            title: Text(widget.vsBot ? 'Duelo vs Bot' : 'Duelo de Reflexos'),
            actions: [
              IconButton(
                tooltip: 'Reiniciar',
                onPressed: controller.startNewGame,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.25,
                        colors: [Color(0xFF172554), Color(0xFF050816)],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: switch (state.phase) {
                    ReflexoMatchPhase.destiny => _DestinyPhaseBody(
                      state: state,
                      playerOne: p1,
                      playerTwo: p2,
                      onSelectOne: (option) =>
                          controller.selectDestiny(ReflexoPlayerId.one, option),
                      onSelectTwo: (option) =>
                          controller.selectDestiny(ReflexoPlayerId.two, option),
                      onRollOne: () =>
                          _rollAndRevealDestiny(ReflexoPlayerId.one),
                      onRollTwo: () =>
                          _rollAndRevealDestiny(ReflexoPlayerId.two),
                    ),
                    ReflexoMatchPhase.tactic => _TacticPhaseBody(
                      controller: controller,
                      state: state,
                      playerOne: p1,
                      playerTwo: p2,
                    ),
                    ReflexoMatchPhase.pressure => _PressurePhaseBody(
                      controller: controller,
                      state: state,
                      playerOne: p1,
                      playerTwo: p2,
                    ),
                    ReflexoMatchPhase.playerTurn ||
                    ReflexoMatchPhase.gameOver => _DuelPhaseBody(
                      controller: controller,
                      state: state,
                      playerOne: p1,
                      playerTwo: p2,
                    ),
                  },
                ),
                if (state.phase == ReflexoMatchPhase.gameOver)
                  _GameOverOverlay(
                    winner: state.winner,
                    onRestart: controller.startNewGame,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DestinyPhaseBody extends StatelessWidget {
  const _DestinyPhaseBody({
    required this.state,
    required this.playerOne,
    required this.playerTwo,
    required this.onSelectOne,
    required this.onSelectTwo,
    required this.onRollOne,
    required this.onRollTwo,
  });

  final ReflexoGameState state;
  final ReflexoPlayerState playerOne;
  final ReflexoPlayerState playerTwo;
  final ValueChanged<ReflexoDestinyOption> onSelectOne;
  final ValueChanged<ReflexoDestinyOption> onSelectTwo;
  final VoidCallback onRollOne;
  final VoidCallback onRollTwo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        ReflexoDuelHud(player: playerTwo, active: false),
        const SizedBox(height: 8),
        ReflexoTimelinePanel(
          round: state.round,
          phase: state.phase,
          activePlayer: state.activePlayer,
          logs: state.timeline,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              const Text(
                'Fase de Destino',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escolha um buff, role seu d20 e veja o resultado na hora. Depois os dois entram em combate.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              ReflexoDestinyPanel(
                player: playerOne,
                round: state.round,
                options: state.destinyOptions[ReflexoPlayerId.one] ?? const [],
                onSelect: onSelectOne,
                onRoll: onRollOne,
              ),
              const SizedBox(height: 12),
              ReflexoDestinyPanel(
                player: playerTwo,
                round: state.round,
                options: state.destinyOptions[ReflexoPlayerId.two] ?? const [],
                onSelect: onSelectTwo,
                onRoll: onRollTwo,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ReflexoDuelHud(player: playerOne, active: false),
      ],
    );
  }
}

class _TacticPhaseBody extends StatelessWidget {
  const _TacticPhaseBody({
    required this.controller,
    required this.state,
    required this.playerOne,
    required this.playerTwo,
  });

  final ReflexoDuelController controller;
  final ReflexoGameState state;
  final ReflexoPlayerState playerOne;
  final ReflexoPlayerState playerTwo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        ReflexoDuelHud(player: playerTwo, active: false),
        const SizedBox(height: 8),
        ReflexoTimelinePanel(
          round: state.round,
          phase: state.phase,
          activePlayer: state.activePlayer,
          logs: state.timeline,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              const Text(
                'Rodada Tática',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Escolha um plano curto para cada jogador. Sem dado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              _TacticPanel(
                player: playerOne,
                options: state.tacticOptions[ReflexoPlayerId.one] ?? const [],
                onSelect: (option) =>
                    controller.selectTactic(ReflexoPlayerId.one, option),
              ),
              const SizedBox(height: 12),
              _TacticPanel(
                player: playerTwo,
                options: state.tacticOptions[ReflexoPlayerId.two] ?? const [],
                onSelect: (option) =>
                    controller.selectTactic(ReflexoPlayerId.two, option),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ReflexoDuelHud(player: playerOne, active: false),
      ],
    );
  }
}

class _PressurePhaseBody extends StatelessWidget {
  const _PressurePhaseBody({
    required this.controller,
    required this.state,
    required this.playerOne,
    required this.playerTwo,
  });

  final ReflexoDuelController controller;
  final ReflexoGameState state;
  final ReflexoPlayerState playerOne;
  final ReflexoPlayerState playerTwo;

  @override
  Widget build(BuildContext context) {
    final pressure = state.pressureEvent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        ReflexoDuelHud(player: playerTwo, active: false),
        const SizedBox(height: 8),
        ReflexoTimelinePanel(
          round: state.round,
          phase: state.phase,
          activePlayer: state.activePlayer,
          logs: state.timeline,
          pressureEvent: pressure,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(),
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFBBF24),
                size: 42,
              ),
              const SizedBox(height: 10),
              const Text(
                'Rodada de Pressão',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                pressure?.name ?? 'Pressão',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pressure?.shortText ?? 'A rodada terá um efeito global.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: controller.startPressureCombat,
                icon: const Icon(Icons.sports_mma_rounded),
                label: const Text('Começar combate'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ReflexoDuelHud(player: playerOne, active: false),
      ],
    );
  }
}

class _TacticPanel extends StatelessWidget {
  const _TacticPanel({
    required this.player,
    required this.options,
    required this.onSelect,
  });

  final ReflexoPlayerState player;
  final List<ReflexoTacticOption> options;
  final ValueChanged<ReflexoTacticOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = player.selectedTactic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEA0B1020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${player.name} · escolha um plano',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((option) {
              final isSelected = selected?.id == option.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: option.fullText.isEmpty
                        ? option.shortText
                        : option.fullText,
                    child: InkWell(
                      onTap: selected == null ? () => onSelect(option) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 96,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: isSelected ? 0.28 : 0.11),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF60A5FA)
                                : Colors.white12,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              option.shortText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFBFDBFE),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
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
        ],
      ),
    );
  }
}

class _DuelPhaseBody extends StatelessWidget {
  const _DuelPhaseBody({
    required this.controller,
    required this.state,
    required this.playerOne,
    required this.playerTwo,
  });

  final ReflexoDuelController controller;
  final ReflexoGameState state;
  final ReflexoPlayerState playerOne;
  final ReflexoPlayerState playerTwo;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedUnitIds.isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
          child: ReflexoDuelHud(
            player: playerTwo,
            active:
                state.activePlayer == ReflexoPlayerId.two &&
                state.phase == ReflexoMatchPhase.playerTurn,
            attackHint: selected && state.activePlayer == ReflexoPlayerId.one,
            onTap: selected && state.activePlayer == ReflexoPlayerId.one
                ? controller.attackReflexo
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ReflexoTimelinePanel(
            round: state.round,
            phase: state.phase,
            activePlayer: state.activePlayer,
            logs: state.timeline,
            pressureEvent: state.pressureEvent,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _BattleBoard(controller: controller, state: state),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: _FloatingTurnBar(state: state, controller: controller),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 3, 10, 6),
          child: ReflexoDuelHud(
            player: playerOne,
            active:
                state.activePlayer == ReflexoPlayerId.one &&
                state.phase == ReflexoMatchPhase.playerTurn,
            attackHint: selected && state.activePlayer == ReflexoPlayerId.two,
            onTap: selected && state.activePlayer == ReflexoPlayerId.two
                ? controller.attackReflexo
                : null,
          ),
        ),
        _HandBar(controller: controller, state: state),
      ],
    );
  }
}

class _BattleBoard extends StatelessWidget {
  const _BattleBoard({required this.controller, required this.state});

  final ReflexoDuelController controller;
  final ReflexoGameState state;

  @override
  Widget build(BuildContext context) {
    final p1 = state.player(ReflexoPlayerId.one);
    final p2 = state.player(ReflexoPlayerId.two);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 64),
      child: Stack(
        children: [
          Column(
            children: [
              ReflexoTrapSlot(trapCount: p2.traps.length),
              const SizedBox(height: 3),
              _FieldRow(
                player: p2,
                reversed: true,
                state: state,
                controller: controller,
                onUnitTap: (unit) => _handleUnitTap(context, unit),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _CenterActionZone(state: state, controller: controller),
              ),
              const SizedBox(height: 6),
              _FieldRow(
                player: p1,
                state: state,
                controller: controller,
                onUnitTap: (unit) => _handleUnitTap(context, unit),
              ),
              const SizedBox(height: 3),
              ReflexoTrapSlot(trapCount: p1.traps.length),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(child: _AttackMotionOverlay(state: state)),
          ),
        ],
      ),
    );
  }

  void _handleUnitTap(BuildContext context, ReflexoUnitInstance unit) {
    if (state.phase != ReflexoMatchPhase.playerTurn) {
      showReflexoUnitDetails(context, unit);
      return;
    }
    if (unit.owner == state.activePlayer) {
      controller.toggleUnitSelection(unit.instanceId);
      return;
    }
    if (state.selectedUnitIds.isNotEmpty &&
        unit.owner == state.activePlayer.opponent) {
      controller.attackUnit(unit.instanceId);
      return;
    }
    showReflexoUnitDetails(context, unit);
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.player,
    required this.state,
    required this.controller,
    required this.onUnitTap,
    this.reversed = false,
  });

  final ReflexoPlayerState player;
  final ReflexoGameState state;
  final ReflexoDuelController controller;
  final ValueChanged<ReflexoUnitInstance> onUnitTap;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    final selectedIds = state.selectedUnitIds.toSet();
    for (var i = 0; i < 5; i++) {
      if (i < player.field.length) {
        final unit = player.field[i];
        final isEnemyTarget =
            state.selectedUnitIds.isNotEmpty &&
            unit.owner == state.activePlayer.opponent;
        slots.add(
          ReflexoUnitCard(
            unit: unit,
            selected: selectedIds.contains(unit.instanceId),
            isAttacking:
                state.lastAttackAnimation?.attackerId == unit.instanceId,
            isTargeted:
                state.lastAttackAnimation?.targetUnitId == unit.instanceId,
            canBeTargeted:
                isEnemyTarget && controller.canSelectedAttackTarget(unit),
            tooStrong:
                isEnemyTarget && !controller.canSelectedAttackTarget(unit),
            onTap: () => onUnitTap(unit),
          ),
        );
      } else {
        slots.add(const ReflexoEmptySlot());
      }
    }
    final rowChildren = reversed ? slots.reversed.toList() : slots;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: rowChildren,
    );
  }
}

class _CenterActionZone extends StatelessWidget {
  const _CenterActionZone({required this.state, required this.controller});

  final ReflexoGameState state;
  final ReflexoDuelController controller;

  @override
  Widget build(BuildContext context) {
    final selectedCount = state.selectedUnitIds.length;
    final selectedPower = controller.selectedAttackPower();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x550B1020),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            selectedCount > 0
                ? 'Ataque combinado: $selectedPower · $selectedCount unidade(s)'
                : 'Selecione tropas e toque no alvo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AttackMotionOverlay extends StatelessWidget {
  const _AttackMotionOverlay({required this.state});

  final ReflexoGameState state;

  @override
  Widget build(BuildContext context) {
    final anim = state.lastAttackAnimation;
    if (anim == null) return const SizedBox.shrink();

    ReflexoPlayerId? attackerOwner;
    int attackerIndex = 2;
    for (final player in state.players.values) {
      final idx = player.field.indexWhere(
        (u) => u.instanceId == anim.attackerId,
      );
      if (idx != -1) {
        attackerOwner = player.id;
        attackerIndex = idx;
        break;
      }
    }
    final attackFromTop = attackerOwner == ReflexoPlayerId.two;

    ReflexoPlayerId? targetOwner;
    int targetIndex = 2;
    if (anim.targetUnitId != null) {
      for (final player in state.players.values) {
        final idx = player.field.indexWhere(
          (u) => u.instanceId == anim.targetUnitId,
        );
        if (idx != -1) {
          targetOwner = player.id;
          targetIndex = idx;
          break;
        }
      }
    }

    Offset slot(int index, bool top) {
      final clamped = index.clamp(0, 4).toDouble();
      final x = 0.11 + (0.195 * clamped);
      final y = top ? 0.17 : 0.79;
      return Offset(x, y);
    }

    final start = slot(attackerIndex, attackFromTop);
    final inferredTargetOwner = targetOwner ?? attackerOwner?.opponent;
    final end = anim.targetUnitId != null
        ? slot(targetIndex, inferredTargetOwner == ReflexoPlayerId.two)
        : Offset(0.50, attackFromTop ? 0.96 : 0.03);

    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(anim.serial),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final current = Offset.lerp(start, end, value)!;
            final x = current.dx * constraints.maxWidth;
            final y = current.dy * constraints.maxHeight;
            final endX = end.dx * constraints.maxWidth;
            final endY = end.dy * constraints.maxHeight;
            return Stack(
              children: [
                if (value < 0.96)
                  Positioned(
                    left: x - 22,
                    top: y - 22,
                    child: Transform.rotate(
                      angle: (end.dx - start.dx) * 0.9,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFFFFFFFF),
                              Color(0xFFFBBF24),
                              Color(0xFFF97316),
                            ],
                            radius: 0.85,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFFFFC107), blurRadius: 22),
                            BoxShadow(color: Color(0xFFFF5722), blurRadius: 36),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF7C2D12),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: endX - 28,
                  top: endY - 28,
                  child: Opacity(
                    opacity: value < 0.6
                        ? 0
                        : (((value - 0.6) / 0.4).clamp(0.0, 1.0)).toDouble(),
                    child: Transform.scale(
                      scale: 0.7 + (value * 0.5),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFFFBBF24),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FloatingTurnBar extends StatelessWidget {
  const _FloatingTurnBar({required this.state, required this.controller});

  final ReflexoGameState state;
  final ReflexoDuelController controller;

  @override
  Widget build(BuildContext context) {
    final selectedCount = state.selectedUnitIds.length;
    final selectedPower = controller.selectedAttackPower();
    final canAct = state.phase == ReflexoMatchPhase.playerTurn;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xF00B1020),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCount > 0
                        ? 'Ataque: $selectedPower com $selectedCount unidade(s)'
                        : 'Selecione tropas e toque no alvo ou no avatar inimigo',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (selectedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: controller.clearSelection,
                        child: const Text(
                          'Limpar seleção',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: canAct ? controller.endTurn : null,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Fim do turno'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandBar extends StatelessWidget {
  const _HandBar({required this.controller, required this.state});

  final ReflexoDuelController controller;
  final ReflexoGameState state;

  @override
  Widget build(BuildContext context) {
    if (state.phase != ReflexoMatchPhase.playerTurn) {
      return const SizedBox(height: 108);
    }
    final player = state.current;
    return Container(
      height: 108,
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: player.hand.length,
        itemBuilder: (context, index) {
          final card = player.hand[index];
          final cost = controller.effectiveCost(player, card);
          final hasSpace = card.isUnit
              ? player.field.length < 5
              : card.isTrap
              ? player.traps.length < 2
              : true;
          return ReflexoCardTile(
            card: card,
            cost: cost,
            enabled: player.energy >= cost && hasSpace,
            compact: true,
            onTap: () => controller.playCard(index),
          );
        },
      ),
    );
  }
}

class _DiceRevealDialog extends StatefulWidget {
  const _DiceRevealDialog({required this.player});

  final ReflexoPlayerState player;

  @override
  State<_DiceRevealDialog> createState() => _DiceRevealDialogState();
}

class _DiceRevealDialogState extends State<_DiceRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destiny = widget.player.selectedDestiny;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 270,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1020),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destiny?.name ?? 'Resultado',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final t = Curves.easeOutBack.transform(_controller.value);
                  final angle = (1 - _controller.value) * 7.5;
                  return Transform.rotate(
                    angle: angle,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * -35),
                      child: Transform.scale(
                        scale: 0.7 + (t * 0.3),
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF60A5FA),
                                Color(0xFF1D4ED8),
                                Color(0xFF0F172A),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white54, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x883B82F6),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${widget.player.lastRoll ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Você rolou ${widget.player.lastRoll ?? '-'} no d20',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (destiny != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Buff escolhido: ${destiny.shortText}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.winner, required this.onRestart});

  final ReflexoPlayerId? winner;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1020),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFBBF24),
                  size: 54,
                ),
                const SizedBox(height: 12),
                Text(
                  '${winner?.label ?? 'Alguém'} venceu!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Nova partida'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    color: const Color(0xEE0B1020),
    border: Border.all(color: Colors.white12),
    boxShadow: const [
      BoxShadow(color: Color(0x77000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}
