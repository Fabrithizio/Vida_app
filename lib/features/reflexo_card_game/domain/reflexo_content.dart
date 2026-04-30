// lib/features/reflexo_card_game/domain/reflexo_content.dart

import 'reflexo_models.dart';

class ReflexoContent {
  const ReflexoContent._();

  static const List<ReflexoCardDefinition> allCards = [
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
      id: 'monge_vinculo',
      name: 'Monge do Vínculo',
      type: ReflexoCardType.unit,
      cost: 3,
      attack: 7,
      health: 16,
      shield: 1,
      attribute: ReflexoAttribute.influencia,
      archetype: ReflexoArchetype.curador,
      abilities: [ReflexoAbility.vinculo],
      text: 'Cura seu Reflexo quando causa dano.',
    ),
    ReflexoCardDefinition(
      id: 'tatico_cristal',
      name: 'Tático de Cristal',
      type: ReflexoCardType.unit,
      cost: 4,
      attack: 7,
      health: 15,
      shield: 2,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.estrategista,
      abilities: [ReflexoAbility.precisao],
      text: 'Ataca unidades sem receber contra-ataque.',
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
      id: 'porta_bandeira',
      name: 'Porta-Bandeira',
      type: ReflexoCardType.unit,
      cost: 4,
      attack: 8,
      health: 18,
      shield: 1,
      attribute: ReflexoAttribute.influencia,
      archetype: ReflexoArchetype.comandante,
      abilities: [ReflexoAbility.eco],
      text: 'Unidade de sinergia. Boa para sustentar campo.',
    ),
    ReflexoCardDefinition(
      id: 'transmutador',
      name: 'Transmutador',
      type: ReflexoCardType.unit,
      cost: 5,
      attack: 10,
      health: 20,
      shield: 2,
      attribute: ReflexoAttribute.recurso,
      secondaryAttribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.alquimista,
      abilities: [ReflexoAbility.eco],
      text: 'Transforma vantagem de recurso em presença de campo.',
    ),
    ReflexoCardDefinition(
      id: 'oraculo_d20',
      name: 'Oráculo do D20',
      type: ReflexoCardType.unit,
      cost: 6,
      attack: 11,
      health: 19,
      shield: 2,
      attribute: ReflexoAttribute.instinto,
      secondaryAttribute: ReflexoAttribute.disciplina,
      archetype: ReflexoArchetype.oraculo,
      abilities: [ReflexoAbility.eco],
      text: 'Melhora partidas longas com efeitos ligados ao dado.',
    ),
    ReflexoCardDefinition(
      id: 'colosso_prismatico',
      name: 'Colosso Prismático',
      type: ReflexoCardType.unit,
      cost: 10,
      attack: 26,
      health: 42,
      shield: 6,
      attribute: ReflexoAttribute.vigor,
      secondaryAttribute: ReflexoAttribute.recurso,
      archetype: ReflexoArchetype.guardiao,
      abilities: [ReflexoAbility.guardiao, ReflexoAbility.barreira],
      text: 'Carta pesada e impactante. Não vence sozinha, mas muda o campo.',
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
      id: 'escudeira_serena',
      name: 'Escudeira Serena',
      type: ReflexoCardType.unit,
      cost: 2,
      attack: 5,
      health: 14,
      shield: 5,
      attribute: ReflexoAttribute.disciplina,
      archetype: ReflexoArchetype.guardiao,
      abilities: [ReflexoAbility.guardiao],
      text: 'Defesa inicial para segurar o primeiro impacto.',
    ),
  ];

  static List<ReflexoCardDefinition> buildDeck({required int seedOffset}) {
    final deck = <ReflexoCardDefinition>[];
    while (deck.length < 30) {
      for (final card in allCards) {
        deck.add(card);
        if (deck.length >= 30) break;
      }
    }
    final first = deck.sublist(0, seedOffset % deck.length);
    final second = deck.sublist(seedOffset % deck.length);
    return [...second, ...first];
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
    final main = player.mainArchetype;
    final pool = <ReflexoDestinyOption>[
      const ReflexoDestinyOption(
        id: 'energia_rapida',
        name: 'Pulso de Energia',
        shortText: '+2 energia',
        requirement: 6,
        effect: ReflexoDestinyEffect.energy,
        amount: 2,
        durationTurns: 1,
        fullText: 'Ganha +2 energia neste turno.',
      ),
      const ReflexoDestinyOption(
        id: 'ataque_medio',
        name: 'Lâmina Viva',
        shortText: '+2 dano nas unidades',
        requirement: 12,
        effect: ReflexoDestinyEffect.attackAll,
        amount: 2,
        durationTurns: 1,
        fullText: 'Suas unidades recebem +2 ataque neste turno.',
      ),
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
      const ReflexoDestinyOption(
        id: 'muralha_rapida',
        name: 'Muralha Rápida',
        shortText: '+3 escudo no campo',
        requirement: 9,
        effect: ReflexoDestinyEffect.shieldAll,
        amount: 3,
        durationTurns: 2,
        fullText: 'Suas unidades atuais recebem +3 escudo.',
      ),
      const ReflexoDestinyOption(
        id: 'compra_tatica',
        name: 'Compra Tática',
        shortText: 'compra 1 carta',
        requirement: 8,
        effect: ReflexoDestinyEffect.draw,
        amount: 1,
        durationTurns: 1,
        fullText: 'Compre 1 carta.',
      ),
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
      const ReflexoDestinyOption(
        id: 'forja_leve',
        name: 'Forja Leve',
        shortText: '-1 custo neste turno',
        requirement: 14,
        effect: ReflexoDestinyEffect.costReduction,
        amount: 1,
        durationTurns: 1,
        fullText: 'Suas cartas custam -1 neste turno.',
      ),
    ];

    final preferred = <ReflexoDestinyOption>[];
    for (final option in pool) {
      if (main == ReflexoArchetype.berserker &&
          option.effect == ReflexoDestinyEffect.attackAll) {
        preferred.add(option);
      }
      if (main == ReflexoArchetype.guardiao &&
          option.effect == ReflexoDestinyEffect.shieldAll) {
        preferred.add(option);
      }
      if (main == ReflexoArchetype.estrategista &&
          option.effect == ReflexoDestinyEffect.draw) {
        preferred.add(option);
      }
      if (main == ReflexoArchetype.sombra &&
          option.effect == ReflexoDestinyEffect.directStrike) {
        preferred.add(option);
      }
      if (main == ReflexoArchetype.curador &&
          option.effect == ReflexoDestinyEffect.heal) {
        preferred.add(option);
      }
      if (main == ReflexoArchetype.inventor &&
          option.effect == ReflexoDestinyEffect.costReduction) {
        preferred.add(option);
      }
    }

    final safe = pool.where((e) => e.requirement <= 8).toList();
    final mid = pool
        .where((e) => e.requirement > 8 && e.requirement < 18)
        .toList();
    final risky = pool.where((e) => e.requirement >= 18).toList();

    ReflexoDestinyOption pick(List<ReflexoDestinyOption> options, int salt) {
      return options[(round + player.id.index + salt) % options.length];
    }

    return [
      preferred.isNotEmpty
          ? preferred[(round + player.id.index) % preferred.length]
          : pick(safe, 1),
      pick(mid, 2),
      pick(risky, 3),
    ];
  }

  static String archetypePassive(
    ReflexoArchetype archetype, {
    required bool main,
  }) {
    final prefix = main ? 'Principal' : 'Secundário';
    switch (archetype) {
      case ReflexoArchetype.berserker:
        return '$prefix: pressão ofensiva; Destinos de dano aparecem mais.';
      case ReflexoArchetype.guardiao:
        return '$prefix: proteção; Destinos de escudo aparecem mais.';
      case ReflexoArchetype.estrategista:
        return '$prefix: consistência; compra e redução de custo aparecem mais.';
      case ReflexoArchetype.oraculo:
        return '$prefix: manipula o dado; mais efeitos de Destino.';
      case ReflexoArchetype.curador:
        return '$prefix: recuperação; cura e vínculo aparecem mais.';
      case ReflexoArchetype.sombra:
        return '$prefix: brechas; ataques diretos raros aparecem mais.';
      case ReflexoArchetype.inventor:
        return '$prefix: equipamentos e custo; valor por recurso.';
      case ReflexoArchetype.comandante:
        return '$prefix: campo cheio e buffs de aliados.';
      case ReflexoArchetype.alquimista:
        return '$prefix: transforma energia e cartas em vantagem.';
    }
  }
}
