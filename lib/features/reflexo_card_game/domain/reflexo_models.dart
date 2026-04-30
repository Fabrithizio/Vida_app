// lib/features/reflexo_card_game/domain/reflexo_models.dart

import 'dart:math';

import 'package:flutter/material.dart';

enum ReflexoPlayerId { one, two }

enum ReflexoMatchPhase { destiny, playerTurn, gameOver }

enum ReflexoCardType { unit, spell, equipment }

enum ReflexoAttribute { vigor, foco, disciplina, influencia, recurso, instinto }

enum ReflexoArchetype {
  berserker,
  guardiao,
  estrategista,
  oraculo,
  curador,
  sombra,
  inventor,
  comandante,
  alquimista,
}

enum ReflexoAbility {
  investida,
  guardiao,
  direto,
  barreira,
  vinculo,
  precisao,
  furia,
  eco,
}

enum ReflexoDestinyEffect {
  energy,
  attackAll,
  shieldAll,
  draw,
  directStrike,
  heal,
  costReduction,
}

extension ReflexoPlayerIdX on ReflexoPlayerId {
  String get label => this == ReflexoPlayerId.one ? 'Jogador 1' : 'Jogador 2';

  ReflexoPlayerId get opponent =>
      this == ReflexoPlayerId.one ? ReflexoPlayerId.two : ReflexoPlayerId.one;
}

extension ReflexoAttributeX on ReflexoAttribute {
  String get label {
    switch (this) {
      case ReflexoAttribute.vigor:
        return 'Vigor';
      case ReflexoAttribute.foco:
        return 'Foco';
      case ReflexoAttribute.disciplina:
        return 'Disciplina';
      case ReflexoAttribute.influencia:
        return 'Influência';
      case ReflexoAttribute.recurso:
        return 'Recurso';
      case ReflexoAttribute.instinto:
        return 'Instinto';
    }
  }

  IconData get icon {
    switch (this) {
      case ReflexoAttribute.vigor:
        return Icons.favorite_rounded;
      case ReflexoAttribute.foco:
        return Icons.psychology_rounded;
      case ReflexoAttribute.disciplina:
        return Icons.track_changes_rounded;
      case ReflexoAttribute.influencia:
        return Icons.groups_rounded;
      case ReflexoAttribute.recurso:
        return Icons.diamond_rounded;
      case ReflexoAttribute.instinto:
        return Icons.auto_awesome_rounded;
    }
  }
}

extension ReflexoArchetypeX on ReflexoArchetype {
  String get label {
    switch (this) {
      case ReflexoArchetype.berserker:
        return 'Berserker';
      case ReflexoArchetype.guardiao:
        return 'Guardião';
      case ReflexoArchetype.estrategista:
        return 'Estrategista';
      case ReflexoArchetype.oraculo:
        return 'Oráculo';
      case ReflexoArchetype.curador:
        return 'Curador';
      case ReflexoArchetype.sombra:
        return 'Sombra';
      case ReflexoArchetype.inventor:
        return 'Inventor';
      case ReflexoArchetype.comandante:
        return 'Comandante';
      case ReflexoArchetype.alquimista:
        return 'Alquimista';
    }
  }

  String get shortDescription {
    switch (this) {
      case ReflexoArchetype.berserker:
        return 'Mais rolagens agressivas e dano explosivo.';
      case ReflexoArchetype.guardiao:
        return 'Escudos, defesa e proteção do campo.';
      case ReflexoArchetype.estrategista:
        return 'Compra, custo e controle da mão.';
      case ReflexoArchetype.oraculo:
        return 'Dado, Destino e manipulação de sorte.';
      case ReflexoArchetype.curador:
        return 'Cura, vínculo e sustentação.';
      case ReflexoArchetype.sombra:
        return 'Precisão, ataque direto raro e sabotagem.';
      case ReflexoArchetype.inventor:
        return 'Equipamentos e melhorias em unidades.';
      case ReflexoArchetype.comandante:
        return 'Campo cheio, aliados e sinergia.';
      case ReflexoArchetype.alquimista:
        return 'Transformação de recursos e cartas.';
    }
  }
}

extension ReflexoAbilityX on ReflexoAbility {
  String get label {
    switch (this) {
      case ReflexoAbility.investida:
        return 'Investida';
      case ReflexoAbility.guardiao:
        return 'Guardião';
      case ReflexoAbility.direto:
        return 'Direto';
      case ReflexoAbility.barreira:
        return 'Barreira';
      case ReflexoAbility.vinculo:
        return 'Vínculo';
      case ReflexoAbility.precisao:
        return 'Precisão';
      case ReflexoAbility.furia:
        return 'Fúria';
      case ReflexoAbility.eco:
        return 'Eco';
    }
  }

  String get description {
    switch (this) {
      case ReflexoAbility.investida:
        return 'Pode atacar no turno em que entra.';
      case ReflexoAbility.guardiao:
        return 'O inimigo deve atacar esta unidade antes das outras.';
      case ReflexoAbility.direto:
        return 'Pode atacar o Reflexo inimigo diretamente.';
      case ReflexoAbility.barreira:
        return 'Ignora o primeiro dano recebido.';
      case ReflexoAbility.vinculo:
        return 'Ao causar dano, cura seu Reflexo.';
      case ReflexoAbility.precisao:
        return 'Ataca unidades sem receber contra-ataque.';
      case ReflexoAbility.furia:
        return 'Ganha ataque ao sobreviver dano.';
      case ReflexoAbility.eco:
        return 'Pode repetir parte do efeito com rolagem.';
    }
  }
}

@immutable
class ReflexoCardDefinition {
  const ReflexoCardDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.cost,
    required this.attack,
    required this.health,
    required this.shield,
    required this.attribute,
    required this.archetype,
    this.secondaryAttribute,
    this.abilities = const [],
    this.text = '',
    this.imageAsset,
  });

  final String id;
  final String name;
  final ReflexoCardType type;
  final int cost;
  final int attack;
  final int health;
  final int shield;
  final ReflexoAttribute attribute;
  final ReflexoAttribute? secondaryAttribute;
  final ReflexoArchetype archetype;
  final List<ReflexoAbility> abilities;
  final String text;
  final String? imageAsset;

  bool get isUnit => type == ReflexoCardType.unit;
}

@immutable
class ReflexoDestinyOption {
  const ReflexoDestinyOption({
    required this.id,
    required this.name,
    required this.shortText,
    required this.requirement,
    required this.effect,
    required this.amount,
    required this.durationTurns,
    this.fullText = '',
  });

  final String id;
  final String name;
  final String shortText;
  final int requirement;
  final ReflexoDestinyEffect effect;
  final int amount;
  final int durationTurns;
  final String fullText;

  bool get lastsWholeMatch => durationTurns <= 0;

  String get durationLabel {
    if (durationTurns <= 0) return 'partida inteira';
    if (durationTurns == 1) return '1 turno';
    return '$durationTurns turnos';
  }
}

@immutable
class ReflexoActiveBuff {
  const ReflexoActiveBuff({
    required this.id,
    required this.name,
    required this.summary,
    this.attackBonus = 0,
    this.shieldBonus = 0,
    this.energyBonus = 0,
    this.costReduction = 0,
    this.healPerTurn = 0,
    this.drawBonus = 0,
    this.directStrikeCharges = 0,
    this.turnsRemaining,
  });

  final String id;
  final String name;
  final String summary;
  final int attackBonus;
  final int shieldBonus;
  final int energyBonus;
  final int costReduction;
  final int healPerTurn;
  final int drawBonus;
  final int directStrikeCharges;
  final int? turnsRemaining;

  bool get isPermanent => turnsRemaining == null;

  ReflexoActiveBuff tick() {
    final turns = turnsRemaining;
    if (turns == null) return this;
    return copyWith(turnsRemaining: max(0, turns - 1));
  }

  ReflexoActiveBuff consumeDirectCharge() =>
      copyWith(directStrikeCharges: max(0, directStrikeCharges - 1));

  ReflexoActiveBuff copyWith({
    String? id,
    String? name,
    String? summary,
    int? attackBonus,
    int? shieldBonus,
    int? energyBonus,
    int? costReduction,
    int? healPerTurn,
    int? drawBonus,
    int? directStrikeCharges,
    Object? turnsRemaining = _sentinel,
  }) {
    return ReflexoActiveBuff(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      attackBonus: attackBonus ?? this.attackBonus,
      shieldBonus: shieldBonus ?? this.shieldBonus,
      energyBonus: energyBonus ?? this.energyBonus,
      costReduction: costReduction ?? this.costReduction,
      healPerTurn: healPerTurn ?? this.healPerTurn,
      drawBonus: drawBonus ?? this.drawBonus,
      directStrikeCharges: directStrikeCharges ?? this.directStrikeCharges,
      turnsRemaining: turnsRemaining == _sentinel
          ? this.turnsRemaining
          : turnsRemaining as int?,
    );
  }
}

const Object _sentinel = Object();

@immutable
class ReflexoUnitInstance {
  const ReflexoUnitInstance({
    required this.instanceId,
    required this.owner,
    required this.card,
    required this.attack,
    required this.health,
    required this.maxHealth,
    required this.shield,
    this.hasBarrier = false,
    this.canAttack = false,
    this.exhausted = false,
    this.turnPlayed = 0,
    this.temporaryBuffs = const [],
  });

  final String instanceId;
  final ReflexoPlayerId owner;
  final ReflexoCardDefinition card;
  final int attack;
  final int health;
  final int maxHealth;
  final int shield;
  final bool hasBarrier;
  final bool canAttack;
  final bool exhausted;
  final int turnPlayed;
  final List<ReflexoActiveBuff> temporaryBuffs;

  bool get alive => health > 0;
  bool get readyToAttack => canAttack && !exhausted && attack > 0;
  bool hasAbility(ReflexoAbility ability) => card.abilities.contains(ability);

  int get bonusAttack =>
      temporaryBuffs.fold<int>(0, (a, b) => a + b.attackBonus);
  int get visibleAttack => attack + bonusAttack;

  ReflexoUnitInstance copyWith({
    String? instanceId,
    ReflexoPlayerId? owner,
    ReflexoCardDefinition? card,
    int? attack,
    int? health,
    int? maxHealth,
    int? shield,
    bool? hasBarrier,
    bool? canAttack,
    bool? exhausted,
    int? turnPlayed,
    List<ReflexoActiveBuff>? temporaryBuffs,
  }) {
    return ReflexoUnitInstance(
      instanceId: instanceId ?? this.instanceId,
      owner: owner ?? this.owner,
      card: card ?? this.card,
      attack: attack ?? this.attack,
      health: health ?? this.health,
      maxHealth: maxHealth ?? this.maxHealth,
      shield: shield ?? this.shield,
      hasBarrier: hasBarrier ?? this.hasBarrier,
      canAttack: canAttack ?? this.canAttack,
      exhausted: exhausted ?? this.exhausted,
      turnPlayed: turnPlayed ?? this.turnPlayed,
      temporaryBuffs: temporaryBuffs ?? this.temporaryBuffs,
    );
  }
}

@immutable
class ReflexoPlayerState {
  const ReflexoPlayerState({
    required this.id,
    required this.name,
    required this.life,
    required this.energy,
    required this.reserve,
    required this.deck,
    required this.hand,
    required this.field,
    required this.discard,
    required this.buffs,
    required this.attributes,
    required this.mainArchetype,
    required this.secondaryArchetype,
    this.selectedDestiny,
    this.lastRoll,
    this.lastRollRound,
    this.turnsTaken = 0,
  });

  final ReflexoPlayerId id;
  final String name;
  final int life;
  final int energy;
  final int reserve;
  final List<ReflexoCardDefinition> deck;
  final List<ReflexoCardDefinition> hand;
  final List<ReflexoUnitInstance> field;
  final List<ReflexoCardDefinition> discard;
  final List<ReflexoActiveBuff> buffs;
  final Map<ReflexoAttribute, int> attributes;
  final ReflexoArchetype mainArchetype;
  final ReflexoArchetype secondaryArchetype;
  final ReflexoDestinyOption? selectedDestiny;
  final int? lastRoll;
  final int? lastRollRound;
  final int turnsTaken;

  int get attackBonus => buffs.fold<int>(0, (a, b) => a + b.attackBonus);
  int get shieldBonus => buffs.fold<int>(0, (a, b) => a + b.shieldBonus);
  int get energyBonus => buffs.fold<int>(0, (a, b) => a + b.energyBonus);
  int get costReduction => buffs.fold<int>(0, (a, b) => a + b.costReduction);
  int get directCharges =>
      buffs.fold<int>(0, (a, b) => a + b.directStrikeCharges);
  bool get hasDirectCharge => directCharges > 0;

  ReflexoPlayerState copyWith({
    ReflexoPlayerId? id,
    String? name,
    int? life,
    int? energy,
    int? reserve,
    List<ReflexoCardDefinition>? deck,
    List<ReflexoCardDefinition>? hand,
    List<ReflexoUnitInstance>? field,
    List<ReflexoCardDefinition>? discard,
    List<ReflexoActiveBuff>? buffs,
    Map<ReflexoAttribute, int>? attributes,
    ReflexoArchetype? mainArchetype,
    ReflexoArchetype? secondaryArchetype,
    Object? selectedDestiny = _sentinel,
    Object? lastRoll = _sentinel,
    Object? lastRollRound = _sentinel,
    int? turnsTaken,
  }) {
    return ReflexoPlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      life: life ?? this.life,
      energy: energy ?? this.energy,
      reserve: reserve ?? this.reserve,
      deck: deck ?? this.deck,
      hand: hand ?? this.hand,
      field: field ?? this.field,
      discard: discard ?? this.discard,
      buffs: buffs ?? this.buffs,
      attributes: attributes ?? this.attributes,
      mainArchetype: mainArchetype ?? this.mainArchetype,
      secondaryArchetype: secondaryArchetype ?? this.secondaryArchetype,
      selectedDestiny: selectedDestiny == _sentinel
          ? this.selectedDestiny
          : selectedDestiny as ReflexoDestinyOption?,
      lastRoll: lastRoll == _sentinel ? this.lastRoll : lastRoll as int?,
      lastRollRound: lastRollRound == _sentinel
          ? this.lastRollRound
          : lastRollRound as int?,
      turnsTaken: turnsTaken ?? this.turnsTaken,
    );
  }
}

@immutable
class ReflexoAttackAnimation {
  const ReflexoAttackAnimation({
    required this.attackerId,
    this.targetUnitId,
    this.targetPlayerId,
  });

  final String attackerId;
  final String? targetUnitId;
  final ReflexoPlayerId? targetPlayerId;
}

@immutable
class ReflexoGameState {
  const ReflexoGameState({
    required this.round,
    required this.phase,
    required this.activePlayer,
    required this.players,
    required this.timeline,
    required this.destinyOptions,
    this.selectedUnitId,
    this.winner,
    this.lastAttackAnimation,
  });

  final int round;
  final ReflexoMatchPhase phase;
  final ReflexoPlayerId activePlayer;
  final Map<ReflexoPlayerId, ReflexoPlayerState> players;
  final List<String> timeline;
  final Map<ReflexoPlayerId, List<ReflexoDestinyOption>> destinyOptions;
  final String? selectedUnitId;
  final ReflexoPlayerId? winner;
  final ReflexoAttackAnimation? lastAttackAnimation;

  ReflexoPlayerState player(ReflexoPlayerId id) => players[id]!;
  ReflexoPlayerState get current => player(activePlayer);
  ReflexoPlayerState get opponent => player(activePlayer.opponent);

  ReflexoGameState copyWith({
    int? round,
    ReflexoMatchPhase? phase,
    ReflexoPlayerId? activePlayer,
    Map<ReflexoPlayerId, ReflexoPlayerState>? players,
    List<String>? timeline,
    Map<ReflexoPlayerId, List<ReflexoDestinyOption>>? destinyOptions,
    Object? selectedUnitId = _sentinel,
    Object? winner = _sentinel,
    Object? lastAttackAnimation = _sentinel,
  }) {
    return ReflexoGameState(
      round: round ?? this.round,
      phase: phase ?? this.phase,
      activePlayer: activePlayer ?? this.activePlayer,
      players: players ?? this.players,
      timeline: timeline ?? this.timeline,
      destinyOptions: destinyOptions ?? this.destinyOptions,
      selectedUnitId: selectedUnitId == _sentinel
          ? this.selectedUnitId
          : selectedUnitId as String?,
      winner: winner == _sentinel ? this.winner : winner as ReflexoPlayerId?,
      lastAttackAnimation: lastAttackAnimation == _sentinel
          ? this.lastAttackAnimation
          : lastAttackAnimation as ReflexoAttackAnimation?,
    );
  }
}
