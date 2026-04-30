// ============================================================================
// FILE: lib/features/reflexo_card_game/domain/reflexo_content.dart
// ============================================================================

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
      id: 'raio_prismatico',
      name: 'Raio Prismático',
      type: ReflexoCardType.spell,
      cost: 2,
      attack: 0,
      health: 0,
      shield: 0,
      attribute: ReflexoAttribute.foco,
      archetype: ReflexoArchetype.oraculo,
      text: 'Causa 6 de dano à unidade inimiga com menor vida.',
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
  ];

  static List<ReflexoCardDefinition> buildDeck({required int seedOffset}) {
    final deck = <ReflexoCardDefinition>[];
    while (deck.length < 30) {
      for (final card in allCards) {
        deck.add(card);
        if (deck.length >= 30) break;
      }
    }
    final pivot = seedOffset % deck.length;
    return [...deck.sublist(pivot), ...deck.sublist(0, pivot)];
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

    ReflexoDestinyOption pick(List<ReflexoDestinyOption> list, int salt) {
      final source = list.isEmpty ? options : list;
      return source[(round + player.id.index + salt) % source.length];
    }

    return [pick(safe, 1), pick(mid, 2), pick(risky, 3)];
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
      case ReflexoArchetype.estrategista:
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
