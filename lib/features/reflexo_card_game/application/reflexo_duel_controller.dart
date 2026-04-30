// lib/features/reflexo_card_game/application/reflexo_duel_controller.dart

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/reflexo_content.dart';
import '../domain/reflexo_models.dart';

class ReflexoDuelController extends ChangeNotifier {
  ReflexoDuelController() {
    startNewGame();
  }

  final Random _rng = Random();
  int _unitSerial = 0;

  late ReflexoGameState state;

  void startNewGame() {
    _unitSerial = 0;
    final p1Deck = ReflexoContent.buildDeck(seedOffset: 0);
    final p2Deck = ReflexoContent.buildDeck(seedOffset: 5);

    var p1 = _buildPlayer(
      id: ReflexoPlayerId.one,
      name: 'Jogador 1',
      deck: p1Deck,
      main: ReflexoArchetype.berserker,
      secondary: ReflexoArchetype.guardiao,
    );
    var p2 = _buildPlayer(
      id: ReflexoPlayerId.two,
      name: 'Jogador 2',
      deck: p2Deck,
      main: ReflexoArchetype.estrategista,
      secondary: ReflexoArchetype.sombra,
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
      timeline: const [
        'Rodada 1 começou.',
        'Cada jogador escolhe um Destino e rola o próprio d20.',
      ],
    );
    notifyListeners();
  }

  ReflexoPlayerState _buildPlayer({
    required ReflexoPlayerId id,
    required String name,
    required List<ReflexoCardDefinition> deck,
    required ReflexoArchetype main,
    required ReflexoArchetype secondary,
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
      buffs: const [],
      attributes: ReflexoContent.attributesForPlayer(id),
      mainArchetype: main,
      secondaryArchetype: secondary,
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
  }

  void rollDestiny(ReflexoPlayerId playerId) {
    if (state.phase != ReflexoMatchPhase.destiny) return;
    final player = state.player(playerId);
    final destiny = player.selectedDestiny;
    if (destiny == null) {
      _addLog('${player.name} precisa escolher um Destino antes de rolar.');
      notifyListeners();
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
      updated = _applyDestinySuccess(updated, destiny, natural, total, bonus);
    } else {
      updated = _applyDestinyFailure(updated, destiny, natural, total, bonus);
    }

    _setPlayer(updated);
    if (_bothPlayersRolled()) {
      _startPlayerTurn(ReflexoPlayerId.one);
    }
    notifyListeners();
  }

  int _rollBonus(ReflexoPlayerState player, ReflexoDestinyOption destiny) {
    final instinto = player.attributes[ReflexoAttribute.instinto] ?? 0;
    final disciplina = player.attributes[ReflexoAttribute.disciplina] ?? 0;
    var bonus = 0;
    if (instinto >= 70 && destiny.requirement >= 12) bonus += 1;
    if (instinto >= 90 && destiny.requirement >= 18) bonus += 1;
    if (disciplina >= 70 && destiny.requirement <= 8) bonus += 1;
    if (player.mainArchetype == ReflexoArchetype.oraculo) bonus += 1;
    return bonus.clamp(0, 2).toInt();
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
          energy: (player.energy + destiny.amount).clamp(0, 12),
          buffs: [...player.buffs, _buffFromDestiny(destiny)],
        );
      case ReflexoDestinyEffect.attackAll:
      case ReflexoDestinyEffect.shieldAll:
      case ReflexoDestinyEffect.costReduction:
      case ReflexoDestinyEffect.directStrike:
        return player.copyWith(
          buffs: [...player.buffs, _buffFromDestiny(destiny)],
        );
      case ReflexoDestinyEffect.draw:
        return _drawCards(
          player,
          destiny.amount,
        ).copyWith(buffs: [...player.buffs, _buffFromDestiny(destiny)]);
      case ReflexoDestinyEffect.heal:
        return player.copyWith(
          life: min(100, player.life + destiny.amount),
          buffs: [...player.buffs, _buffFromDestiny(destiny)],
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
    // Falha não pune nesta versão. Ela só dá metade de efeitos seguros.
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

  void _startPlayerTurn(ReflexoPlayerId id) {
    final baseEnergy = state.round <= 3 ? 3 : 5;
    var player = state.player(id);
    final totalEnergy = (baseEnergy + player.reserve + player.energyBonus)
        .clamp(0, 10)
        .toInt();
    player = player.copyWith(
      energy: totalEnergy,
      reserve: 0,
      field: player.field
          .map((unit) => unit.copyWith(canAttack: true, exhausted: false))
          .toList(),
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

  void playCard(int handIndex) {
    if (state.phase != ReflexoMatchPhase.playerTurn) return;
    var player = state.current;
    if (handIndex < 0 || handIndex >= player.hand.length) return;
    final card = player.hand[handIndex];
    if (!card.isUnit) return;
    if (player.field.length >= 5) {
      _addLog('Campo cheio. Limite: 5 unidades.');
      notifyListeners();
      return;
    }
    final cost = effectiveCost(player, card);
    if (player.energy < cost) {
      _addLog('Energia insuficiente para ${card.name}.');
      notifyListeners();
      return;
    }

    final hand = [...player.hand]..removeAt(handIndex);
    final unit = _createUnit(player.id, card);
    final field = [...player.field, unit];
    player = player.copyWith(
      energy: player.energy - cost,
      hand: hand,
      field: field,
    );
    _setPlayer(player);
    _addLog('${player.name} colocou ${card.name} em campo.');
    notifyListeners();
  }

  int effectiveCost(ReflexoPlayerState player, ReflexoCardDefinition card) {
    final attribute = player.attributes[card.attribute] ?? 0;
    var reduction = player.costReduction;
    if (attribute >= 90) reduction += 1;
    return max(1, card.cost - reduction);
  }

  ReflexoUnitInstance _createUnit(
    ReflexoPlayerId owner,
    ReflexoCardDefinition card,
  ) {
    final player = state.player(owner);
    final attr = player.attributes[card.attribute] ?? 0;
    var healthBonus = 0;
    var attackBonus = 0;
    if (card.attribute == ReflexoAttribute.vigor && attr >= 50)
      healthBonus += 2;
    if (card.attribute == ReflexoAttribute.vigor && attr >= 70)
      healthBonus += 2;
    if (card.attribute == ReflexoAttribute.instinto && attr >= 70)
      attackBonus += 1;
    if (card.attribute == ReflexoAttribute.foco && attr >= 90) attackBonus += 1;

    final shield = card.shield + player.shieldBonus;
    return ReflexoUnitInstance(
      instanceId: 'u_${owner.index}_${_unitSerial++}',
      owner: owner,
      card: card,
      attack: card.attack + attackBonus,
      health: card.health + healthBonus,
      maxHealth: card.health + healthBonus,
      shield: shield,
      hasBarrier: card.abilities.contains(ReflexoAbility.barreira),
      canAttack: card.abilities.contains(ReflexoAbility.investida),
      exhausted: false,
      turnPlayed: state.round,
    );
  }

  void selectUnit(String unitId) {
    if (state.phase != ReflexoMatchPhase.playerTurn) return;
    final ownsUnit = state.current.field.any(
      (unit) => unit.instanceId == unitId,
    );
    if (!ownsUnit) return;
    state = state.copyWith(selectedUnitId: unitId);
    notifyListeners();
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

    final attackerDamage = attacker.visibleAttack + active.attackBonus;
    final defenderDamage = defender.hasAbility(ReflexoAbility.precisao)
        ? 0
        : defender.visibleAttack;
    final precision = attacker.hasAbility(ReflexoAbility.precisao);

    final updatedDefender = _damageUnit(defender, attackerDamage);
    final updatedAttacker = precision
        ? attacker
        : _damageUnit(attacker, defenderDamage);

    active = _replaceOrRemoveUnit(
      active,
      updatedAttacker.copyWith(exhausted: true, canAttack: false),
    );
    opponent = _replaceOrRemoveUnit(opponent, updatedDefender);

    if (attacker.hasAbility(ReflexoAbility.vinculo)) {
      active = active.copyWith(
        life: min(100, active.life + max(1, attackerDamage ~/ 2)),
      );
    }

    _setPlayers(active, opponent);
    state = state.copyWith(
      selectedUnitId: null,
      lastAttackAnimation: ReflexoAttackAnimation(
        attackerId: attacker.instanceId,
        targetUnitId: defenderId,
      ),
    );
    _addLog(
      '${active.name}: ${attacker.card.name} atacou ${defender.card.name}.',
    );
    _checkGameOver();
    notifyListeners();
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
      return;
    }

    var active = state.current;
    var opponent = state.opponent;
    final damage = attacker.visibleAttack + active.attackBonus;
    opponent = opponent.copyWith(life: max(0, opponent.life - damage));
    active = _replaceOrRemoveUnit(
      active,
      attacker.copyWith(exhausted: true, canAttack: false),
    );
    active = _consumeDirectChargeIfNeeded(active, attacker);

    if (attacker.hasAbility(ReflexoAbility.vinculo)) {
      active = active.copyWith(
        life: min(100, active.life + max(1, damage ~/ 2)),
      );
    }

    _setPlayers(active, opponent);
    state = state.copyWith(
      selectedUnitId: null,
      lastAttackAnimation: ReflexoAttackAnimation(
        attackerId: attacker.instanceId,
        targetPlayerId: opponent.id,
      ),
    );
    _addLog(
      '${active.name}: ${attacker.card.name} causou $damage no Reflexo inimigo.',
    );
    _checkGameOver();
    notifyListeners();
  }

  ReflexoPlayerState _consumeDirectChargeIfNeeded(
    ReflexoPlayerState player,
    ReflexoUnitInstance attacker,
  ) {
    if (attacker.hasAbility(ReflexoAbility.direto)) return player;
    if (player.field.length == 0) return player;
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
    final saved = (player.reserve + (player.energy < 0 ? 0 : player.energy))
        .clamp(0, 10)
        .toInt();
    player = player.copyWith(
      energy: 0,
      reserve: saved,
      turnsTaken: player.turnsTaken + 1,
      buffs: _tickBuffs(player.buffs),
    );
    _setPlayer(player);
    _addLog('${player.name} finalizou o turno. Reserva: $saved.');

    if (state.activePlayer == ReflexoPlayerId.one) {
      _startPlayerTurn(ReflexoPlayerId.two);
    } else {
      _startNextRound();
    }
    notifyListeners();
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
      players[id] = players[id]!.copyWith(selectedDestiny: null);
    }
    final nextRound = state.round + 1;
    state = state.copyWith(
      round: nextRound,
      phase: ReflexoMatchPhase.destiny,
      activePlayer: ReflexoPlayerId.one,
      players: players,
      selectedUnitId: null,
      destinyOptions: _buildDestinyOptions(players, nextRound),
    );
    _addLog('Rodada $nextRound começou. Nova Fase de Destino.');
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
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
