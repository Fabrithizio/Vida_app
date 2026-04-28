// ============================================================================
// FILE: lib/features/areas/application/profile/areas_rpg_profile_engine.dart
//
// O que faz:
// - Traduz o estado atual do Areas para uma ficha RPG
// - Escolhe classe, atributos, rank e dado adaptativo
// - Gera também o livro de regras para o usuário entender tudo
//
// Filosofia desta versão:
// - o Areas decide os pesos base
// - a classe reequilibra os atributos como num RPG
// - atributos podem subir e descer por efeito cruzado
// - o dado do dia usa o estado vivido ontem/mais recente
// ============================================================================

import 'dart:math' as math;

import 'package:vida_app/features/areas/application/profile/areas_rpg_profile_models.dart';
import 'package:vida_app/features/home/presentation/tabs/areas_tab_controller.dart';

class AreasRpgProfileEngine {
  AreasRpgProfileEngine({AreasTabController? controller})
    : _controller = controller ?? AreasTabController();

  final AreasTabController _controller;

  Future<AreasRpgProfileSnapshot> build({
    required String userName,
    required Map<String, int?> areaScores,
  }) async {
    final classificationLabel = await _controller.currentProfileLabel();
    final normalized = _normalize(areaScores);
    final archetype = _pickArchetype(normalized, classificationLabel);
    final raw = _baseAttributesFromAreas(normalized);
    final classAdjusted = _applyArchetypeModifiers(archetype, raw);
    final crossed = _applyCrossAttributeTradeoffs(classAdjusted);
    final attributes = _buildAttributeScores(crossed);
    final totalPower = attributes.fold<int>(0, (sum, item) => sum + item.value);
    final dice = _buildDice(attributes, archetype, classificationLabel);
    final rankLabel = _rankFromPower(totalPower);
    final rules = _buildRules(archetype, attributes, dice);

    return AreasRpgProfileSnapshot(
      userName: userName,
      classificationLabel: classificationLabel,
      archetype: archetype,
      rankLabel: rankLabel,
      attributes: attributes,
      dice: dice,
      totalPower: totalPower,
      rules: rules,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, double> _normalize(Map<String, int?> scores) {
    final map = <String, double>{};
    scores.forEach((key, value) {
      map[key] = ((value ?? 0).clamp(0, 100)) / 100.0;
    });
    return map;
  }

  double _s(Map<String, double> scores, String key) => scores[key] ?? 0.0;

  RpgArchetype _pickArchetype(
    Map<String, double> scores,
    String classificationLabel,
  ) {
    final body = _s(scores, 'body_health');
    final mind = _s(scores, 'mind_emotion');
    final purpose = _s(scores, 'purpose_values');
    final finance = _s(scores, 'finance_material');
    final learning = _s(scores, 'learning_intellect');
    final digital = _s(scores, 'digital_tech');
    final env = _s(scores, 'environment_home');

    final weights = <RpgArchetype, double>{
      RpgArchetype.warrior: body * 1.45 + purpose * 0.35 + learning * 0.25,
      RpgArchetype.mage: mind * 1.30 + learning * 0.95 + purpose * 0.55,
      RpgArchetype.ranger:
          body * 0.80 + digital * 0.90 + env * 0.60 + purpose * 0.40,
      RpgArchetype.rogue:
          digital * 1.10 + finance * 0.70 + learning * 0.55 + mind * 0.35,
      RpgArchetype.cleric:
          mind * 1.00 + body * 0.85 + env * 0.65 + purpose * 0.75,
      RpgArchetype.paladin:
          purpose * 1.05 + body * 0.95 + finance * 0.60 + learning * 0.60,
    };

    final lower = classificationLabel.toLowerCase();
    if (lower.contains('adapta')) {
      weights[RpgArchetype.ranger] = (weights[RpgArchetype.ranger] ?? 0) + 0.08;
    }
    if (lower.contains('disc') || lower.contains('const')) {
      weights[RpgArchetype.paladin] =
          (weights[RpgArchetype.paladin] ?? 0) + 0.08;
    }

    return weights.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Map<RpgAttributeType, double> _baseAttributesFromAreas(
    Map<String, double> scores,
  ) {
    final body = _s(scores, 'body_health');
    final mind = _s(scores, 'mind_emotion');
    final purpose = _s(scores, 'purpose_values');
    final finance = _s(scores, 'finance_material');
    final learning = _s(scores, 'learning_intellect');
    final digital = _s(scores, 'digital_tech');
    final env = _s(scores, 'environment_home');

    return {
      RpgAttributeType.strength: 7 + body * 9 + purpose * 2 + learning * 1,
      RpgAttributeType.dexterity: 7 + digital * 5 + learning * 4 + body * 3,
      RpgAttributeType.vitality: 7 + body * 10 + env * 2 + mind * 2,
      RpgAttributeType.intelligence: 7 + learning * 9 + mind * 5 + finance * 2,
      RpgAttributeType.wisdom: 7 + purpose * 8 + mind * 6 + env * 2,
      RpgAttributeType.charisma:
          7 + mind * 4 + env * 4 + digital * 2 + purpose * 2,
      RpgAttributeType.discipline:
          7 + learning * 6 + finance * 5 + body * 3 + purpose * 3,
      RpgAttributeType.luck:
          7 + digital * 3 + mind * 2 + learning * 2 + finance * 2,
    };
  }

  Map<RpgAttributeType, double> _applyArchetypeModifiers(
    RpgArchetype archetype,
    Map<RpgAttributeType, double> raw,
  ) {
    final out = Map<RpgAttributeType, double>.from(raw);

    void boost(RpgAttributeType type, double value) {
      out[type] = (out[type] ?? 0) + value;
    }

    switch (archetype) {
      case RpgArchetype.warrior:
        boost(RpgAttributeType.strength, 4);
        boost(RpgAttributeType.vitality, 3);
        boost(RpgAttributeType.discipline, 1);
        boost(RpgAttributeType.intelligence, -1);
        break;
      case RpgArchetype.mage:
        boost(RpgAttributeType.intelligence, 4);
        boost(RpgAttributeType.wisdom, 3);
        boost(RpgAttributeType.strength, -2);
        break;
      case RpgArchetype.ranger:
        boost(RpgAttributeType.dexterity, 4);
        boost(RpgAttributeType.wisdom, 1);
        boost(RpgAttributeType.luck, 2);
        break;
      case RpgArchetype.rogue:
        boost(RpgAttributeType.dexterity, 3);
        boost(RpgAttributeType.charisma, 2);
        boost(RpgAttributeType.luck, 2);
        boost(RpgAttributeType.vitality, -1);
        break;
      case RpgArchetype.cleric:
        boost(RpgAttributeType.wisdom, 3);
        boost(RpgAttributeType.vitality, 2);
        boost(RpgAttributeType.charisma, 2);
        break;
      case RpgArchetype.paladin:
        boost(RpgAttributeType.strength, 2);
        boost(RpgAttributeType.discipline, 4);
        boost(RpgAttributeType.vitality, 2);
        break;
    }

    return out;
  }

  Map<RpgAttributeType, double> _applyCrossAttributeTradeoffs(
    Map<RpgAttributeType, double> raw,
  ) {
    final out = Map<RpgAttributeType, double>.from(raw);

    final strength = out[RpgAttributeType.strength] ?? 0;
    final intelligence = out[RpgAttributeType.intelligence] ?? 0;
    final charisma = out[RpgAttributeType.charisma] ?? 0;
    final discipline = out[RpgAttributeType.discipline] ?? 0;
    final luck = out[RpgAttributeType.luck] ?? 0;
    final dexterity = out[RpgAttributeType.dexterity] ?? 0;

    if (strength >= 17 && intelligence <= 11) {
      out[RpgAttributeType.dexterity] =
          (out[RpgAttributeType.dexterity] ?? 0) - 1.2;
    }

    if (intelligence >= 18 && (out[RpgAttributeType.vitality] ?? 0) <= 11) {
      out[RpgAttributeType.strength] =
          (out[RpgAttributeType.strength] ?? 0) - 1.0;
    }

    if (charisma >= 17 && discipline <= 11) {
      out[RpgAttributeType.discipline] =
          (out[RpgAttributeType.discipline] ?? 0) - 0.8;
    }

    if (discipline >= 18 && luck <= 10) {
      out[RpgAttributeType.charisma] =
          (out[RpgAttributeType.charisma] ?? 0) - 0.6;
    }

    if (dexterity >= 18 && strength <= 10) {
      out[RpgAttributeType.vitality] =
          (out[RpgAttributeType.vitality] ?? 0) - 0.7;
    }

    out.updateAll((key, value) => value.clamp(3.0, 25.0));
    return out;
  }

  List<RpgAttributeScore> _buildAttributeScores(
    Map<RpgAttributeType, double> values,
  ) {
    String tier(int value) {
      if (value >= 22) return 'Lendário';
      if (value >= 18) return 'Elite';
      if (value >= 14) return 'Alto';
      if (value >= 10) return 'Médio';
      if (value >= 7) return 'Baixo';
      return 'Crítico';
    }

    String reason(RpgAttributeType type) {
      switch (type) {
        case RpgAttributeType.strength:
          return 'Pesa mais corpo, energia e imposição física.';
        case RpgAttributeType.dexterity:
          return 'Pesa agilidade, adaptação, precisão e execução.';
        case RpgAttributeType.vitality:
          return 'Pesa resistência, estabilidade e sustentação do personagem.';
        case RpgAttributeType.intelligence:
          return 'Pesa estudo, leitura de sistema e capacidade mental.';
        case RpgAttributeType.wisdom:
          return 'Pesa direção, propósito e leitura de longo prazo.';
        case RpgAttributeType.charisma:
          return 'Pesa presença, magnetismo e influência social.';
        case RpgAttributeType.discipline:
          return 'Pesa rotina, constância, controle e firmeza.';
        case RpgAttributeType.luck:
          return 'Pesa variabilidade favorável do momento.';
      }
    }

    return RpgAttributeType.values
        .map((type) {
          final value = (values[type] ?? 0).round().clamp(1, 25);
          return RpgAttributeScore(
            type: type,
            value: value,
            tierLabel: tier(value),
            reason: reason(type),
          );
        })
        .toList(growable: false);
  }

  RpgDiceProfile _buildDice(
    List<RpgAttributeScore> attributes,
    RpgArchetype archetype,
    String classificationLabel,
  ) {
    final avg =
        attributes.fold<int>(0, (sum, e) => sum + e.value) /
        math.max(attributes.length, 1);
    final discipline = attributes
        .firstWhere((e) => e.type == RpgAttributeType.discipline)
        .value;
    final vitality = attributes
        .firstWhere((e) => e.type == RpgAttributeType.vitality)
        .value;
    final intelligence = attributes
        .firstWhere((e) => e.type == RpgAttributeType.intelligence)
        .value;
    final luck = attributes
        .firstWhere((e) => e.type == RpgAttributeType.luck)
        .value;

    int minRoll = 1;
    int maxRoll = 20;

    if (avg >= 16) minRoll += 2;
    if (avg >= 18) minRoll += 1;
    if (discipline >= 18) minRoll += 1;
    if (vitality <= 8) maxRoll -= 1;
    if (luck >= 18) maxRoll += 1;
    if (classificationLabel.toLowerCase().contains('ótimo')) {
      minRoll += 1;
    }

    minRoll = minRoll.clamp(1, 12);
    maxRoll = maxRoll.clamp(12, 20);

    String title;
    String advantage;
    String risk;

    switch (archetype) {
      case RpgArchetype.warrior:
        title = 'D20 de Investida';
        advantage = 'Bônus em testes físicos e pressão';
        risk = 'Perde finesse se o dia veio pesado';
        break;
      case RpgArchetype.mage:
        title = 'D20 Arcano';
        advantage = 'Bônus em leitura, estratégia e magia';
        risk = 'Oscila mais se a base física cair';
        break;
      case RpgArchetype.ranger:
        title = 'D20 de Caçada';
        advantage = 'Bônus em precisão, percepção e reação';
        risk = 'Perde força bruta em confronto direto';
        break;
      case RpgArchetype.rogue:
        title = 'D20 Sombrio';
        advantage = 'Bônus em iniciativa, astúcia e improviso';
        risk = 'Sofre se a disciplina desabar';
        break;
      case RpgArchetype.cleric:
        title = 'D20 Sagrado';
        advantage = 'Bônus em suporte, recuperação e proteção';
        risk = 'Explode menos em dano bruto';
        break;
      case RpgArchetype.paladin:
        title = 'D20 do Juramento';
        advantage = 'Bônus em firmeza, defesa e moral';
        risk = 'Fica mais rígido quando o ritmo cai';
        break;
    }

    final reason =
        'Seu dado usa base D20, mas se adapta ao dia anterior. '
        'Quanto melhor o conjunto dos atributos, maior o piso do lançamento. '
        'Hoje ele rola de $minRoll até $maxRoll. Inteligência atual: $intelligence.';

    return RpgDiceProfile(
      title: title,
      diceSides: 20,
      minimumRoll: minRoll,
      maximumRoll: maxRoll,
      advantageLabel: advantage,
      riskLabel: risk,
      reason: reason,
    );
  }

  String _rankFromPower(int totalPower) {
    if (totalPower >= 150) return 'Mestre';
    if (totalPower >= 130) return 'Diamante';
    if (totalPower >= 112) return 'Ouro';
    if (totalPower >= 96) return 'Prata';
    if (totalPower >= 80) return 'Bronze';
    return 'Iniciante';
  }

  List<RpgRulesBookSection> _buildRules(
    RpgArchetype archetype,
    List<RpgAttributeScore> attributes,
    RpgDiceProfile dice,
  ) {
    return [
      RpgRulesBookSection(
        title: 'Classe',
        points: [
          'A classe é escolhida pelo conjunto mais forte do seu perfil, mas no formato clássico de RPG: ${archetype.label}.',
          'Ela redistribui pesos e pode reforçar ou enfraquecer atributos específicos.',
          'Pontos fortes atuais da classe: ${archetype.strengths.join(', ')}.',
        ],
      ),
      RpgRulesBookSection(
        title: 'Atributos',
        points: [
          'Os atributos vão de 1 a 25.',
          'O Areas define a base deles, mas a ficha é tratada como RPG normal, com leitura cruzada entre atributos.',
          'Se um atributo explode demais e outro fica muito baixo, pode haver penalidade cruzada para evitar ficha quebrada.',
          'Atributo mais alto atual: ${attributes.reduce((a, b) => a.value >= b.value ? a : b).type.label}.',
        ],
      ),
      RpgRulesBookSection(
        title: 'Dado adaptativo',
        points: [
          'Seu dado base é um D20.',
          'Ele não rola sempre de 1 a 20: hoje ele vai de ${dice.minimumRoll} até ${dice.maximumRoll}.',
          'Quanto melhor sua ficha no dia anterior, maior o piso do dado e menor a chance de resultado ruim.',
          'Vantagem temática atual: ${dice.advantageLabel}.',
          'Risco temático atual: ${dice.riskLabel}.',
        ],
      ),
      const RpgRulesBookSection(
        title: 'Leitura do dia',
        points: [
          'A ficha muda de um dia para o outro.',
          'Ela sempre tenta refletir o estado mais recente do personagem.',
          'Você pode usar os atributos e o dado em RPG de mesa normalmente, como uma ficha viva.',
        ],
      ),
    ];
  }
}
