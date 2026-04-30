// ============================================================================
// FILE: lib/features/reflexo_card_game/domain/reflexo_models.dart
//
// O que faz:
// - Define todos os modelos do Reflexo Card Game.
// - Mantém as fases Destino, Tática, Pressão e Combate.
// - Define arquétipos com passiva base, despertar e progresso.
// - Define cartas, armadilhas, buffs, unidades, jogadores e estado da partida.
// ============================================================================

import 'dart:math';

import 'package:flutter/material.dart';

enum ReflexoPlayerId { one, two }

enum ReflexoMatchPhase { destiny, tactic, pressure, playerTurn, gameOver }

enum ReflexoCardType { unit, spell, trap, equipment }

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

enum ReflexoTacticEffect {
  reserve,
  draw,
  firstUnitAttack,
  firstUnitShield,
  heal,
  costReduction,
}

enum ReflexoPressureEffect {
  firstAttackBonus,
  firstCardDiscount,
  emptyFieldDraw,
  lowLifeFury,
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

  IconData get icon {
    switch (this) {
      case ReflexoArchetype.berserker:
        return Icons.local_fire_department_rounded;
      case ReflexoArchetype.guardiao:
        return Icons.shield_rounded;
      case ReflexoArchetype.estrategista:
        return Icons.psychology_alt_rounded;
      case ReflexoArchetype.oraculo:
        return Icons.casino_rounded;
      case ReflexoArchetype.curador:
        return Icons.healing_rounded;
      case ReflexoArchetype.sombra:
        return Icons.visibility_off_rounded;
      case ReflexoArchetype.inventor:
        return Icons.construction_rounded;
      case ReflexoArchetype.comandante:
        return Icons.flag_rounded;
      case ReflexoArchetype.alquimista:
        return Icons.science_rounded;
    }
  }

  String get shortDescription {
    switch (this) {
      case ReflexoArchetype.berserker:
        return 'Dano alto e pressão constante.';
      case ReflexoArchetype.guardiao:
        return 'Escudos, defesa e resistência.';
      case ReflexoArchetype.estrategista:
        return 'Compra, ritmo e controle de mão.';
      case ReflexoArchetype.oraculo:
        return 'Dado, Destino e manipulação de sorte.';
      case ReflexoArchetype.curador:
        return 'Cura, vínculo e sustentação.';
      case ReflexoArchetype.sombra:
        return 'Ataque direto, precisão e ameaça oculta.';
      case ReflexoArchetype.inventor:
        return 'Redução de custo e valor por recurso.';
      case ReflexoArchetype.comandante:
        return 'Campo cheio e fortalecimento de tropas.';
      case ReflexoArchetype.alquimista:
        return 'Transforma energia e reserva em vantagem.';
    }
  }

  String get basePassive {
    switch (this) {
      case ReflexoArchetype.berserker:
        return '+1 ataque em unidades ao entrar em campo.';
      case ReflexoArchetype.guardiao:
        return '+1 escudo em unidades ao entrar em campo.';
      case ReflexoArchetype.estrategista:
        return 'A cada 3 cartas jogadas no turno, compra 1 carta.';
      case ReflexoArchetype.oraculo:
        return '+1 em rolagens de d20 ligadas ao Destino.';
      case ReflexoArchetype.curador:
        return 'Vínculo cura um pouco mais.';
      case ReflexoArchetype.sombra:
        return 'Unidades com Direto causam +1 dano.';
      case ReflexoArchetype.inventor:
        return 'A primeira carta do turno custa -1.';
      case ReflexoArchetype.comandante:
        return 'Ao jogar a segunda carta no turno, aliados recebem +1/+1.';
      case ReflexoArchetype.alquimista:
        return 'Valoriza reserva e redução de custo em partidas longas.';
    }
  }

  String get awakenedPassive {
    switch (this) {
      case ReflexoArchetype.berserker:
        return '+2 ataque e dano excedente perfura o Reflexo.';
      case ReflexoArchetype.guardiao:
        return '+3 escudo em unidades ao entrar em campo.';
      case ReflexoArchetype.estrategista:
        return 'A cada 2 cartas jogadas no turno, compra 1 carta.';
      case ReflexoArchetype.oraculo:
        return '+1 extra em Destinos difíceis.';
      case ReflexoArchetype.curador:
        return 'Cura 2 de vida no fim do seu turno.';
      case ReflexoArchetype.sombra:
        return 'Primeiro atacante do turno age com Precisão.';
      case ReflexoArchetype.inventor:
        return 'A primeira carta do turno custa -2.';
      case ReflexoArchetype.comandante:
        return 'Sinergias de campo ficam mais agressivas.';
      case ReflexoArchetype.alquimista:
        return 'Com 3+ reserva, suas cartas custam -1.';
    }
  }

  String get awakenCondition {
    switch (this) {
      case ReflexoArchetype.berserker:
        return 'cause dano total';
      case ReflexoArchetype.guardiao:
        return 'gere escudo';
      case ReflexoArchetype.estrategista:
        return 'jogue cartas';
      case ReflexoArchetype.oraculo:
        return 'tenha sucessos no d20';
      case ReflexoArchetype.curador:
        return 'cure vida';
      case ReflexoArchetype.sombra:
        return 'cause dano direto';
      case ReflexoArchetype.inventor:
        return 'gaste energia';
      case ReflexoArchetype.comandante:
        return 'jogue cartas';
      case ReflexoArchetype.alquimista:
        return 'gaste energia';
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
  bool get isSpell => type == ReflexoCardType.spell;
  bool get isTrap => type == ReflexoCardType.trap;
  bool get isEquipment => type == ReflexoCardType.equipment;
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
class ReflexoTacticOption {
  const ReflexoTacticOption({
    required this.id,
    required this.name,
    required this.shortText,
    required this.effect,
    required this.amount,
    this.fullText = '',
  });

  final String id;
  final String name;
  final String shortText;
  final ReflexoTacticEffect effect;
  final int amount;
  final String fullText;
}

@immutable
class ReflexoPressureEvent {
  const ReflexoPressureEvent({
    required this.id,
    required this.name,
    String? shortText,
    String? fullText,
    String? description,
    required this.effect,
    required this.amount,
  }) : shortText = shortText ?? description ?? fullText ?? '',
       fullText = fullText ?? description ?? shortText ?? '';

  final String id;
  final String name;
  final String shortText;
  final String fullText;
  final ReflexoPressureEffect effect;
  final int amount;
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
    this.firstUnitAttackBonus = 0,
    this.firstUnitShieldBonus = 0,
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
  final int firstUnitAttackBonus;
  final int firstUnitShieldBonus;
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
    int? firstUnitAttackBonus,
    int? firstUnitShieldBonus,
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
      firstUnitAttackBonus: firstUnitAttackBonus ?? this.firstUnitAttackBonus,
      firstUnitShieldBonus: firstUnitShieldBonus ?? this.firstUnitShieldBonus,
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
    this.traps = const [],
    required this.buffs,
    required this.attributes,
    required this.mainArchetype,
    this.secondaryArchetype,
    this.selectedDestiny,
    this.selectedTactic,
    this.lastRoll,
    this.lastRollRound,
    this.turnsTaken = 0,
    this.cardsPlayedThisTurn = 0,
    this.cardsPlayedTotal = 0,
    this.energySpent = 0,
    this.damageDealt = 0,
    this.directDamageEvents = 0,
    this.healingDone = 0,
    this.shieldGenerated = 0,
    this.d20Successes = 0,
    this.archetypeAwakened = false,
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
  final List<ReflexoCardDefinition> traps;
  final List<ReflexoActiveBuff> buffs;
  final Map<ReflexoAttribute, int> attributes;
  final ReflexoArchetype mainArchetype;
  final ReflexoArchetype? secondaryArchetype;
  final ReflexoDestinyOption? selectedDestiny;
  final ReflexoTacticOption? selectedTactic;
  final int? lastRoll;
  final int? lastRollRound;
  final int turnsTaken;
  final int cardsPlayedThisTurn;
  final int cardsPlayedTotal;
  final int energySpent;
  final int damageDealt;
  final int directDamageEvents;
  final int healingDone;
  final int shieldGenerated;
  final int d20Successes;
  final bool archetypeAwakened;

  int get attackBonus => buffs.fold<int>(0, (a, b) => a + b.attackBonus);
  int get shieldBonus => buffs.fold<int>(0, (a, b) => a + b.shieldBonus);
  int get energyBonus => buffs.fold<int>(0, (a, b) => a + b.energyBonus);
  int get costReduction => buffs.fold<int>(0, (a, b) => a + b.costReduction);
  int get firstUnitAttackBonus =>
      buffs.fold<int>(0, (a, b) => a + b.firstUnitAttackBonus);
  int get firstUnitShieldBonus =>
      buffs.fold<int>(0, (a, b) => a + b.firstUnitShieldBonus);
  int get directCharges =>
      buffs.fold<int>(0, (a, b) => a + b.directStrikeCharges);
  bool get hasDirectCharge => directCharges > 0;

  int get archetypeGoal {
    switch (mainArchetype) {
      case ReflexoArchetype.berserker:
        return 30;
      case ReflexoArchetype.guardiao:
        return 18;
      case ReflexoArchetype.estrategista:
        return 8;
      case ReflexoArchetype.oraculo:
        return 3;
      case ReflexoArchetype.curador:
        return 16;
      case ReflexoArchetype.sombra:
        return 2;
      case ReflexoArchetype.inventor:
        return 20;
      case ReflexoArchetype.comandante:
        return 8;
      case ReflexoArchetype.alquimista:
        return 20;
    }
  }

  int get archetypeProgress {
    switch (mainArchetype) {
      case ReflexoArchetype.berserker:
        return damageDealt;
      case ReflexoArchetype.guardiao:
        return shieldGenerated;
      case ReflexoArchetype.estrategista:
        return cardsPlayedTotal;
      case ReflexoArchetype.oraculo:
        return d20Successes;
      case ReflexoArchetype.curador:
        return healingDone;
      case ReflexoArchetype.sombra:
        return directDamageEvents;
      case ReflexoArchetype.inventor:
        return energySpent;
      case ReflexoArchetype.comandante:
        return cardsPlayedTotal;
      case ReflexoArchetype.alquimista:
        return energySpent;
    }
  }

  double get archetypeProgressRatio {
    final goal = archetypeGoal;
    if (goal <= 0) return 1;
    return (archetypeProgress / goal).clamp(0.0, 1.0).toDouble();
  }

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
    List<ReflexoCardDefinition>? traps,
    List<ReflexoActiveBuff>? buffs,
    Map<ReflexoAttribute, int>? attributes,
    ReflexoArchetype? mainArchetype,
    Object? secondaryArchetype = _sentinel,
    Object? selectedDestiny = _sentinel,
    Object? selectedTactic = _sentinel,
    Object? lastRoll = _sentinel,
    Object? lastRollRound = _sentinel,
    int? turnsTaken,
    int? cardsPlayedThisTurn,
    int? cardsPlayedTotal,
    int? energySpent,
    int? damageDealt,
    int? directDamageEvents,
    int? healingDone,
    int? shieldGenerated,
    int? d20Successes,
    bool? archetypeAwakened,
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
      traps: traps ?? this.traps,
      buffs: buffs ?? this.buffs,
      attributes: attributes ?? this.attributes,
      mainArchetype: mainArchetype ?? this.mainArchetype,
      secondaryArchetype: secondaryArchetype == _sentinel
          ? this.secondaryArchetype
          : secondaryArchetype as ReflexoArchetype?,
      selectedDestiny: selectedDestiny == _sentinel
          ? this.selectedDestiny
          : selectedDestiny as ReflexoDestinyOption?,
      selectedTactic: selectedTactic == _sentinel
          ? this.selectedTactic
          : selectedTactic as ReflexoTacticOption?,
      lastRoll: lastRoll == _sentinel ? this.lastRoll : lastRoll as int?,
      lastRollRound: lastRollRound == _sentinel
          ? this.lastRollRound
          : lastRollRound as int?,
      turnsTaken: turnsTaken ?? this.turnsTaken,
      cardsPlayedThisTurn: cardsPlayedThisTurn ?? this.cardsPlayedThisTurn,
      cardsPlayedTotal: cardsPlayedTotal ?? this.cardsPlayedTotal,
      energySpent: energySpent ?? this.energySpent,
      damageDealt: damageDealt ?? this.damageDealt,
      directDamageEvents: directDamageEvents ?? this.directDamageEvents,
      healingDone: healingDone ?? this.healingDone,
      shieldGenerated: shieldGenerated ?? this.shieldGenerated,
      d20Successes: d20Successes ?? this.d20Successes,
      archetypeAwakened: archetypeAwakened ?? this.archetypeAwakened,
    );
  }
}

@immutable
class ReflexoAttackAnimation {
  const ReflexoAttackAnimation({
    required this.attackerId,
    this.targetUnitId,
    this.targetPlayerId,
    this.serial = 0,
  });

  final String attackerId;
  final String? targetUnitId;
  final ReflexoPlayerId? targetPlayerId;
  final int serial;
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
    this.tacticOptions = const {},
    this.pressureEvent,
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
  final Map<ReflexoPlayerId, List<ReflexoTacticOption>> tacticOptions;
  final ReflexoPressureEvent? pressureEvent;
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
    Map<ReflexoPlayerId, List<ReflexoTacticOption>>? tacticOptions,
    Object? pressureEvent = _sentinel,
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
      tacticOptions: tacticOptions ?? this.tacticOptions,
      pressureEvent: pressureEvent == _sentinel
          ? this.pressureEvent
          : pressureEvent as ReflexoPressureEvent?,
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
