// lib/features/reflexo_card_game/presentation/pages/reflexo_duel_page.dart

import 'package:flutter/material.dart';
import 'package:vida_app/features/reflexo_card_game/application/reflexo_duel_controller.dart';

import '../../domain/reflexo_models.dart';
import '../widgets/reflexo_card_widgets.dart';
import '../widgets/reflexo_destiny_panel.dart';
import '../widgets/reflexo_duel_hud.dart';

class ReflexoDuelPage extends StatefulWidget {
  const ReflexoDuelPage({
    super.key,
    this.vsBot = false,
    this.playerDeckPresetId = 'berserker',
    this.opponentDeckPresetId = 'estrategista',
  });

  final bool vsBot;
  final String playerDeckPresetId;
  final String opponentDeckPresetId;

  @override
  State<ReflexoDuelPage> createState() => _ReflexoDuelPageState();
}

class _ReflexoDuelPageState extends State<ReflexoDuelPage> {
  late final ReflexoDuelController controller;

  @override
  void initState() {
    super.initState();
    controller = ReflexoDuelController(
      vsBot: widget.vsBot,
      playerDeckPresetId: widget.playerDeckPresetId,
      opponentDeckPresetId: widget.opponentDeckPresetId,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
                      controller: controller,
                      state: state,
                      playerOne: p1,
                      playerTwo: p2,
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
                'Cada jogador escolhe 1 buff e rola seu próprio d20. Quando os dois rolarem, o combate começa.',
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
                onSelect: (option) =>
                    controller.selectDestiny(ReflexoPlayerId.one, option),
                onRoll: () => controller.rollDestiny(ReflexoPlayerId.one),
              ),
              const SizedBox(height: 12),
              ReflexoDestinyPanel(
                player: playerTwo,
                round: state.round,
                options: state.destinyOptions[ReflexoPlayerId.two] ?? const [],
                onSelect: (option) =>
                    controller.selectDestiny(ReflexoPlayerId.two, option),
                onRoll: () => controller.rollDestiny(ReflexoPlayerId.two),
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
                'Escolha um plano pequeno para cada jogador. Sem dado. Sem enrolação de pergaminho.',
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
              fontSize: 15,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
          child: _DirectReflexoTarget(
            enabled:
                state.phase == ReflexoMatchPhase.playerTurn &&
                state.activePlayer == ReflexoPlayerId.one &&
                state.selectedUnitIds.isNotEmpty,
            message: 'Toque aqui para atacar diretamente o Reflexo inimigo.',
            onTap: controller.attackReflexo,
            child: ReflexoDuelHud(
              player: playerTwo,
              active:
                  state.activePlayer == ReflexoPlayerId.two &&
                  state.phase == ReflexoMatchPhase.playerTurn,
            ),
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
        if (_shouldShowEventBanner(state.timeline))
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: _EventBanner(message: state.timeline.first),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: _BattleBoard(controller: controller, state: state),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 8),
          child: _DirectReflexoTarget(
            enabled:
                state.phase == ReflexoMatchPhase.playerTurn &&
                state.activePlayer == ReflexoPlayerId.two &&
                state.selectedUnitIds.isNotEmpty,
            message: 'Toque aqui para atacar diretamente o Reflexo inimigo.',
            onTap: controller.attackReflexo,
            child: ReflexoDuelHud(
              player: playerOne,
              active:
                  state.activePlayer == ReflexoPlayerId.one &&
                  state.phase == ReflexoMatchPhase.playerTurn,
            ),
          ),
        ),
        _HandBar(controller: controller, state: state),
      ],
    );
  }
}

class _DirectReflexoTarget extends StatelessWidget {
  const _DirectReflexoTarget({
    required this.enabled,
    required this.message,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final String message;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? message : 'Reflexo do jogador.',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            child,
            if (enabled)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFBBF24),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x55FBBF24), blurRadius: 18),
                      ],
                    ),
                  ),
                ),
              ),
            if (enabled)
              Positioned(
                right: 10,
                top: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'TOQUE PARA ATACAR',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _shouldShowEventBanner(List<String> logs) {
  if (logs.isEmpty) return false;
  final text = logs.first.toLowerCase();
  return text.contains('revelou') ||
      text.contains('usou') ||
      text.contains('despertou') ||
      text.contains('perfuração') ||
      text.contains('ataque combinado');
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF312E81).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFBBF24),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          ReflexoTrapSlot(trapCount: p2.traps.length),
          const SizedBox(height: 3),
          _FieldRow(
            player: p2,
            activePlayer: state.activePlayer,
            reversed: true,
            selectedUnitIds: state.selectedUnitIds,
            animation: state.lastAttackAnimation,
            canAttackTarget: controller.canSelectedAttackUnit,
            onUnitTap: (unit) => _handleUnitTap(context, unit),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _CenterActionZone(
              state: state,
              selectedAttackTotal: controller.selectedAttackTotal,
              selectedHasPrecision: controller.selectedAttackHasPrecision,
              onClearSelection: controller.clearSelection,
              onEndTurn: controller.endTurn,
            ),
          ),
          const SizedBox(height: 8),
          _FieldRow(
            player: p1,
            activePlayer: state.activePlayer,
            selectedUnitIds: state.selectedUnitIds,
            animation: state.lastAttackAnimation,
            canAttackTarget: controller.canSelectedAttackUnit,
            onUnitTap: (unit) => _handleUnitTap(context, unit),
          ),
          const SizedBox(height: 3),
          ReflexoTrapSlot(trapCount: p1.traps.length),
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
      controller.selectUnit(unit.instanceId);
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
    required this.activePlayer,
    required this.selectedUnitIds,
    required this.onUnitTap,
    required this.canAttackTarget,
    this.animation,
    this.reversed = false,
  });

  final ReflexoPlayerState player;
  final ReflexoPlayerId activePlayer;
  final List<String> selectedUnitIds;
  final ValueChanged<ReflexoUnitInstance> onUnitTap;
  final bool Function(ReflexoUnitInstance unit) canAttackTarget;
  final ReflexoAttackAnimation? animation;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[];
    for (var i = 0; i < 5; i++) {
      if (i < player.field.length) {
        final unit = player.field[i];
        final isOpponentTarget =
            selectedUnitIds.isNotEmpty && unit.owner == activePlayer.opponent;
        final canTarget = isOpponentTarget && canAttackTarget(unit);
        slots.add(
          ReflexoUnitCard(
            unit: unit,
            selected: selectedUnitIds.contains(unit.instanceId),
            isAttacking: animation?.attackerId == unit.instanceId,
            isTargeted: animation?.targetUnitId == unit.instanceId,
            targetable: canTarget,
            blockedTarget: isOpponentTarget && !canTarget,
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
  const _CenterActionZone({
    required this.state,
    required this.selectedAttackTotal,
    required this.selectedHasPrecision,
    required this.onClearSelection,
    required this.onEndTurn,
  });

  final ReflexoGameState state;
  final int selectedAttackTotal;
  final bool selectedHasPrecision;
  final VoidCallback onClearSelection;
  final VoidCallback onEndTurn;

  @override
  Widget build(BuildContext context) {
    final current = state.current;
    final selectedCount = state.selectedUnitIds.length;
    final selected = selectedCount > 0;
    final canAct = state.phase == ReflexoMatchPhase.playerTurn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x770B1020),
        border: Border.all(color: Colors.white12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      canAct ? 'Turno de ${current.name}' : 'Aguardando',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (selected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0EA5E9,
                          ).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFF38BDF8,
                            ).withValues(alpha: 0.42),
                          ),
                        ),
                        child: Text(
                          selectedCount > 1
                              ? 'Ataque combinado: $selectedAttackTotal · $selectedCount unidades'
                              : 'Ataque selecionado: $selectedAttackTotal',
                          style: const TextStyle(
                            color: Color(0xFFBAE6FD),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      selected
                          ? selectedHasPrecision
                                ? 'Alvos destacados podem ser atacados. Precisão ignora comparação de ataque.'
                                : 'Alvos verdes podem ser atacados. Toque no HUD inimigo para ataque direto.'
                          : 'Toque em uma ou mais unidades suas para selecionar atacantes.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 11,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: selected ? onClearSelection : null,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Limpar seleção'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onPressed: canAct ? onEndTurn : null,
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: const Text('Fim do turno'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
      return const SizedBox(height: 112);
    }
    final player = state.current;
    return Container(
      height: 112,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
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
            onTap: () => controller.playCard(index),
          );
        },
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
