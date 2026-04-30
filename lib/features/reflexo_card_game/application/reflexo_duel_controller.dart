// lib/features/reflexo_card_game/application/reflexo_duel_controller.dart

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/reflexo_content.dart';
import '../domain/reflexo_models.dart';

class ReflexoDuelController extends ChangeNotifier {
  ReflexoDuelController({this.vsBot = false}) {
    startNewGame();
  }

  final bool vsBot;
  bool _botBusy = false;

  final Random _rng = Random();
  int _unitSerial = 0;
  int _animationSerial = 0;

  late ReflexoGameState state;

  void startNewGame() {
    _unitSerial = 0;
    _animationSerial = 0;
    final p1Deck = ReflexoContent.buildDeck(seedOffset: 0);
    final p2Deck = ReflexoContent.buildDeck(seedOffset: 5);

    var p1 = _buildPlayer(
      id: ReflexoPlayerId.one,
      name: 'Jogador 1',
      deck: p1Deck,
      archetype: ReflexoArchetype.berserker,
    );
    var p2 = _buildPlayer(
      id: ReflexoPlayerId.two,
      name: vsBot ? 'Bot Estrategista' : 'Jogador 2',
      deck: p2Deck,
      archetype: ReflexoArchetype.estrategista,
    );

    p1 = _drawCards(p1, 4);
    p2 = _drawCards(p2, 4);

    final players = <ReflexoPlayerId, ReflexoPlayerState>{
      ReflexoPlayerId.one: p1,
      ReflexoPlayerId.two: p2,
    };

    state = ReflexoGameState(
      round: 1,
      phase: ReflexoMatchPhase.destiny,
      activePlayer: ReflexoPlayerId.one,
      players: players,
      destinyOptions: _buildDestinyOptions(players, 1),
      tacticOptions: const {},
      pressureEvent: null,
      timeline: const [
        'Rodada 1: Destino.',
        'Cada jogador escolhe um buff e rola o próprio d20.',
      ],
    );
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  ReflexoPlayerState _buildPlayer({
    required ReflexoPlayerId id,
    required String name,
    required List<ReflexoCardDefinition> deck,
    required ReflexoArchetype archetype,
  }) {
    return ReflexoPlayerState(
      id: id,
      name: name,
      life: 100,
      energy: 0,
      reserve: 0,
      deck: deck,
      hand: const [],
      field: const [],
      discard: const [],
      traps: const [],
      buffs: const [],
      attributes: ReflexoContent.attributesForPlayer(id),
      mainArchetype: archetype,
      secondaryArchetype: null,
    );
  }

  Map<ReflexoPlayerId, List<ReflexoDestinyOption>> _buildDestinyOptions(
    Map<ReflexoPlayerId, ReflexoPlayerState> players,
    int round,
  ) {
    return {
      for (final entry in players.entries)
        entry.key: ReflexoContent.destinyPoolFor(
          player: entry.value,
          round: round,
        ),
    };
  }

  Map<ReflexoPlayerId, List<ReflexoTacticOption>> _buildTacticOptions(
    Map<ReflexoPlayerId, ReflexoPlayerState> players,
    int round,
  ) {
    return {
      for (final entry in players.entries)
        entry.key: ReflexoContent.tacticOptionsFor(
          player: entry.value,
          round: round,
        ),
    };
  }

  ReflexoPlayerState _drawCards(ReflexoPlayerState player, int amount) {
    var deck = [...player.deck];
    final hand = [...player.hand];
    final discard = [...player.discard];
    for (var i = 0; i < amount; i++) {
      if (deck.isEmpty || hand.length >= 10) break;
      hand.add(deck.removeAt(0));
    }
    return player.copyWith(deck: deck, hand: hand, discard: discard);
  }

  void selectDestiny(ReflexoPlayerId playerId, ReflexoDestinyOption option) {
    if (state.phase != ReflexoMatchPhase.destiny) return;
    final player = state.player(playerId).copyWith(selectedDestiny: option);
    _setPlayer(player);
    _addLog('${player.name} escolheu um Destino secreto.');
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  void rollDestiny(ReflexoPlayerId playerId) {
    if (state.phase != ReflexoMatchPhase.destiny) return;
    final player = state.player(playerId);
    final destiny = player.selectedDestiny;
    if (destiny == null) {
      _addLog('${player.name} precisa escolher um Destino antes de rolar.');
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }
    if (player.lastRollRound == state.round) return;

    final natural = _rng.nextInt(20) + 1;
    final bonus = _rollBonus(player, destiny);
    final total = natural + bonus;
    final success = natural == 20 || total >= destiny.requirement;

    var updated = player.copyWith(
      lastRoll: natural,
      lastRollRound: state.round,
    );
    if (success) {
      updated = updated.copyWith(d20Successes: updated.d20Successes + 1);
      updated = _applyDestinySuccess(updated, destiny, natural, total, bonus);
    } else {
      updated = _applyDestinyFailure(updated, destiny, natural, total, bonus);
    }
    updated = _maybeAwaken(updated);

    _setPlayer(updated);
    if (_bothPlayersRolled()) {
      _startPlayerTurn(ReflexoPlayerId.one);
    }
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  int _rollBonus(ReflexoPlayerState player, ReflexoDestinyOption destiny) {
    final instinto = player.attributes[ReflexoAttribute.instinto] ?? 0;
    final disciplina = player.attributes[ReflexoAttribute.disciplina] ?? 0;
    var bonus = 0;
    if (instinto >= 70 && destiny.requirement >= 12) bonus += 1;
    if (disciplina >= 70 && destiny.requirement <= 8) bonus += 1;
    if (player.mainArchetype == ReflexoArchetype.oraculo) bonus += 1;
    if (player.mainArchetype == ReflexoArchetype.oraculo &&
        player.archetypeAwakened &&
        destiny.requirement >= 12) {
      bonus += 1;
    }
    return bonus.clamp(0, 3).toInt();
  }

  ReflexoPlayerState _applyDestinySuccess(
    ReflexoPlayerState player,
    ReflexoDestinyOption destiny,
    int natural,
    int total,
    int bonus,
  ) {
    _addLog(
      '${player.name} rolou d20: $natural${bonus > 0 ? ' +$bonus' : ''} = $total. ${destiny.name} ativado.',
    );

    switch (destiny.effect) {
      case ReflexoDestinyEffect.energy:
        return player.copyWith(
          energy: (player.energy + destiny.amount).clamp(0, 12).toInt(),
        );
      case ReflexoDestinyEffect.attackAll:
      case ReflexoDestinyEffect.shieldAll:
      case ReflexoDestinyEffect.costReduction:
      case ReflexoDestinyEffect.directStrike:
        return player.copyWith(
          buffs: [...player.buffs, _buffFromDestiny(destiny)],
        );
      case ReflexoDestinyEffect.draw:
        return _drawCards(player, destiny.amount);
      case ReflexoDestinyEffect.heal:
        final healed = min(100 - player.life, destiny.amount);
        return player.copyWith(
          life: min(100, player.life + destiny.amount),
          healingDone: player.healingDone + healed,
        );
    }
  }

  ReflexoPlayerState _applyDestinyFailure(
    ReflexoPlayerState player,
    ReflexoDestinyOption destiny,
    int natural,
    int total,
    int bonus,
  ) {
    _addLog(
      '${player.name} rolou d20: $natural${bonus > 0 ? ' +$bonus' : ''} = $total. ${destiny.name} falhou.',
    );
    if (destiny.effect == ReflexoDestinyEffect.energy &&
        destiny.requirement <= 8) {
      _addLog('${player.name} recebeu efeito fraco: +1 energia.');
      return player.copyWith(energy: min(10, player.energy + 1));
    }
    return player;
  }

  ReflexoActiveBuff _buffFromDestiny(ReflexoDestinyOption destiny) {
    final turns = destiny.lastsWholeMatch ? null : destiny.durationTurns;
    switch (destiny.effect) {
      case ReflexoDestinyEffect.energy:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          energyBonus: destiny.amount,
          turnsRemaining: turns,
        );
      case ReflexoDestinyEffect.attackAll:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          attackBonus: destiny.amount,
          turnsRemaining: turns,
        );
      case ReflexoDestinyEffect.shieldAll:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          shieldBonus: destiny.amount,
          turnsRemaining: turns,
        );
      case ReflexoDestinyEffect.draw:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          drawBonus: destiny.amount,
          turnsRemaining: turns,
        );
      case ReflexoDestinyEffect.directStrike:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          directStrikeCharges: destiny.amount,
          turnsRemaining: turns,
        );
      case ReflexoDestinyEffect.heal:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          turnsRemaining: turns,
        );
      case ReflexoDestinyEffect.costReduction:
        return ReflexoActiveBuff(
          id: destiny.id,
          name: destiny.name,
          summary: destiny.shortText,
          costReduction: destiny.amount,
          turnsRemaining: turns,
        );
    }
  }

  bool _bothPlayersRolled() {
    return state.player(ReflexoPlayerId.one).lastRollRound == state.round &&
        state.player(ReflexoPlayerId.two).lastRollRound == state.round;
  }

  void selectTactic(ReflexoPlayerId playerId, ReflexoTacticOption option) {
    if (state.phase != ReflexoMatchPhase.tactic) return;
    var player = state.player(playerId).copyWith(selectedTactic: option);
    player = _applyTactic(player, option);
    player = _maybeAwaken(player);
    _setPlayer(player);
    _addLog('${player.name} escolheu Tática: ${option.name}.');
    if (_bothPlayersTacticReady()) {
      _startPlayerTurn(ReflexoPlayerId.one);
    }
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  bool _bothPlayersTacticReady() {
    return state.player(ReflexoPlayerId.one).selectedTactic != null &&
        state.player(ReflexoPlayerId.two).selectedTactic != null;
  }

  ReflexoPlayerState _applyTactic(
    ReflexoPlayerState player,
    ReflexoTacticOption option,
  ) {
    switch (option.effect) {
      case ReflexoTacticEffect.reserve:
        return player.copyWith(
          reserve: min(10, player.reserve + option.amount),
        );
      case ReflexoTacticEffect.draw:
        return _drawCards(player, option.amount);
      case ReflexoTacticEffect.firstUnitAttack:
        return player.copyWith(
          buffs: [
            ...player.buffs,
            ReflexoActiveBuff(
              id: option.id,
              name: option.name,
              summary: option.shortText,
              firstUnitAttackBonus: option.amount,
              turnsRemaining: 1,
            ),
          ],
        );
      case ReflexoTacticEffect.firstUnitShield:
        return player.copyWith(
          buffs: [
            ...player.buffs,
            ReflexoActiveBuff(
              id: option.id,
              name: option.name,
              summary: option.shortText,
              firstUnitShieldBonus: option.amount,
              turnsRemaining: 1,
            ),
          ],
        );
      case ReflexoTacticEffect.heal:
        final healed = min(100 - player.life, option.amount);
        return player.copyWith(
          life: min(100, player.life + option.amount),
          healingDone: player.healingDone + healed,
        );
      case ReflexoTacticEffect.costReduction:
        return player.copyWith(
          buffs: [
            ...player.buffs,
            ReflexoActiveBuff(
              id: option.id,
              name: option.name,
              summary: option.shortText,
              costReduction: option.amount,
              turnsRemaining: 1,
            ),
          ],
        );
    }
  }

  void startPressureCombat() {
    if (state.phase != ReflexoMatchPhase.pressure) return;
    _startPlayerTurn(ReflexoPlayerId.one);
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  void _startPlayerTurn(ReflexoPlayerId id) {
    final baseEnergy = state.round <= 3 ? 3 : 5;
    var player = state.player(id);
    final pressureDiscount = _pressureDiscountFor(player);
    final totalEnergy = (baseEnergy + player.reserve + player.energyBonus)
        .clamp(0, 10)
        .toInt();
    player = player.copyWith(
      energy: totalEnergy,
      reserve: 0,
      cardsPlayedThisTurn: 0,
      field: player.field
          .map((unit) => unit.copyWith(canAttack: true, exhausted: false))
          .toList(),
      buffs: pressureDiscount > 0
          ? [
              ...player.buffs,
              ReflexoActiveBuff(
                id: 'pressure_discount_${state.round}_${player.id.name}',
                name: 'Ritmo Forçado',
                summary: '-$pressureDiscount custo na 1ª carta',
                costReduction: pressureDiscount,
                turnsRemaining: 1,
              ),
            ]
          : player.buffs,
    );
    player = _drawCards(
      player,
      1 + player.buffs.fold<int>(0, (a, b) => a + b.drawBonus),
    );
    _setPlayer(player);
    state = state.copyWith(
      phase: ReflexoMatchPhase.playerTurn,
      activePlayer: id,
      selectedUnitId: null,
    );
    _addLog('Turno de ${player.name}. Energia: ${player.energy}.');
  }

  int _pressureDiscountFor(ReflexoPlayerState player) {
    final pressure = state.pressureEvent;
    if (pressure?.effect == ReflexoPressureEffect.firstCardDiscount &&
        player.cardsPlayedThisTurn == 0) {
      return pressure!.amount;
    }
    return 0;
  }

  void playCard(int handIndex) {
    if (state.phase != ReflexoMatchPhase.playerTurn) return;
    var player = state.current;
    if (handIndex < 0 || handIndex >= player.hand.length) return;
    final card = player.hand[handIndex];
    final cost = effectiveCost(player, card);
    if (player.energy < cost) {
      _addLog('Energia insuficiente para ${card.name}. Precisa de $cost.');
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }
    if (card.isUnit && player.field.length >= 5) {
      _addLog('Campo cheio. Limite: 5 unidades.');
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }
    if (card.isTrap && player.traps.length >= 2) {
      _addLog('Limite de 2 armadilhas preparadas.');
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }

    final hand = [...player.hand]..removeAt(handIndex);
    player = player.copyWith(
      energy: player.energy - cost,
      hand: hand,
      cardsPlayedThisTurn: player.cardsPlayedThisTurn + 1,
      cardsPlayedTotal: player.cardsPlayedTotal + 1,
      energySpent: player.energySpent + cost,
    );

    if (card.isUnit) {
      final unit = _createUnit(player.id, card, player);
      player = player.copyWith(field: [...player.field, unit]);
      player = _consumeFirstUnitBuffs(player);
      _addLog('${player.name} colocou ${card.name} em campo.');
    } else if (card.isSpell) {
      player = _resolveSpell(player, card);
      player = player.copyWith(discard: [...player.discard, card]);
    } else if (card.isTrap) {
      player = player.copyWith(traps: [...player.traps, card]);
      _addLog('${player.name} preparou uma armadilha virada.');
    } else {
      player = player.copyWith(discard: [...player.discard, card]);
    }

    player = _applyCardCountPassives(player);
    player = _maybeAwaken(player);
    _setPlayer(player);
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  int effectiveCost(ReflexoPlayerState player, ReflexoCardDefinition card) {
    final attribute = player.attributes[card.attribute] ?? 0;
    var reduction = player.costReduction;
    if (attribute >= 90) reduction += 1;
    if (player.mainArchetype == ReflexoArchetype.inventor) {
      final amount = player.archetypeAwakened ? 2 : 1;
      if (player.cardsPlayedThisTurn == 0) reduction += amount;
    }
    if (player.mainArchetype == ReflexoArchetype.alquimista &&
        player.archetypeAwakened &&
        player.reserve >= 3) {
      reduction += 1;
    }
    return max(1, card.cost - reduction);
  }

  ReflexoUnitInstance _createUnit(
    ReflexoPlayerId owner,
    ReflexoCardDefinition card,
    ReflexoPlayerState player,
  ) {
    final attr = player.attributes[card.attribute] ?? 0;
    var healthBonus = 0;
    var attackBonus = 0;
    var shieldBonus = player.shieldBonus;

    if (card.attribute == ReflexoAttribute.vigor && attr >= 50)
      healthBonus += 2;
    if (card.attribute == ReflexoAttribute.vigor && attr >= 70)
      healthBonus += 2;
    if (card.attribute == ReflexoAttribute.instinto && attr >= 70)
      attackBonus += 1;
    if (card.attribute == ReflexoAttribute.foco && attr >= 90) attackBonus += 1;

    if (player.mainArchetype == ReflexoArchetype.berserker) {
      attackBonus += player.archetypeAwakened ? 2 : 1;
    }
    if (player.mainArchetype == ReflexoArchetype.guardiao) {
      shieldBonus += player.archetypeAwakened ? 3 : 1;
    }
    if (player.firstUnitAttackBonus > 0)
      attackBonus += player.firstUnitAttackBonus;
    if (player.firstUnitShieldBonus > 0)
      shieldBonus += player.firstUnitShieldBonus;

    final pressure = state.pressureEvent;
    if (pressure?.effect == ReflexoPressureEffect.lowLifeFury &&
        card.health > 0 &&
        card.health <= 14) {
      attackBonus += pressure!.amount;
    }

    return ReflexoUnitInstance(
      instanceId: 'u_${owner.index}_${_unitSerial++}',
      owner: owner,
      card: card,
      attack: card.attack + attackBonus,
      health: card.health + healthBonus,
      maxHealth: card.health + healthBonus,
      shield: card.shield + shieldBonus,
      hasBarrier: card.abilities.contains(ReflexoAbility.barreira),
      canAttack: card.abilities.contains(ReflexoAbility.investida),
      exhausted: false,
      turnPlayed: state.round,
    );
  }

  ReflexoPlayerState _consumeFirstUnitBuffs(ReflexoPlayerState player) {
    var buffs = [...player.buffs];
    buffs = buffs
        .where(
          (b) => b.firstUnitAttackBonus == 0 && b.firstUnitShieldBonus == 0,
        )
        .toList();
    return player.copyWith(
      buffs: buffs,
      shieldGenerated: player.shieldGenerated + player.firstUnitShieldBonus,
    );
  }

  ReflexoPlayerState _resolveSpell(
    ReflexoPlayerState player,
    ReflexoCardDefinition card,
  ) {
    switch (card.id) {
      case 'raio_prismatico':
        final target = _lowestHealthUnit(state.opponent);
        if (target == null) {
          _addLog('${card.name} não encontrou alvo.');
          return player;
        }
        var opponent = state.opponent;
        final damaged = _damageUnit(target, 6);
        opponent = _replaceOrRemoveUnit(opponent, damaged);
        _setPlayer(opponent);
        _addLog(
          '${player.name} usou ${card.name}: 6 dano em ${target.card.name}.',
        );
        return player;
      case 'forca_subita':
        if (player.field.isEmpty) {
          _addLog('${card.name} não encontrou unidade aliada.');
          return player;
        }
        final unit = player.field.first;
        final updated = unit.copyWith(attack: unit.attack + 3);
        _addLog(
          '${player.name} usou ${card.name}: +3 ataque em ${unit.card.name}.',
        );
        return _replaceOrRemoveUnit(player, updated);
      case 'reparo_rapido':
        final target = _lowestHealthUnit(player);
        if (target == null) {
          _addLog('${card.name} não encontrou unidade aliada.');
          return player;
        }
        final heal = min(8, target.maxHealth - target.health);
        final updated = target.copyWith(
          health: min(target.maxHealth, target.health + 8),
        );
        _addLog(
          '${player.name} usou ${card.name}: curou $heal em ${target.card.name}.',
        );
        return _replaceOrRemoveUnit(
          player.copyWith(healingDone: player.healingDone + heal),
          updated,
        );
      default:
        _addLog('${player.name} usou ${card.name}.');
        return player;
    }
  }

  ReflexoUnitInstance? _lowestHealthUnit(ReflexoPlayerState player) {
    if (player.field.isEmpty) return null;
    final sorted = [...player.field]
      ..sort((a, b) => a.health.compareTo(b.health));
    return sorted.first;
  }

  ReflexoPlayerState _applyCardCountPassives(ReflexoPlayerState player) {
    if (player.mainArchetype == ReflexoArchetype.estrategista) {
      final threshold = player.archetypeAwakened ? 2 : 3;
      if (player.cardsPlayedThisTurn > 0 &&
          player.cardsPlayedThisTurn % threshold == 0) {
        _addLog('${player.name} ativou Estrategista: comprou 1 carta.');
        return _drawCards(player, 1);
      }
    }
    if (player.mainArchetype == ReflexoArchetype.comandante &&
        player.cardsPlayedThisTurn == 2 &&
        player.field.isNotEmpty) {
      final buffed = player.field
          .map(
            (u) => u.copyWith(
              attack: u.attack + 1,
              health: u.health + 1,
              maxHealth: u.maxHealth + 1,
            ),
          )
          .toList();
      _addLog('${player.name} ativou Comandante: aliados receberam +1/+1.');
      return player.copyWith(field: buffed);
    }
    return player;
  }

  void selectUnit(String unitId) {
    if (state.phase != ReflexoMatchPhase.playerTurn) return;
    final ownsUnit = state.current.field.any(
      (unit) => unit.instanceId == unitId,
    );
    if (!ownsUnit) return;
    state = state.copyWith(selectedUnitId: unitId);
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  void attackUnit(String defenderId) {
    final attacker = _selectedAttacker();
    if (attacker == null) return;
    final defender = state.opponent.field
        .where((u) => u.instanceId == defenderId)
        .firstOrNull;
    if (defender == null) return;
    if (!_canAttackWith(attacker)) return;

    var active = state.current;
    var opponent = state.opponent;

    final trapResult = _triggerAttackTraps(
      active,
      opponent,
      attacker,
      attacksReflexo: false,
    );
    active = trapResult.active;
    opponent = trapResult.opponent;
    final maybeAttacker = active.field
        .where((u) => u.instanceId == attacker.instanceId)
        .firstOrNull;
    if (maybeAttacker == null) {
      _setPlayers(active, opponent);
      _addLog(
        '${attacker.card.name} foi destruído por armadilha antes do ataque.',
      );
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }

    final attackerDamage = _attackDamageWithPressure(maybeAttacker, active);
    final precision =
        maybeAttacker.hasAbility(ReflexoAbility.precisao) ||
        (active.mainArchetype == ReflexoArchetype.sombra &&
            active.archetypeAwakened);
    final defenderDamage = precision ? 0 : defender.visibleAttack;

    final updatedDefender = _damageUnit(defender, attackerDamage);
    final updatedAttacker = precision
        ? maybeAttacker
        : _damageUnit(maybeAttacker, defenderDamage);

    final overflow = max(
      0,
      attackerDamage - (defender.health + defender.shield),
    );
    active = _replaceOrRemoveUnit(
      active,
      updatedAttacker.copyWith(exhausted: true, canAttack: false),
    );
    opponent = _replaceOrRemoveUnit(opponent, updatedDefender);

    var dealtToPlayer = 0;
    if (active.mainArchetype == ReflexoArchetype.berserker &&
        active.archetypeAwakened &&
        overflow > 0 &&
        !updatedDefender.alive) {
      dealtToPlayer = overflow;
      opponent = opponent.copyWith(life: max(0, opponent.life - overflow));
      _addLog('Perfuração Berserker: $overflow dano excedente no Reflexo.');
    }

    active = _afterDamageDealt(
      active,
      attackerDamage + dealtToPlayer,
      maybeAttacker,
    );
    _setPlayers(_maybeAwaken(active), opponent);
    state = state.copyWith(
      selectedUnitId: null,
      lastAttackAnimation: ReflexoAttackAnimation(
        attackerId: maybeAttacker.instanceId,
        targetUnitId: defenderId,
        serial: _animationSerial++,
      ),
    );
    _addLog(
      '${active.name}: ${maybeAttacker.card.name} atacou ${defender.card.name}.',
    );
    _checkGameOver();
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  void attackReflexo() {
    final attacker = _selectedAttacker();
    if (attacker == null) return;
    if (!_canAttackWith(attacker)) return;
    if (!_canAttackReflexo(attacker)) {
      _addLog(
        'Ataque direto bloqueado. Limpe o campo inimigo ou use Direto/Brecha.',
      );
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }

    var active = state.current;
    var opponent = state.opponent;

    final trapResult = _triggerAttackTraps(
      active,
      opponent,
      attacker,
      attacksReflexo: true,
    );
    active = trapResult.active;
    opponent = trapResult.opponent;
    final maybeAttacker = active.field
        .where((u) => u.instanceId == attacker.instanceId)
        .firstOrNull;
    if (maybeAttacker == null) {
      _setPlayers(active, opponent);
      _addLog(
        '${attacker.card.name} foi destruído por armadilha antes do ataque.',
      );
      notifyListeners();
      _scheduleBotIfNeeded();
      return;
    }

    var damage = _attackDamageWithPressure(maybeAttacker, active);
    final shieldTrap = opponent.traps
        .where((c) => c.id == 'barreira_oculta')
        .firstOrNull;
    if (shieldTrap != null) {
      final traps = [...opponent.traps]..remove(shieldTrap);
      damage = max(0, damage - 6);
      opponent = opponent.copyWith(
        traps: traps,
        discard: [...opponent.discard, shieldTrap],
      );
      _addLog('${opponent.name} revelou Barreira Oculta: -6 dano.');
    }

    opponent = opponent.copyWith(life: max(0, opponent.life - damage));
    active = _replaceOrRemoveUnit(
      active,
      maybeAttacker.copyWith(exhausted: true, canAttack: false),
    );
    active = _consumeDirectChargeIfNeeded(active, maybeAttacker);
    active = _afterDamageDealt(active, damage, maybeAttacker, direct: true);

    _setPlayers(_maybeAwaken(active), opponent);
    state = state.copyWith(
      selectedUnitId: null,
      lastAttackAnimation: ReflexoAttackAnimation(
        attackerId: maybeAttacker.instanceId,
        targetPlayerId: opponent.id,
        serial: _animationSerial++,
      ),
    );
    _addLog(
      '${active.name}: ${maybeAttacker.card.name} causou $damage no Reflexo inimigo.',
    );
    _checkGameOver();
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  int _attackDamageWithPressure(
    ReflexoUnitInstance attacker,
    ReflexoPlayerState player,
  ) {
    var damage = attacker.visibleAttack + player.attackBonus;
    final pressure = state.pressureEvent;
    if (pressure?.effect == ReflexoPressureEffect.firstAttackBonus &&
        player.field.where((u) => u.exhausted).isEmpty) {
      damage += pressure!.amount;
    }
    if (player.mainArchetype == ReflexoArchetype.sombra &&
        attacker.hasAbility(ReflexoAbility.direto)) {
      damage += player.archetypeAwakened ? 2 : 1;
    }
    return damage;
  }

  ({ReflexoPlayerState active, ReflexoPlayerState opponent})
  _triggerAttackTraps(
    ReflexoPlayerState active,
    ReflexoPlayerState opponent,
    ReflexoUnitInstance attacker, {
    required bool attacksReflexo,
  }) {
    final trap = opponent.traps
        .where((c) => c.id == 'armadilha_espelhada')
        .firstOrNull;
    if (trap == null) return (active: active, opponent: opponent);
    final traps = [...opponent.traps]..remove(trap);
    opponent = opponent.copyWith(
      traps: traps,
      discard: [...opponent.discard, trap],
    );
    final damaged = _damageUnit(attacker, 5);
    active = _replaceOrRemoveUnit(active, damaged);
    _addLog(
      '${opponent.name} revelou Armadilha Espelhada: 5 dano no atacante.',
    );
    return (active: active, opponent: opponent);
  }

  ReflexoPlayerState _afterDamageDealt(
    ReflexoPlayerState player,
    int damage,
    ReflexoUnitInstance attacker, {
    bool direct = false,
  }) {
    var updated = player.copyWith(
      damageDealt: player.damageDealt + max(0, damage),
    );
    if (direct) {
      updated = updated.copyWith(
        directDamageEvents: updated.directDamageEvents + 1,
      );
    }
    if (attacker.hasAbility(ReflexoAbility.vinculo)) {
      final bonus = updated.mainArchetype == ReflexoArchetype.curador ? 2 : 0;
      final heal = max(1, damage ~/ 2) + bonus;
      updated = updated.copyWith(
        life: min(100, updated.life + heal),
        healingDone: updated.healingDone + heal,
      );
    }
    return updated;
  }

  ReflexoPlayerState _consumeDirectChargeIfNeeded(
    ReflexoPlayerState player,
    ReflexoUnitInstance attacker,
  ) {
    if (attacker.hasAbility(ReflexoAbility.direto)) return player;
    if (!player.hasDirectCharge) return player;
    final buffs = [...player.buffs];
    for (var i = 0; i < buffs.length; i++) {
      if (buffs[i].directStrikeCharges > 0) {
        final consumed = buffs[i].consumeDirectCharge();
        if (consumed.directStrikeCharges <= 0 &&
            consumed.turnsRemaining != null) {
          buffs.removeAt(i);
        } else {
          buffs[i] = consumed;
        }
        break;
      }
    }
    return player.copyWith(buffs: buffs);
  }

  ReflexoUnitInstance? _selectedAttacker() {
    final id = state.selectedUnitId;
    if (id == null) return null;
    return state.current.field.where((u) => u.instanceId == id).firstOrNull;
  }

  bool _canAttackWith(ReflexoUnitInstance attacker) {
    if (!attacker.readyToAttack) {
      _addLog('${attacker.card.name} não pode atacar agora.');
      notifyListeners();
      _scheduleBotIfNeeded();
      return false;
    }
    return true;
  }

  bool _canAttackReflexo(ReflexoUnitInstance attacker) {
    final opponent = state.opponent;
    if (opponent.turnsTaken <= 0 && state.round == 1) return false;
    if (attacker.hasAbility(ReflexoAbility.direto)) return true;
    if (state.current.hasDirectCharge) return true;
    return opponent.field.isEmpty;
  }

  ReflexoUnitInstance _damageUnit(ReflexoUnitInstance unit, int rawDamage) {
    if (rawDamage <= 0) return unit;
    if (unit.hasBarrier) {
      return unit.copyWith(hasBarrier: false);
    }
    var shield = unit.shield;
    var health = unit.health;
    final absorbed = min(shield, rawDamage);
    shield -= absorbed;
    health -= rawDamage - absorbed;
    var updated = unit.copyWith(shield: max(0, shield), health: health);
    if (updated.alive && unit.hasAbility(ReflexoAbility.furia)) {
      updated = updated.copyWith(attack: updated.attack + 2);
    }
    return updated;
  }

  ReflexoPlayerState _replaceOrRemoveUnit(
    ReflexoPlayerState player,
    ReflexoUnitInstance updated,
  ) {
    final field = <ReflexoUnitInstance>[];
    for (final unit in player.field) {
      if (unit.instanceId == updated.instanceId) {
        if (updated.alive) field.add(updated);
      } else {
        field.add(unit);
      }
    }
    return player.copyWith(field: field);
  }

  void endTurn() {
    if (state.phase != ReflexoMatchPhase.playerTurn) return;
    var player = state.current;
    if (player.mainArchetype == ReflexoArchetype.curador &&
        player.archetypeAwakened) {
      player = player.copyWith(
        life: min(100, player.life + 2),
        healingDone: player.healingDone + 2,
      );
    }
    final saved = (player.reserve + max(0, player.energy)).clamp(0, 10).toInt();
    player = player.copyWith(
      energy: 0,
      reserve: saved,
      turnsTaken: player.turnsTaken + 1,
      buffs: _tickBuffs(player.buffs),
    );

    final pressure = state.pressureEvent;
    if (pressure?.effect == ReflexoPressureEffect.emptyFieldDraw &&
        player.field.isEmpty) {
      player = _drawCards(player, pressure!.amount);
      _addLog('${player.name} comprou 1 carta por Campo Instável.');
    }

    _setPlayer(_maybeAwaken(player));
    _addLog('${player.name} finalizou o turno. Reserva: $saved.');

    if (state.activePlayer == ReflexoPlayerId.one) {
      _startPlayerTurn(ReflexoPlayerId.two);
    } else {
      _startNextRound();
    }
    notifyListeners();
    _scheduleBotIfNeeded();
  }

  List<ReflexoActiveBuff> _tickBuffs(List<ReflexoActiveBuff> buffs) {
    return buffs
        .map((buff) => buff.tick())
        .where(
          (buff) => buff.turnsRemaining == null || buff.turnsRemaining! > 0,
        )
        .toList();
  }

  void _startNextRound() {
    var players = {...state.players};
    for (final id in ReflexoPlayerId.values) {
      players[id] = players[id]!.copyWith(
        selectedDestiny: null,
        selectedTactic: null,
      );
    }
    final nextRound = state.round + 1;
    final kindIndex = (nextRound - 1) % 3;
    if (kindIndex == 0) {
      state = state.copyWith(
        round: nextRound,
        phase: ReflexoMatchPhase.destiny,
        activePlayer: ReflexoPlayerId.one,
        players: players,
        selectedUnitId: null,
        destinyOptions: _buildDestinyOptions(players, nextRound),
        tacticOptions: const {},
        pressureEvent: null,
      );
      _addLog('Rodada $nextRound: Destino.');
    } else if (kindIndex == 1) {
      state = state.copyWith(
        round: nextRound,
        phase: ReflexoMatchPhase.tactic,
        activePlayer: ReflexoPlayerId.one,
        players: players,
        selectedUnitId: null,
        destinyOptions: const {},
        tacticOptions: _buildTacticOptions(players, nextRound),
        pressureEvent: null,
      );
      _addLog('Rodada $nextRound: Tática.');
    } else {
      final pressure = ReflexoContent.pressureForRound(nextRound);
      state = state.copyWith(
        round: nextRound,
        phase: ReflexoMatchPhase.pressure,
        activePlayer: ReflexoPlayerId.one,
        players: players,
        selectedUnitId: null,
        destinyOptions: const {},
        tacticOptions: const {},
        pressureEvent: pressure,
      );
      _addLog('Rodada $nextRound: Pressão — ${pressure.name}.');
    }
  }

  ReflexoPlayerState _maybeAwaken(ReflexoPlayerState player) {
    if (player.archetypeAwakened) return player;
    if (player.archetypeProgress < player.archetypeGoal) return player;
    _addLog('${player.name} despertou ${player.mainArchetype.label}!');
    return player.copyWith(archetypeAwakened: true);
  }

  void _checkGameOver() {
    final p1 = state.player(ReflexoPlayerId.one);
    final p2 = state.player(ReflexoPlayerId.two);
    ReflexoPlayerId? winner;
    if (p1.life <= 0) winner = ReflexoPlayerId.two;
    if (p2.life <= 0) winner = ReflexoPlayerId.one;
    if (p1.deck.isEmpty && p1.field.isEmpty) winner = ReflexoPlayerId.two;
    if (p2.deck.isEmpty && p2.field.isEmpty) winner = ReflexoPlayerId.one;
    if (winner != null) {
      state = state.copyWith(
        phase: ReflexoMatchPhase.gameOver,
        winner: winner,
        selectedUnitId: null,
      );
      _addLog('${winner.label} venceu o Duelo de Reflexos.');
    }
  }

  void _setPlayer(ReflexoPlayerState player) {
    final players = {...state.players, player.id: player};
    state = state.copyWith(players: players);
  }

  void _setPlayers(ReflexoPlayerState a, ReflexoPlayerState b) {
    final players = {...state.players, a.id: a, b.id: b};
    state = state.copyWith(players: players);
  }

  void _addLog(String message) {
    final timeline = [message, ...state.timeline];
    state = state.copyWith(timeline: timeline.take(12).toList());
  }

  void _scheduleBotIfNeeded() {
    if (!vsBot || _botBusy) return;

    final bot = state.player(ReflexoPlayerId.two);

    final shouldAct =
        (state.phase == ReflexoMatchPhase.destiny &&
            (bot.selectedDestiny == null ||
                bot.lastRollRound != state.round)) ||
        (state.phase == ReflexoMatchPhase.tactic &&
            bot.selectedTactic == null) ||
        (state.phase == ReflexoMatchPhase.playerTurn &&
            state.activePlayer == ReflexoPlayerId.two);

    if (!shouldAct) return;

    _botBusy = true;
    Future<void>.delayed(const Duration(milliseconds: 450), () async {
      try {
        if (state.phase == ReflexoMatchPhase.destiny) {
          await _runBotDestiny();
        } else if (state.phase == ReflexoMatchPhase.tactic) {
          await _runBotTactic();
        } else if (state.phase == ReflexoMatchPhase.playerTurn &&
            state.activePlayer == ReflexoPlayerId.two) {
          await _runBotTurn();
        }
      } finally {
        _botBusy = false;
        notifyListeners();
        _scheduleBotIfNeeded();
      }
    });
  }

  Future<void> _runBotDestiny() async {
    var bot = state.player(ReflexoPlayerId.two);
    if (bot.selectedDestiny == null) {
      final options = state.destinyOptions[ReflexoPlayerId.two] ?? const [];
      if (options.isNotEmpty) {
        final choice = _bestBotDestiny(options, bot);
        selectDestiny(ReflexoPlayerId.two, choice);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    bot = state.player(ReflexoPlayerId.two);
    if (state.phase == ReflexoMatchPhase.destiny &&
        bot.lastRollRound != state.round) {
      rollDestiny(ReflexoPlayerId.two);
    }
  }

  ReflexoDestinyOption _bestBotDestiny(
    List<ReflexoDestinyOption> options,
    ReflexoPlayerState bot,
  ) {
    if (bot.life <= 45) {
      final heal = options.where((o) => o.effect == ReflexoDestinyEffect.heal);
      if (heal.isNotEmpty) return heal.first;
    }

    final playable = options.where((o) => o.requirement <= 12).toList();
    if (playable.isNotEmpty) return playable.first;

    return options.first;
  }

  Future<void> _runBotTactic() async {
    final bot = state.player(ReflexoPlayerId.two);
    if (bot.selectedTactic != null) return;

    final options = state.tacticOptions[ReflexoPlayerId.two] ?? const [];
    if (options.isEmpty) return;

    ReflexoTacticOption choice = options.first;
    if (bot.hand.length <= 2) {
      final draw = options.where((o) => o.effect == ReflexoTacticEffect.draw);
      if (draw.isNotEmpty) choice = draw.first;
    } else if (bot.life <= 40) {
      final heal = options.where((o) => o.effect == ReflexoTacticEffect.heal);
      if (heal.isNotEmpty) choice = heal.first;
    } else {
      final economy = options.where(
        (o) =>
            o.effect == ReflexoTacticEffect.costReduction ||
            o.effect == ReflexoTacticEffect.reserve,
      );
      if (economy.isNotEmpty) choice = economy.first;
    }

    selectTactic(ReflexoPlayerId.two, choice);
  }

  Future<void> _runBotTurn() async {
    if (state.phase != ReflexoMatchPhase.playerTurn ||
        state.activePlayer != ReflexoPlayerId.two) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    _botPlayBestCard();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    _botAttackIfPossible();

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (state.phase == ReflexoMatchPhase.playerTurn &&
        state.activePlayer == ReflexoPlayerId.two) {
      endTurn();
    }
  }

  void _botPlayBestCard() {
    if (state.phase != ReflexoMatchPhase.playerTurn ||
        state.activePlayer != ReflexoPlayerId.two) {
      return;
    }

    final bot = state.current;
    var bestIndex = -1;
    var bestCost = -1;

    for (var i = 0; i < bot.hand.length; i++) {
      final card = bot.hand[i];
      final cost = effectiveCost(bot, card);
      final hasSpace = card.isUnit
          ? bot.field.length < 5
          : card.isTrap
          ? bot.traps.length < 2
          : true;

      if (hasSpace && bot.energy >= cost && cost > bestCost) {
        bestIndex = i;
        bestCost = cost;
      }
    }

    if (bestIndex >= 0) {
      playCard(bestIndex);
    }
  }

  void _botAttackIfPossible() {
    if (state.phase != ReflexoMatchPhase.playerTurn ||
        state.activePlayer != ReflexoPlayerId.two) {
      return;
    }

    final attackers = state.current.field
        .where((u) => u.readyToAttack)
        .toList();
    if (attackers.isEmpty) return;

    attackers.sort((a, b) => b.visibleAttack.compareTo(a.visibleAttack));
    final attacker = attackers.first;
    selectUnit(attacker.instanceId);

    final enemyUnits = state.opponent.field;
    if (enemyUnits.isNotEmpty) {
      final targets = [...enemyUnits]
        ..sort((a, b) => a.health.compareTo(b.health));
      attackUnit(targets.first.instanceId);
      return;
    }

    attackReflexo();
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
