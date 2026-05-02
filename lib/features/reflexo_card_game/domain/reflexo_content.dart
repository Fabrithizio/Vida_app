// ============================================================================
// FILE: lib/features/reflexo_card_game/domain/reflexo_content.dart
// ============================================================================

import 'dart:math';

import 'reflexo_models.dart';

class ReflexoContent {
  const ReflexoContent._();

  static const int deckSize = 30;
  static const int minUnits = 18;
  static const int maxSpells = 8;
  static const int maxTraps = 6;
  static const int maxCopies = 2;
  static const int maxHeavyCards = 4;

  static const List<ReflexoCardDefinition> allCards = [
    ReflexoCardDefinition(
      id: 'astra',
      name: 'Astra',
      type: ReflexoCardType.unit,
      cost: 2,
      attack: 7,
      health: 13,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      archetype: ReflexoArchetype.berserker,
      abilities: [ReflexoAbility.investida],
      imageAsset: 'assets/images/reflexo/cards/Astra.png',
      text: 'Atacante inicial veloz. Entra pressionando o campo.',
    ),
    ReflexoCardDefinition(
      id: 'lumina',
      name: 'Lumina',
      type: ReflexoCardType.unit,
      cost: 3,
      attack: 8,
      health: 16,
      shield: 1,
      attribute: ReflexoAttribute.influencia,
      archetype: ReflexoArchetype.curador,
      abilities: [ReflexoAbility.vinculo],
      imageAsset: 'assets/images/reflexo/cards/Lumina.png',
      text: 'Cura seu Reflexo ao causar dano.',
    ),
    ReflexoCardDefinition(
      id: 'eris',
      name: 'Eris',
      type: ReflexoCardType.unit,
      cost: 3,
      attack: 6,
      health: 17,
      shield: 3,
      attribute: ReflexoAttribute.disciplina,
      archetype: ReflexoArchetype.guardiao,
      abilities: [ReflexoAbility.guardiao],
      imageAsset: 'assets/images/reflexo/cards/Eris.png',
      text: 'Unidade defensiva para segurar pressão inicial.',
    ),
    ReflexoCardDefinition(
      id: 'lin',
      name: 'Lin',
      type: ReflexoCardType.unit,
      cost: 2,
      attack: 5,
      health: 14,
      shield: 2,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.estrategista,
      abilities: [ReflexoAbility.precisao],
      imageAsset: 'assets/images/reflexo/cards/Lin.png',
      text: 'Pequena, precisa e ótima para eliminar alvos frágeis.',
    ),
    ReflexoCardDefinition(
      id: 'mia',
      name: 'Mia',
      type: ReflexoCardType.unit,
      cost: 4,
      attack: 10,
      health: 16,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      archetype: ReflexoArchetype.sombra,
      abilities: [ReflexoAbility.direto],
      imageAsset: 'assets/images/reflexo/cards/mia.png',
      text: 'Pode atacar o Reflexo diretamente, mas exige proteção.',
    ),
    ReflexoCardDefinition(
      id: 'zion',
      name: 'Zion',
      type: ReflexoCardType.unit,
      cost: 5,
      attack: 13,
      health: 22,
      shield: 2,
      attribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.inventor,
      abilities: [ReflexoAbility.barreira],
      imageAsset: 'assets/images/reflexo/cards/Zion.png',
      text: 'Ignora o primeiro dano recebido.',
    ),
    ReflexoCardDefinition(
      id: 'valerius',
      name: 'Valerius',
      type: ReflexoCardType.unit,
      cost: 6,
      attack: 15,
      health: 25,
      shield: 3,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.oraculo,
      abilities: [ReflexoAbility.eco],
      imageAsset: 'assets/images/reflexo/cards/Valerius.png',
      text: 'Unidade pesada de controle. Forte, mas vulnerável a anti-tanque.',
    ),
    ReflexoCardDefinition(
      id: 'mago_anciao',
      name: 'Mago Ancião',
      type: ReflexoCardType.unit,
      cost: 7,
      attack: 17,
      health: 28,
      shield: 2,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.oraculo,
      abilities: [ReflexoAbility.precisao],
      imageAsset: 'assets/images/reflexo/cards/Mago_ancião.png',
      text:
          'Pesado e preciso. Controla o campo sem tomar contra-ataque em empate.',
    ),
    ReflexoCardDefinition(
      id: 'lia_noa',
      name: 'Lia & Noa',
      type: ReflexoCardType.unit,
      cost: 5,
      attack: 11,
      health: 21,
      shield: 1,
      attribute: ReflexoAttribute.influencia,
      archetype: ReflexoArchetype.comandante,
      abilities: [ReflexoAbility.eco],
      imageAsset: 'assets/images/reflexo/cards/Lia & Noa.png',
      text: 'Boa em decks com campo cheio. Ajuda o plano de Comandante.',
    ),
    ReflexoCardDefinition(
      id: 'sentinela_ferro',
      name: 'Sentinela de Ferro',
      type: ReflexoCardType.unit,
      cost: 2,
      attack: 6,
      health: 18,
      shield: 3,
      attribute: ReflexoAttribute.vigor,
      archetype: ReflexoArchetype.guardiao,
      abilities: [ReflexoAbility.guardiao],
      text: 'Defensor resistente. Obriga o inimigo a lidar com ele primeiro.',
    ),
    ReflexoCardDefinition(
      id: 'lamina_impulso',
      name: 'Lâmina de Impulso',
      type: ReflexoCardType.unit,
      cost: 3,
      attack: 12,
      health: 12,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      archetype: ReflexoArchetype.berserker,
      abilities: [ReflexoAbility.investida],
      text: 'Pode atacar assim que entra. Forte para pressão rápida.',
    ),
    ReflexoCardDefinition(
      id: 'arqueira_sombra',
      name: 'Arqueira Sombra',
      type: ReflexoCardType.unit,
      cost: 4,
      attack: 8,
      health: 10,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      secondaryAttribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.sombra,
      abilities: [ReflexoAbility.direto],
      text: 'Pode atacar o Reflexo diretamente, mas tem dano baixo.',
    ),
    ReflexoCardDefinition(
      id: 'golem_reserva',
      name: 'Golem da Reserva',
      type: ReflexoCardType.unit,
      cost: 5,
      attack: 13,
      health: 24,
      shield: 4,
      attribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.inventor,
      abilities: [ReflexoAbility.barreira],
      text: 'Ignora o primeiro dano recebido.',
    ),
    ReflexoCardDefinition(
      id: 'furia_crescente',
      name: 'Fúria Crescente',
      type: ReflexoCardType.unit,
      cost: 7,
      attack: 18,
      health: 22,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      archetype: ReflexoArchetype.berserker,
      abilities: [ReflexoAbility.furia],
      text: 'Ganha força quando sobrevive dano.',
    ),
    ReflexoCardDefinition(
      id: 'colosso_prismatico',
      name: 'Colosso Prismático',
      type: ReflexoCardType.unit,
      cost: 9,
      attack: 23,
      health: 38,
      shield: 5,
      attribute: ReflexoAttribute.vigor,
      secondaryAttribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.guardiao,
      abilities: [ReflexoAbility.guardiao, ReflexoAbility.barreira],
      text:
          'Carta pesada e impactante. Sofre contra ataque combinado e anti-tanque.',
    ),
    ReflexoCardDefinition(
      id: 'dano_instantaneo',
      name: 'Dano Instantâneo',
      type: ReflexoCardType.spell,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.oraculo,
      imageAsset: 'assets/images/reflexo/cards/dano.png',
      text: 'Causa 6 de dano à unidade inimiga com menor vida.',
    ),
    ReflexoCardDefinition(
      id: 'ponte_magica',
      name: 'Ponte Mágica',
      type: ReflexoCardType.spell,
      cost: 3,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.alquimista,
      imageAsset: 'assets/images/reflexo/cards/Ponte_magico.png',
      text: 'Compre 1 carta e ganhe +1 reserva.',
    ),
    ReflexoCardDefinition(
      id: 'forca_subita',
      name: 'Força Súbita',
      type: ReflexoCardType.spell,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      archetype: ReflexoArchetype.berserker,
      text: 'Sua primeira unidade em campo recebe +3 ataque.',
    ),
    ReflexoCardDefinition(
      id: 'reparo_rapido',
      name: 'Reparo Rápido',
      type: ReflexoCardType.spell,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.inventor,
      text: 'Cura 8 de vida da sua unidade mais ferida.',
    ),
    ReflexoCardDefinition(
      id: 'quebra_armadura',
      name: 'Quebra-Armadura',
      type: ReflexoCardType.spell,
      cost: 3,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.disciplina,
      archetype: ReflexoArchetype.guardiao,
      text:
          'Remove todo escudo da unidade inimiga com mais escudo e causa 4 dano.',
    ),
    ReflexoCardDefinition(
      id: 'ruptura_colosso',
      name: 'Ruptura de Colosso',
      type: ReflexoCardType.spell,
      cost: 4,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.estrategista,
      text: 'Causa 14 dano a uma unidade pesada inimiga.',
    ),
    ReflexoCardDefinition(
      id: 'selamento_pesado',
      name: 'Selamento Pesado',
      type: ReflexoCardType.spell,
      cost: 3,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.disciplina,
      archetype: ReflexoArchetype.oraculo,
      text:
          'A unidade inimiga de maior ataque não pode atacar no próximo turno.',
    ),
    ReflexoCardDefinition(
      id: 'armadilha_espelhada',
      name: 'Armadilha Espelhada',
      type: ReflexoCardType.trap,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.instinto,
      archetype: ReflexoArchetype.sombra,
      text:
          'Fica virada. Quando o inimigo atacar, causa 5 de dano ao atacante.',
    ),
    ReflexoCardDefinition(
      id: 'barreira_oculta',
      name: 'Barreira Oculta',
      type: ReflexoCardType.trap,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.disciplina,
      archetype: ReflexoArchetype.guardiao,
      text:
          'Fica virada. Quando seu Reflexo receber ataque direto, reduz 6 de dano.',
    ),
    ReflexoCardDefinition(
      id: 'rede_contencao',
      name: 'Rede de Contenção',
      type: ReflexoCardType.trap,
      cost: 3,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.estrategista,
      text: 'Fica virada. Quando uma unidade pesada atacar, ela recebe 8 dano.',
    ),
    ReflexoCardDefinition(
      id: 'mina_fragmentos',
      name: 'Mina de Fragmentos',
      type: ReflexoCardType.trap,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.inventor,
      text:
          'Fica virada. Quando o inimigo jogar a segunda carta no turno, causa 4 dano ao Reflexo inimigo.',
    ),
  ];

  static final Map<String, ReflexoCardDefinition> byId = {
    for (final card in allCards) card.id: card,
  };

  static const List<ReflexoDeckTemplate> starterDecks = [
    ReflexoDeckTemplate(
      id: 'berserker_agressivo',
      name: 'Berserker Agressivo',
      description: 'Pressão rápida, ataque alto e poucas paredes.',
      archetype: ReflexoArchetype.berserker,
      cardIds: [
        'astra',
        'astra',
        'lamina_impulso',
        'lamina_impulso',
        'furia_crescente',
        'furia_crescente',
        'mia',
        'mia',
        'lin',
        'lin',
        'lumina',
        'lumina',
        'eris',
        'eris',
        'zion',
        'zion',
        'sentinela_ferro',
        'sentinela_ferro',
        'forca_subita',
        'forca_subita',
        'dano_instantaneo',
        'dano_instantaneo',
        'ponte_magica',
        'quebra_armadura',
        'armadilha_espelhada',
        'armadilha_espelhada',
        'barreira_oculta',
        'rede_contencao',
        'mina_fragmentos',
        'mina_fragmentos',
      ],
    ),
    ReflexoDeckTemplate(
      id: 'guardiao_resistente',
      name: 'Guardião Resistente',
      description: 'Escudos, unidades pesadas e respostas anti-tanque.',
      archetype: ReflexoArchetype.guardiao,
      cardIds: [
        'eris',
        'eris',
        'sentinela_ferro',
        'sentinela_ferro',
        'golem_reserva',
        'golem_reserva',
        'zion',
        'zion',
        'valerius',
        'valerius',
        'colosso_prismatico',
        'colosso_prismatico',
        'lumina',
        'lumina',
        'lin',
        'lin',
        'lia_noa',
        'lia_noa',
        'quebra_armadura',
        'quebra_armadura',
        'reparo_rapido',
        'reparo_rapido',
        'ponte_magica',
        'selamento_pesado',
        'barreira_oculta',
        'barreira_oculta',
        'rede_contencao',
        'rede_contencao',
        'armadilha_espelhada',
        'mina_fragmentos',
      ],
    ),
    ReflexoDeckTemplate(
      id: 'estrategista_controle',
      name: 'Estrategista Controle',
      description: 'Compra, precisão, magia e controle de unidades grandes.',
      archetype: ReflexoArchetype.estrategista,
      cardIds: [
        'lin',
        'lin',
        'lia_noa',
        'lia_noa',
        'mago_anciao',
        'mago_anciao',
        'valerius',
        'valerius',
        'lumina',
        'lumina',
        'mia',
        'mia',
        'astra',
        'astra',
        'eris',
        'eris',
        'zion',
        'zion',
        'dano_instantaneo',
        'dano_instantaneo',
        'ponte_magica',
        'ponte_magica',
        'ruptura_colosso',
        'ruptura_colosso',
        'selamento_pesado',
        'quebra_armadura',
        'rede_contencao',
        'rede_contencao',
        'barreira_oculta',
        'mina_fragmentos',
      ],
    ),
  ];

  static ReflexoDeckTemplate get defaultDeck => starterDecks.first;

  static List<ReflexoCardDefinition> cardsFromIds(List<String> ids) {
    return ids
        .map((id) => byId[id])
        .whereType<ReflexoCardDefinition>()
        .toList();
  }

  static List<ReflexoCardDefinition> buildDeck({
    required int seedOffset,
    List<String>? customIds,
  }) {
    final ids = customIds;
    if (ids != null && ids.length == deckSize && validateDeckIds(ids).isValid) {
      return cardsFromIds(ids);
    }
    final template = starterDecks[seedOffset % starterDecks.length];
    return cardsFromIds(template.cardIds);
  }

  static ReflexoDeckValidation validateDeckIds(List<String> ids) {
    final cards = cardsFromIds(ids);
    final messages = <String>[];
    final unitCount = cards.where((c) => c.isUnit).length;
    final spellCount = cards.where((c) => c.isSpell).length;
    final trapCount = cards.where((c) => c.isTrap).length;
    final heavyCount = cards.where((c) => c.isHeavy).length;

    if (ids.length != deckSize)
      messages.add('O deck precisa ter $deckSize cartas.');
    if (unitCount < minUnits)
      messages.add('Use pelo menos $minUnits unidades.');
    if (spellCount > maxSpells)
      messages.add('Use no máximo $maxSpells feitiços.');
    if (trapCount > maxTraps)
      messages.add('Use no máximo $maxTraps armadilhas.');
    if (heavyCount > maxHeavyCards)
      messages.add('Use no máximo $maxHeavyCards cartas pesadas.');

    final counts = <String, int>{};
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final tooMany = counts.entries.where((e) => e.value > maxCopies).toList();
    if (tooMany.isNotEmpty)
      messages.add('Máximo de $maxCopies cópias da mesma carta.');

    return ReflexoDeckValidation(
      status: messages.isEmpty
          ? ReflexoDeckValidationStatus.valid
          : ReflexoDeckValidationStatus.invalid,
      messages: messages,
      unitCount: unitCount,
      spellCount: spellCount,
      trapCount: trapCount,
      heavyCount: heavyCount,
      totalCount: ids.length,
    );
  }

  static Map<ReflexoAttribute, int> attributesForPlayer(ReflexoPlayerId id) {
    if (id == ReflexoPlayerId.one) {
      return const {
        ReflexoAttribute.vigor: 72,
        ReflexoAttribute.foco: 64,
        ReflexoAttribute.disciplina: 58,
        ReflexoAttribute.influencia: 70,
        ReflexoAttribute.recurso: 52,
        ReflexoAttribute.instinto: 81,
      };
    }
    return const {
      ReflexoAttribute.vigor: 62,
      ReflexoAttribute.foco: 76,
      ReflexoAttribute.disciplina: 68,
      ReflexoAttribute.influencia: 55,
      ReflexoAttribute.recurso: 74,
      ReflexoAttribute.instinto: 60,
    };
  }

  static List<ReflexoDestinyOption> destinyPoolFor({
    required ReflexoPlayerState player,
    required int round,
  }) {
    final early = round < 4;
    final midGame = round >= 4 && round < 7;
    final options = <ReflexoDestinyOption>[
      const ReflexoDestinyOption(
        id: 'energia_rapida',
        name: 'Pulso de Energia',
        shortText: '+1 energia',
        requirement: 5,
        effect: ReflexoDestinyEffect.energy,
        amount: 1,
        durationTurns: 1,
        fullText: 'Ganha +1 energia neste turno.',
      ),
      const ReflexoDestinyOption(
        id: 'compra_tatica',
        name: 'Compra Tática',
        shortText: 'compra 1',
        requirement: 8,
        effect: ReflexoDestinyEffect.draw,
        amount: 1,
        durationTurns: 1,
        fullText: 'Compre 1 carta.',
      ),
      ReflexoDestinyOption(
        id: 'ataque_medio',
        name: early ? 'Afiar Lâmina' : 'Lâmina Viva',
        shortText: early ? '+1 ataque' : '+2 ataque',
        requirement: early ? 9 : 12,
        effect: ReflexoDestinyEffect.attackAll,
        amount: early ? 1 : 2,
        durationTurns: 1,
        fullText: 'Suas unidades recebem bônus de ataque neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'muralha_rapida',
        name: early ? 'Postura Firme' : 'Muralha Rápida',
        shortText: early ? '+1 escudo' : '+3 escudo',
        requirement: early ? 7 : 10,
        effect: ReflexoDestinyEffect.shieldAll,
        amount: early ? 1 : 3,
        durationTurns: 2,
        fullText: 'Suas próximas unidades entram com mais escudo.',
      ),
      if (!early)
        const ReflexoDestinyOption(
          id: 'forja_leve',
          name: 'Forja Leve',
          shortText: '-1 custo',
          requirement: 14,
          effect: ReflexoDestinyEffect.costReduction,
          amount: 1,
          durationTurns: 1,
          fullText: 'Suas cartas custam -1 neste turno.',
        ),
      if (!early)
        const ReflexoDestinyOption(
          id: 'cura_reflexo',
          name: 'Fôlego do Reflexo',
          shortText: '+8 vida',
          requirement: 10,
          effect: ReflexoDestinyEffect.heal,
          amount: 8,
          durationTurns: 1,
          fullText: 'Cura 8 pontos de vida do seu Reflexo.',
        ),
      if (!early && !midGame)
        const ReflexoDestinyOption(
          id: 'brecha_absoluta',
          name: 'Brecha Absoluta',
          shortText: '1 ataque direto',
          requirement: 20,
          effect: ReflexoDestinyEffect.directStrike,
          amount: 1,
          durationTurns: 1,
          fullText: 'Uma unidade pode atacar o Reflexo inimigo diretamente.',
        ),
    ];

    final safe = options.where((e) => e.requirement <= 8).toList();
    final mid = options
        .where((e) => e.requirement > 8 && e.requirement < 18)
        .toList();
    final risky = options.where((e) => e.requirement >= 18).toList();

    ReflexoDestinyOption pick(
      List<ReflexoDestinyOption> list,
      int salt,
      Set<String> used,
    ) {
      final source = list.isEmpty ? options : list;
      for (var offset = 0; offset < source.length; offset++) {
        final candidate =
            source[(round + player.id.index + salt + offset) % source.length];
        if (used.add(candidate.id)) return candidate;
      }
      for (final candidate in options) {
        if (used.add(candidate.id)) return candidate;
      }
      return source.first;
    }

    final used = <String>{};
    return [pick(safe, 1, used), pick(mid, 2, used), pick(risky, 3, used)];
  }

  static List<ReflexoTacticOption> tacticOptionsFor({
    required ReflexoPlayerState player,
    required int round,
  }) {
    final first = round.isEven
        ? const ReflexoTacticOption(
            id: 'reserva_tatica',
            name: 'Guardar Fôlego',
            shortText: '+2 reserva',
            effect: ReflexoTacticEffect.reserve,
            amount: 2,
            fullText: 'Ganha +2 de reserva para preparar jogadas maiores.',
          )
        : const ReflexoTacticOption(
            id: 'compra_tatica_plano',
            name: 'Ler o Campo',
            shortText: 'compra 1',
            effect: ReflexoTacticEffect.draw,
            amount: 1,
            fullText: 'Compra 1 carta.',
          );

    ReflexoTacticOption second;
    switch (player.mainArchetype) {
      case ReflexoArchetype.berserker:
        second = const ReflexoTacticOption(
          id: 'plano_agressivo',
          name: 'Plano Agressivo',
          shortText: '+2 ataque na 1ª unidade',
          effect: ReflexoTacticEffect.firstUnitAttack,
          amount: 2,
          fullText: 'A próxima unidade que você jogar recebe +2 ataque.',
        );
        break;
      case ReflexoArchetype.guardiao:
        second = const ReflexoTacticOption(
          id: 'plano_defensivo',
          name: 'Plano Defensivo',
          shortText: '+3 escudo na 1ª unidade',
          effect: ReflexoTacticEffect.firstUnitShield,
          amount: 3,
          fullText: 'A próxima unidade que você jogar recebe +3 escudo.',
        );
        break;
      case ReflexoArchetype.curador:
        second = const ReflexoTacticOption(
          id: 'plano_cura',
          name: 'Respirar',
          shortText: '+5 vida',
          effect: ReflexoTacticEffect.heal,
          amount: 5,
          fullText: 'Cura 5 de vida do seu Reflexo.',
        );
        break;
      default:
        second = const ReflexoTacticOption(
          id: 'plano_economico',
          name: 'Plano Econômico',
          shortText: '-1 custo neste turno',
          effect: ReflexoTacticEffect.costReduction,
          amount: 1,
          fullText: 'Suas cartas custam -1 neste turno.',
        );
    }

    return [first, second];
  }

  static ReflexoPressureEvent pressureForRound(int round) {
    final index = (round ~/ 3) % 4;
    switch (index) {
      case 0:
        return const ReflexoPressureEvent(
          id: 'pressao_ataque',
          name: 'Pressão de Combate',
          shortText: '1º ataque de cada jogador causa +2 dano.',
          effect: ReflexoPressureEffect.firstAttackBonus,
          amount: 2,
        );
      case 1:
        return const ReflexoPressureEvent(
          id: 'ritmo_forcado',
          name: 'Ritmo Forçado',
          shortText: '1ª carta de cada jogador custa -1.',
          effect: ReflexoPressureEffect.firstCardDiscount,
          amount: 1,
        );
      case 2:
        return const ReflexoPressureEvent(
          id: 'campo_instavel',
          name: 'Campo Instável',
          shortText: 'Quem terminar sem unidades compra 1 carta.',
          effect: ReflexoPressureEffect.emptyFieldDraw,
          amount: 1,
        );
      default:
        return const ReflexoPressureEvent(
          id: 'furia_baixa',
          name: 'Fúria de Sobrevivência',
          shortText: 'Unidades leves entram com +2 ataque.',
          effect: ReflexoPressureEffect.lowLifeFury,
          amount: 2,
        );
    }
  }
}
