import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/data/repositories/areas_storage_repository.dart';

class AreasBootstrapService {
  AreasBootstrapService({AreasStorageRepository? storage})
    : _storage = storage ?? AreasStorageRepository();

  final AreasStorageRepository _storage;

  Future<void> ensureBootstrappedFromOnboarding() async {
    final box = await _storage.open();
    if (box.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;
    final now = DateTime.now();

    String read(String key) => (prefs.getString('$uid:$key') ?? '').trim();

    Future<void> seedScore(
      String areaId,
      String itemId,
      int? score, {
      String? reason,
      AreaDataSource source = AreaDataSource.onboarding,
    }) async {
      if (score == null) return;
      final safeScore = score.clamp(0, 100);
      await box.put(
        _storage.itemKey(areaId, itemId),
        AreaAssessment(
          status: _statusFromScore(safeScore),
          score: safeScore,
          reason: reason,
          source: source,
          lastUpdatedAt: now,
        ).toMap(),
      );
      await prefs.setString(
        _storage.areaUpdatedPrefKey(uid, areaId),
        now.toIso8601String(),
      );
    }

    final focus = read('focus');
    final childrenCount = _childrenCount(read('children_count'));
    final dependentsFinancial = _dependentsCount(read('dependents_financial'));
    final homeLoad = read('home_routine_load');
    final studyWork = read('study_work');
    final workSchedule = read('work_schedule_format');
    final romanticRelationship = read('romantic_relationship');

    var responsibilityLoad = 0;
    if (childrenCount >= 1) responsibilityLoad += 1;
    if (childrenCount >= 2) responsibilityLoad += 1;
    if (dependentsFinancial >= 1) responsibilityLoad += 1;
    if (studyWork == 'Trabalho e estudos') responsibilityLoad += 1;
    if (homeLoad == 'Corrida' ||
        homeLoad == 'Muito puxada' ||
        homeLoad == 'Instável') {
      responsibilityLoad += 1;
    }
    if (workSchedule == 'Turnos' ||
        workSchedule == 'Noturno' ||
        workSchedule == 'Rotina muito variável') {
      responsibilityLoad += 1;
    }

    final heavyContext = responsibilityLoad >= 3;

    int adaptToContext(int? score, {int floor = 55}) {
      if (score == null) return floor;
      if (!heavyContext) return score;
      return score < floor ? floor : score;
    }

    int addFocusBoost(int base, String areaId) {
      final boost = _focusBoostFor(focus, areaId);
      return (base + boost).clamp(0, 100);
    }

    final sleepScore = _mapOption(read('sleep_hours'), const {
      'Menos de 5h': 30,
      '5–6h': 48,
      '6–7h': 62,
      '7–8h': 84,
      '8h+': 82,
      'Varia muito': 52,
    });
    await seedScore(
      'body_health',
      'sleep',
      sleepScore == null ? null : addFocusBoost(sleepScore, 'body_health'),
      reason: 'Base inicial vinda do onboarding sobre sono médio atual.',
    );

    final movementScore = _mapOption(read('exercise_frequency'), const {
      'Nunca': 25,
      '1x por semana': 45,
      '2–3x por semana': 65,
      '4–5x por semana': 82,
      'Quase todo dia': 88,
      'Meu dia já é muito físico': 78,
    });
    await seedScore(
      'body_health',
      'movement',
      movementScore == null
          ? null
          : addFocusBoost(movementScore, 'body_health'),
      reason: 'Base inicial vinda do onboarding sobre atividade física atual.',
    );

    final checkupScore = _mapOption(read('last_checkup'), const {
      'Menos de 6 meses': 92,
      '6 a 12 meses': 72,
      '1 a 2 anos': 40,
      'Mais de 2 anos': 18,
      'Nunca fiz / não lembro': 28,
    });
    await seedScore(
      'body_health',
      'checkups',
      checkupScore,
      reason: 'Base inicial vinda do onboarding sobre o último check-up.',
    );

    final stressScore = _mapOption(read('stress_level'), const {
      'Muito baixo': 84,
      'Baixo': 72,
      'Médio': 55,
      'Alto': 32,
      'Muito alto': 15,
    });
    await seedScore(
      'mind_emotion',
      'stress',
      stressScore == null ? null : addFocusBoost(stressScore, 'mind_emotion'),
      reason: 'Base inicial vinda do onboarding sobre nível de estresse atual.',
    );

    final moodScore = _mapOption(read('emotional_state'), const {
      'Muito bem': 86,
      'Bem': 72,
      'Oscilando': 52,
      'Mal': 32,
      'Muito mal': 15,
    });
    await seedScore(
      'mind_emotion',
      'mood',
      moodScore == null ? null : addFocusBoost(moodScore, 'mind_emotion'),
      reason: 'Base inicial vinda do onboarding sobre estado emocional atual.',
    );

    final mentalLoadScore = _mapOption(read('mental_load'), const {
      'Leve': 82,
      'Equilibrado(a)': 68,
      'Cansado(a)': 48,
      'Sobrecarregado(a)': 30,
      'Esgotado(a)': 12,
    });
    await seedScore(
      'mind_emotion',
      'mental_load',
      mentalLoadScore == null
          ? null
          : addFocusBoost(mentalLoadScore, 'mind_emotion'),
      reason: 'Base inicial vinda do onboarding sobre carga mental atual.',
    );

    final financialSituationScore =
        _mapOption(read('financial_situation'), const {
          'Muito organizada': 82,
          'Organizada': 68,
          'Mais ou menos': 50,
          'Desorganizada': 30,
          'Muito difícil': 15,
        });
    await seedScore(
      'finance_material',
      'budget',
      financialSituationScore == null
          ? null
          : addFocusBoost(financialSituationScore, 'finance_material'),
      reason:
          'Base inicial vinda do onboarding sobre organização financeira atual.',
    );

    final trackingScore = _mapOption(read('expense_tracking'), const {
      'Sim, tudo': 84,
      'Sim, a maior parte': 72,
      'Só às vezes': 52,
      'Quase nunca': 28,
      'Nunca': 15,
    });
    await seedScore(
      'finance_material',
      'spending',
      trackingScore == null
          ? null
          : addFocusBoost(trackingScore, 'finance_material'),
      reason:
          'Base inicial vinda do onboarding sobre acompanhamento de gastos.',
    );

    final routineScore = _mapOption(read('personal_organization'), const {
      'Muito boa': 84,
      'Boa': 70,
      'Média': 54,
      'Ruim': 34,
      'Muito ruim': 18,
    });
    await seedScore(
      'work_vocation',
      'routine',
      routineScore == null
          ? null
          : addFocusBoost(
              adaptToContext(routineScore, floor: 58),
              'work_vocation',
            ),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual de responsabilidades da rotina.'
          : 'Base inicial vinda do onboarding sobre organização pessoal.',
    );

    final balanceBase = _average([
      _mapOption(read('life_demands_capacity'), const {
        'Sim, com folga': 86,
        'Sim, razoavelmente': 68,
        'Mais ou menos': 50,
        'Quase não': 28,
        'Não': 12,
      }),
      _mapOption(read('work_schedule_format'), const {
        'Horário fixo diurno': 72,
        'Turnos': 42,
        'Noturno': 38,
        'Horário flexível': 68,
        'Rotina muito variável': 34,
        'Não se aplica': 60,
      }),
    ]);
    await seedScore(
      'work_vocation',
      'balance',
      balanceBase == null
          ? null
          : addFocusBoost(
              adaptToContext(balanceBase, floor: 56),
              'work_vocation',
            ),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual de carga e responsabilidades.'
          : 'Base inicial vinda do onboarding sobre a sensação de dar conta da rotina.',
    );

    final consistencyScore = _mapOption(read('routine_predictability'), const {
      'Muito previsível': 82,
      'Relativamente organizada': 68,
      'Um pouco bagunçada': 48,
      'Bem corrida': 42,
      'Totalmente imprevisível': 26,
    });
    await seedScore(
      'work_vocation',
      'consistency',
      consistencyScore == null
          ? null
          : addFocusBoost(
              adaptToContext(consistencyScore, floor: 56),
              'work_vocation',
            ),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual da rotina.'
          : 'Base inicial vinda do onboarding sobre previsibilidade da rotina.',
    );

    final studyBase =
        studyWork == 'Estudos' || studyWork == 'Trabalho e estudos'
        ? 68
        : (read('goal') == 'Evoluir no trabalho/estudos' ? 60 : null);
    await seedScore(
      'learning_intellect',
      'study',
      studyBase,
      reason:
          'Base inicial vinda do onboarding sobre presença atual de estudo e desenvolvimento.',
    );

    final familyScore = _mapOption(read('family_relationship'), const {
      'Muito boa': 84,
      'Boa': 72,
      'Mais ou menos': 52,
      'Difícil': 30,
      'Muito difícil': 15,
    });
    await seedScore(
      'relations_community',
      'family',
      familyScore == null ? null : adaptToContext(familyScore, floor: 55),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual da vida familiar.'
          : 'Base inicial vinda do onboarding sobre relação com a família.',
    );

    final socialContactBase = _average([
      _mapOption(read('social_life'), const {
        'Muito boa': 82,
        'Boa': 68,
        'Média': 52,
        'Fraca': 32,
        'Muito fraca': 18,
      }),
      _mapOption(read('emotional_support'), const {
        'Sim, bastante': 82,
        'Sim, um pouco': 64,
        'Quase não': 35,
        'Não': 18,
      }),
      _mapOption(read('loneliness'), const {
        'Bem acompanhado(a)': 82,
        'Às vezes acompanhado(a)': 64,
        'Mais sozinho(a) do que gostaria': 36,
        'Muito sozinho(a)': 18,
      }),
    ]);
    await seedScore(
      'relations_community',
      'social_contact',
      socialContactBase == null
          ? null
          : adaptToContext(socialContactBase, floor: 55),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual de responsabilidades e apoio.'
          : 'Base inicial vinda do onboarding sobre apoio e vida social.',
    );

    final friendshipScore = _mapOption(read('friendship_connection'), const {
      'Muito boa': 82,
      'Boa': 68,
      'Média': 52,
      'Fraca': 32,
      'Quase inexistente': 18,
    });
    await seedScore(
      'relations_community',
      'friends',
      friendshipScore == null
          ? null
          : adaptToContext(friendshipScore, floor: 55),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual da vida social.'
          : 'Base inicial vinda do onboarding sobre conexão com amigos.',
    );

    if (romanticRelationship.isNotEmpty &&
        romanticRelationship != 'Não tenho' &&
        romanticRelationship != 'Prefiro não responder') {
      final partnerScore = _mapOption(romanticRelationship, const {
        'Está bem': 78,
        'Está mais ou menos': 52,
        'Está difícil': 24,
      });
      await seedScore(
        'relations_community',
        'partner',
        partnerScore == null ? null : adaptToContext(partnerScore, floor: 55),
        reason: heavyContext
            ? 'Base inicial ajustada ao contexto atual do relacionamento.'
            : 'Base inicial vinda do onboarding sobre relacionamento amoroso.',
      );
    }

    final homeOrganizationScore = _mapOption(read('home_organization'), const {
      'Muito boa': 84,
      'Boa': 70,
      'Média': 54,
      'Ruim': 34,
      'Muito ruim': 18,
      'Não se aplica': 60,
    });
    await seedScore(
      'environment_home',
      'organization',
      homeOrganizationScore == null
          ? null
          : addFocusBoost(
              adaptToContext(homeOrganizationScore, floor: 58),
              'environment_home',
            ),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual da casa e responsabilidades.'
          : 'Base inicial vinda do onboarding sobre organização da casa.',
    );
    await seedScore(
      'environment_home',
      'cleaning',
      homeOrganizationScore == null
          ? null
          : addFocusBoost(
              adaptToContext(homeOrganizationScore, floor: 58),
              'environment_home',
            ),
      reason: heavyContext
          ? 'Base inicial ajustada ao contexto atual da casa e responsabilidades.'
          : 'Base inicial vinda do onboarding sobre cuidado com o ambiente.',
    );

    final screenTimeBase = _mapOption(read('screen_time'), const {
      'Menos de 2h': 84,
      '2–4h': 72,
      '4–6h': 54,
      '6–8h': 36,
      '8h+': 20,
    });
    final phonePurposeBoost =
        _mapOption(read('phone_usage_purpose'), const {
          'Mais para trabalho/estudo': 8,
          'Mais para comunicação': 4,
          'Misturado': 0,
          'Mais para redes/entretenimento': -8,
          'Quase não uso': 10,
        }) ??
        0;
    if (screenTimeBase != null) {
      await seedScore(
        'digital_tech',
        'distraction',
        addFocusBoost(
          (screenTimeBase + phonePurposeBoost).clamp(0, 100),
          'digital_tech',
        ),
        reason:
            'Base inicial vinda do onboarding sobre tempo e tipo de uso do celular.',
      );
    }

    final directionBase = _average([
      focus.isEmpty ? null : 72,
      _mapOption(read('start_preference'), const {
        'Pequenos passos': 72,
        'Resultados rápidos': 62,
        'Entender minha realidade primeiro': 74,
        'Plano mais completo': 70,
        'Tanto faz': 56,
      }),
      _mapOption(read('app_help'), const {
        'Entender minha vida melhor': 74,
        'Ter mais clareza': 72,
        'Criar rotina': 70,
        'Melhorar hábitos': 70,
        'Organizar finanças': 68,
        'Cuidar da saúde': 68,
        'Sair do caos': 66,
        'Outro': 60,
      }),
    ]);
    await seedScore(
      'purpose_values',
      'direction',
      directionBase,
      reason: 'Base inicial vinda do onboarding sobre foco e direção desejada.',
    );

    final goalsReviewBase = _mapOption(read('consistency'), const {
      'Sim, muito': 82,
      'Sim, razoavelmente': 68,
      'Mais ou menos': 52,
      'Pouco': 32,
      'Não': 18,
    });
    await seedScore(
      'purpose_values',
      'goals_review',
      goalsReviewBase,
      reason:
          'Base inicial vinda do onboarding sobre constância percebida hoje.',
    );
  }

  int? _mapOption(String raw, Map<String, int> map) {
    if (raw.isEmpty) return null;
    return map[raw];
  }

  int? _average(List<int?> values) {
    final valid = values.whereType<int>().toList(growable: false);
    if (valid.isEmpty) return null;
    final sum = valid.reduce((a, b) => a + b);
    return (sum / valid.length).round();
  }

  int _childrenCount(String raw) {
    switch (raw) {
      case 'Sim, 1':
        return 1;
      case 'Sim, 2':
        return 2;
      case 'Sim, 3 ou mais':
        return 3;
      default:
        return 0;
    }
  }

  int _dependentsCount(String raw) {
    switch (raw) {
      case 'Sim, 1 pessoa':
        return 1;
      case 'Sim, 2 pessoas':
        return 2;
      case 'Sim, 3 ou mais':
        return 3;
      default:
        return 0;
    }
  }

  int _focusBoostFor(String focus, String areaId) {
    switch (focus) {
      case 'Corpo & saúde':
        return areaId == 'body_health' ? 8 : 0;
      case 'Mental & emocional':
        return areaId == 'mind_emotion' ? 8 : 0;
      case 'Finanças':
        return areaId == 'finance_material' ? 8 : 0;
      case 'Trabalho/estudos':
        return areaId == 'work_vocation' || areaId == 'learning_intellect'
            ? 8
            : 0;
      case 'Família':
      case 'Relacionamentos':
        return areaId == 'relations_community' ? 8 : 0;
      case 'Casa e organização':
        return areaId == 'environment_home' ? 8 : 0;
      case 'Hábitos e constância':
        return areaId == 'work_vocation' || areaId == 'purpose_values' ? 8 : 0;
      default:
        return 0;
    }
  }

  AreaStatus _statusFromScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}
