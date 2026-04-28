// ============================================================================
// FILE: lib/features/areas/application/profile/areas_rpg_profile_models.dart
//
// O que faz:
// - Define os modelos da ficha RPG do usuário
// - Centraliza classes, atributos, dado adaptativo e livro de regras
// - Agora também suporta serialização para histórico diário
// ============================================================================

import 'package:flutter/material.dart';

enum RpgArchetype { warrior, mage, ranger, rogue, cleric, paladin }

extension RpgArchetypeUi on RpgArchetype {
  String get label {
    switch (this) {
      case RpgArchetype.warrior:
        return 'Guerreiro';
      case RpgArchetype.mage:
        return 'Mago';
      case RpgArchetype.ranger:
        return 'Arqueiro';
      case RpgArchetype.rogue:
        return 'Ladino';
      case RpgArchetype.cleric:
        return 'Clérigo';
      case RpgArchetype.paladin:
        return 'Paladino';
    }
  }

  String get fantasySummary {
    switch (this) {
      case RpgArchetype.warrior:
        return 'Linha de frente, firmeza e poder físico.';
      case RpgArchetype.mage:
        return 'Conhecimento, leitura de cenário e poder mental.';
      case RpgArchetype.ranger:
        return 'Precisão, adaptação e leitura do ambiente.';
      case RpgArchetype.rogue:
        return 'Velocidade, astúcia e execução eficiente.';
      case RpgArchetype.cleric:
        return 'Suporte, equilíbrio e recuperação.';
      case RpgArchetype.paladin:
        return 'Disciplina, proteção e força guiada.';
    }
  }

  IconData get icon {
    switch (this) {
      case RpgArchetype.warrior:
        return Icons.gavel_rounded;
      case RpgArchetype.mage:
        return Icons.auto_fix_high_rounded;
      case RpgArchetype.ranger:
        return Icons.ads_click_rounded;
      case RpgArchetype.rogue:
        return Icons.bolt_rounded;
      case RpgArchetype.cleric:
        return Icons.healing_rounded;
      case RpgArchetype.paladin:
        return Icons.shield_rounded;
    }
  }

  List<String> get strengths {
    switch (this) {
      case RpgArchetype.warrior:
        return ['Força', 'Vitalidade'];
      case RpgArchetype.mage:
        return ['Inteligência', 'Sabedoria'];
      case RpgArchetype.ranger:
        return ['Destreza', 'Percepção'];
      case RpgArchetype.rogue:
        return ['Destreza', 'Carisma'];
      case RpgArchetype.cleric:
        return ['Sabedoria', 'Vitalidade'];
      case RpgArchetype.paladin:
        return ['Força', 'Disciplina'];
    }
  }

  static RpgArchetype fromName(String raw) {
    return RpgArchetype.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => RpgArchetype.warrior,
    );
  }
}

enum RpgAttributeType {
  strength,
  dexterity,
  vitality,
  intelligence,
  wisdom,
  charisma,
  discipline,
  luck,
}

extension RpgAttributeTypeUi on RpgAttributeType {
  String get label {
    switch (this) {
      case RpgAttributeType.strength:
        return 'Força';
      case RpgAttributeType.dexterity:
        return 'Destreza';
      case RpgAttributeType.vitality:
        return 'Vitalidade';
      case RpgAttributeType.intelligence:
        return 'Inteligência';
      case RpgAttributeType.wisdom:
        return 'Sabedoria';
      case RpgAttributeType.charisma:
        return 'Carisma';
      case RpgAttributeType.discipline:
        return 'Disciplina';
      case RpgAttributeType.luck:
        return 'Sorte';
    }
  }

  IconData get icon {
    switch (this) {
      case RpgAttributeType.strength:
        return Icons.fitness_center_rounded;
      case RpgAttributeType.dexterity:
        return Icons.flash_on_rounded;
      case RpgAttributeType.vitality:
        return Icons.favorite_rounded;
      case RpgAttributeType.intelligence:
        return Icons.psychology_rounded;
      case RpgAttributeType.wisdom:
        return Icons.menu_book_rounded;
      case RpgAttributeType.charisma:
        return Icons.record_voice_over_rounded;
      case RpgAttributeType.discipline:
        return Icons.task_alt_rounded;
      case RpgAttributeType.luck:
        return Icons.casino_rounded;
    }
  }

  Color get accent {
    switch (this) {
      case RpgAttributeType.strength:
        return const Color(0xFFEF4444);
      case RpgAttributeType.dexterity:
        return const Color(0xFFF59E0B);
      case RpgAttributeType.vitality:
        return const Color(0xFF22C55E);
      case RpgAttributeType.intelligence:
        return const Color(0xFF8B5CF6);
      case RpgAttributeType.wisdom:
        return const Color(0xFF0EA5E9);
      case RpgAttributeType.charisma:
        return const Color(0xFFEC4899);
      case RpgAttributeType.discipline:
        return const Color(0xFF14B8A6);
      case RpgAttributeType.luck:
        return const Color(0xFFEAB308);
    }
  }

  static RpgAttributeType fromName(String raw) {
    return RpgAttributeType.values.firstWhere(
      (item) => item.name == raw,
      orElse: () => RpgAttributeType.strength,
    );
  }
}

class RpgAttributeScore {
  const RpgAttributeScore({
    required this.type,
    required this.value,
    required this.tierLabel,
    required this.reason,
  });

  final RpgAttributeType type;
  final int value;
  final String tierLabel;
  final String reason;

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'value': value,
    'tierLabel': tierLabel,
    'reason': reason,
  };

  static RpgAttributeScore fromMap(Map<String, dynamic> map) {
    return RpgAttributeScore(
      type: RpgAttributeTypeUi.fromName(map['type'] as String? ?? ''),
      value: (map['value'] as num?)?.toInt() ?? 0,
      tierLabel: map['tierLabel'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
    );
  }
}

class RpgDiceProfile {
  const RpgDiceProfile({
    required this.title,
    required this.diceSides,
    required this.minimumRoll,
    required this.maximumRoll,
    required this.advantageLabel,
    required this.riskLabel,
    required this.reason,
  });

  final String title;
  final int diceSides;
  final int minimumRoll;
  final int maximumRoll;
  final String advantageLabel;
  final String riskLabel;
  final String reason;

  int sanitizeRoll(int raw) {
    if (raw < minimumRoll) return minimumRoll;
    if (raw > maximumRoll) return maximumRoll;
    return raw;
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'diceSides': diceSides,
    'minimumRoll': minimumRoll,
    'maximumRoll': maximumRoll,
    'advantageLabel': advantageLabel,
    'riskLabel': riskLabel,
    'reason': reason,
  };

  static RpgDiceProfile fromMap(Map<String, dynamic> map) {
    return RpgDiceProfile(
      title: map['title'] as String? ?? 'D20',
      diceSides: (map['diceSides'] as num?)?.toInt() ?? 20,
      minimumRoll: (map['minimumRoll'] as num?)?.toInt() ?? 1,
      maximumRoll: (map['maximumRoll'] as num?)?.toInt() ?? 20,
      advantageLabel: map['advantageLabel'] as String? ?? '',
      riskLabel: map['riskLabel'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
    );
  }
}

class RpgRulesBookSection {
  const RpgRulesBookSection({required this.title, required this.points});

  final String title;
  final List<String> points;
}

class AreasRpgProfileSnapshot {
  const AreasRpgProfileSnapshot({
    required this.userName,
    required this.classificationLabel,
    required this.archetype,
    required this.rankLabel,
    required this.attributes,
    required this.dice,
    required this.totalPower,
    required this.rules,
    required this.updatedAt,
  });

  final String userName;
  final String classificationLabel;
  final RpgArchetype archetype;
  final String rankLabel;
  final List<RpgAttributeScore> attributes;
  final RpgDiceProfile dice;
  final int totalPower;
  final List<RpgRulesBookSection> rules;
  final DateTime updatedAt;

  RpgAttributeScore attributeOf(RpgAttributeType type) {
    return attributes.firstWhere((e) => e.type == type);
  }

  Map<String, dynamic> toHistoryMap() => {
    'userName': userName,
    'classificationLabel': classificationLabel,
    'archetype': archetype.name,
    'rankLabel': rankLabel,
    'attributes': attributes.map((e) => e.toMap()).toList(growable: false),
    'dice': dice.toMap(),
    'totalPower': totalPower,
    'updatedAt': updatedAt.toIso8601String(),
  };

  static AreasRpgProfileSnapshot fromHistoryMap(
    Map<String, dynamic> map, {
    List<RpgRulesBookSection> rules = const <RpgRulesBookSection>[],
  }) {
    final rawAttributes =
        (map['attributes'] as List?)?.cast<Map>() ?? const <Map>[];

    return AreasRpgProfileSnapshot(
      userName: map['userName'] as String? ?? 'Usuário',
      classificationLabel: map['classificationLabel'] as String? ?? '',
      archetype: RpgArchetypeUi.fromName(map['archetype'] as String? ?? ''),
      rankLabel: map['rankLabel'] as String? ?? 'Iniciante',
      attributes: rawAttributes
          .map((e) => RpgAttributeScore.fromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      dice: RpgDiceProfile.fromMap(
        Map<String, dynamic>.from((map['dice'] as Map?) ?? const {}),
      ),
      totalPower: (map['totalPower'] as num?)?.toInt() ?? 0,
      rules: rules,
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
