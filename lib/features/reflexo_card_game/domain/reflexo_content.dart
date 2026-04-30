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

    const weakPool = <ReflexoDestinyOption>[
      ReflexoDestinyOption(
        id: 'energia_fagulha',
        name: 'Fagulha de Energia',
        shortText: '+1 energia',
        requirement: 5,
        effect: ReflexoDestinyEffect.energy,
        amount: 1,
        durationTurns: 1,
        fullText: 'Ganha +1 energia no próximo turno deste jogador.',
      ),
      ReflexoDestinyOption(
        id: 'fio_lamina',
        name: 'Fio da Lâmina',
        shortText: '+1 ataque',
        requirement: 7,
        effect: ReflexoDestinyEffect.attackAll,
        amount: 1,
        durationTurns: 1,
        fullText: 'Suas unidades recebem +1 ataque neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'pele_ferro',
        name: 'Pele de Ferro',
        shortText: '+2 escudo',
        requirement: 6,
        effect: ReflexoDestinyEffect.shieldAll,
        amount: 2,
        durationTurns: 1,
        fullText: 'Suas próximas unidades entram com +2 escudo neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'olhar_tatico',
        name: 'Olhar Tático',
        shortText: 'compra 1',
        requirement: 8,
        effect: ReflexoDestinyEffect.draw,
        amount: 1,
        durationTurns: 1,
        fullText: 'Compre 1 carta.',
      ),
    ];

    const midPool = <ReflexoDestinyOption>[
      ReflexoDestinyOption(
        id: 'pulso_energia',
        name: 'Pulso de Energia',
        shortText: '+2 energia',
        requirement: 9,
        effect: ReflexoDestinyEffect.energy,
        amount: 2,
        durationTurns: 1,
        fullText: 'Ganha +2 energia no próximo turno deste jogador.',
      ),
      ReflexoDestinyOption(
        id: 'lamina_viva',
        name: 'Lâmina Viva',
        shortText: '+2 ataque',
        requirement: 12,
        effect: ReflexoDestinyEffect.attackAll,
        amount: 2,
        durationTurns: 1,
        fullText: 'Suas unidades recebem +2 ataque neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'muralha_rapida',
        name: 'Muralha Rápida',
        shortText: '+3 escudo',
        requirement: 10,
        effect: ReflexoDestinyEffect.shieldAll,
        amount: 3,
        durationTurns: 2,
        fullText: 'Suas próximas unidades entram com +3 escudo por 2 turnos.',
      ),
      ReflexoDestinyOption(
        id: 'forja_leve',
        name: 'Forja Leve',
        shortText: '-1 custo',
        requirement: 13,
        effect: ReflexoDestinyEffect.costReduction,
        amount: 1,
        durationTurns: 1,
        fullText: 'Suas cartas custam -1 neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'folego_reflexo',
        name: 'Fôlego do Reflexo',
        shortText: '+8 vida',
        requirement: 10,
        effect: ReflexoDestinyEffect.heal,
        amount: 8,
        durationTurns: 1,
        fullText: 'Cura 8 pontos de vida do seu Reflexo.',
      ),
    ];

    const latePool = <ReflexoDestinyOption>[
      ReflexoDestinyOption(
        id: 'brecha_absoluta',
        name: 'Brecha Absoluta',
        shortText: '1 ataque direto',
        requirement: 20,
        effect: ReflexoDestinyEffect.directStrike,
        amount: 1,
        durationTurns: 1,
        fullText:
            'Uma unidade pode atacar o Reflexo inimigo diretamente neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'surto_prismatico',
        name: 'Surto Prismático',
        shortText: '+3 energia',
        requirement: 16,
        effect: ReflexoDestinyEffect.energy,
        amount: 3,
        durationTurns: 1,
        fullText: 'Ganha +3 energia no próximo turno deste jogador.',
      ),
      ReflexoDestinyOption(
        id: 'comando_total',
        name: 'Comando Total',
        shortText: '+3 ataque',
        requirement: 17,
        effect: ReflexoDestinyEffect.attackAll,
        amount: 3,
        durationTurns: 1,
        fullText: 'Suas unidades recebem +3 ataque neste turno.',
      ),
      ReflexoDestinyOption(
        id: 'economia_arcana',
        name: 'Economia Arcana',
        shortText: '-2 custo',
        requirement: 18,
        effect: ReflexoDestinyEffect.costReduction,
        amount: 2,
        durationTurns: 1,
        fullText: 'Suas cartas custam -2 neste turno.',
      ),
    ];

    final available = <ReflexoDestinyOption>[
      ...weakPool,
      if (round >= 4) ...midPool,
      if (round >= 7) ...latePool,
    ];

    bool likes(ReflexoDestinyOption option) {
      return (main == ReflexoArchetype.berserker &&
              option.effect == ReflexoDestinyEffect.attackAll) ||
          (main == ReflexoArchetype.guardiao &&
              option.effect == ReflexoDestinyEffect.shieldAll) ||
          (main == ReflexoArchetype.estrategista &&
              option.effect == ReflexoDestinyEffect.draw) ||
          (main == ReflexoArchetype.sombra &&
              option.effect == ReflexoDestinyEffect.directStrike) ||
          (main == ReflexoArchetype.curador &&
              option.effect == ReflexoDestinyEffect.heal) ||
          (main == ReflexoArchetype.inventor &&
              option.effect == ReflexoDestinyEffect.costReduction);
    }

    final safe = available.where((e) => e.requirement <= 8).toList();
    final mid = available
        .where((e) => e.requirement > 8 && e.requirement < 16)
        .toList();
    final risky = available.where((e) => e.requirement >= 16).toList();
    final preferred = available.where(likes).toList();

    ReflexoDestinyOption pick(List<ReflexoDestinyOption> options, int salt) {
      final source = options.isEmpty ? available : options;
      return source[(round + player.id.index + salt) % source.length];
    }

    return [
      preferred.isNotEmpty
          ? preferred[(round + player.id.index) % preferred.length]
          : pick(safe, 1),
      pick(mid, 2),
      pick(risky.isEmpty ? mid : risky, 3),
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
