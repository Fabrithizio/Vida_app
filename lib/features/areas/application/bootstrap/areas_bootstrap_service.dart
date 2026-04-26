// ============================================================================
// FILE: lib/features/areas/application/bootstrap/areas_bootstrap_service.dart
//
// O que faz:
// - Cria o primeiro estado do Areas a partir do onboarding
// - Limpa a dependência de ids antigos que não fazem mais parte do sistema novo
// - Gera um ponto de partida coerente até os dados reais do app assumirem
// ============================================================================

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
      required String reason,
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

    final stress = read('stress_level');
    final emotional = read('emotional_state');
    final mentalLoad = read('mental_load');
    final support = read('emotional_support');
    final loneliness = read('loneliness');
    final socialLife = read('social_life');
    final family = read('family_relationship');
    final consistency = read('consistency');
    final predictability = read('routine_predictability');
    final focus = read('focus');
    final goal = read('goal');
    final help = read('app_help');
    final studyWork = read('study_work');
    final organization = read('personal_organization');
    final homeLoad = read('home_routine_load');
    final financial = read('financial_situation');

    await seedScore(
      'mind_emotion',
      'mood',
      _mapOption(emotional, const {
        'Muito bem': 88,
        'Bem': 74,
        'Oscilando': 52,
        'Mal': 28,
        'Muito mal': 14,
      }),
      reason: 'Base inicial vinda do onboarding sobre estado emocional.',
    );

    await seedScore(
      'mind_emotion',
      'stress',
      _mapOption(stress, const {
        'Muito baixo': 86,
        'Baixo': 72,
        'Médio': 56,
        'Alto': 32,
        'Muito alto': 14,
      }),
      reason: 'Base inicial vinda do onboarding sobre estresse atual.',
    );

    await seedScore(
      'mind_emotion',
      'mental_load',
      _mapOption(mentalLoad, const {
        'Leve': 84,
        'Equilibrado(a)': 70,
        'Cansado(a)': 48,
        'Sobrecarregado(a)': 28,
        'Esgotado(a)': 10,
      }),
      reason: 'Base inicial vinda do onboarding sobre carga mental.',
    );

    await seedScore(
      'mind_emotion',
      'focus',
      _average([
        _mapOption(organization, const {
          'Muito boa': 84,
          'Boa': 70,
          'Média': 52,
          'Ruim': 32,
          'Muito ruim': 16,
        }),
        _mapOption(predictability, const {
          'Muito previsível': 82,
          'Relativamente organizada': 68,
          'Um pouco bagunçada': 48,
          'Bem corrida': 36,
          'Totalmente imprevisível': 20,
        }),
      ]),
      reason: 'Base inicial vinda da organização e previsibilidade da rotina.',
    );

    await seedScore(
      'work_vocation',
      'routine',
      _average([
        _mapOption(organization, const {
          'Muito boa': 86,
          'Boa': 72,
          'Média': 54,
          'Ruim': 34,
          'Muito ruim': 18,
        }),
        _mapOption(predictability, const {
          'Muito previsível': 84,
          'Relativamente organizada': 68,
          'Um pouco bagunçada': 46,
          'Bem corrida': 38,
          'Totalmente imprevisível': 22,
        }),
      ]),
      reason: 'Base inicial vinda da organização pessoal e da rotina.',
    );

    await seedScore(
      'work_vocation',
      'consistency',
      _mapOption(consistency, const {
        'Sim, muito': 84,
        'Sim, razoavelmente': 70,
        'Mais ou menos': 52,
        'Pouco': 32,
        'Não': 18,
      }),
      reason: 'Base inicial vinda do onboarding sobre constância.',
    );

    await seedScore(
      'work_vocation',
      'balance',
      _average([
        _mapOption(homeLoad, const {
          'Leve': 78,
          'Equilibrada': 66,
          'Corrida': 46,
          'Muito puxada': 28,
          'Instável': 34,
        }),
        _mapOption(financial, const {
          'Muito organizada': 78,
          'Organizada': 68,
          'Mais ou menos': 52,
          'Desorganizada': 34,
          'Muito difícil': 18,
        }),
      ]),
      reason: 'Base inicial vinda da carga da rotina e da pressão geral.',
    );

    await seedScore(
      'learning_intellect',
      'planning',
      _average([
        _mapOption(focus, const {
          'Corpo & saúde': 56,
          'Mental & emocional': 60,
          'Finanças': 64,
          'Trabalho/estudos': 82,
          'Família': 60,
          'Relacionamentos': 58,
          'Casa e organização': 66,
          'Hábitos e constância': 74,
        }),
        _mapOption(help, const {
          'Entender minha vida melhor': 68,
          'Ter mais clareza': 74,
          'Criar rotina': 72,
          'Melhorar hábitos': 70,
          'Organizar finanças': 64,
          'Cuidar da saúde': 62,
          'Sair do caos': 70,
          'Outro': 58,
        }),
      ]),
      reason: 'Base inicial vinda do foco principal e do que o usuário busca.',
    );

    await seedScore(
      'learning_intellect',
      'execution',
      _mapOption(consistency, const {
        'Sim, muito': 82,
        'Sim, razoavelmente': 68,
        'Mais ou menos': 52,
        'Pouco': 30,
        'Não': 16,
      }),
      reason: 'Base inicial vinda da constância declarada no onboarding.',
    );

    await seedScore(
      'learning_intellect',
      'progress',
      _average([
        _mapOption(goal, const {
          'Cuidar melhor da minha saúde': 62,
          'Melhorar meu emocional': 62,
          'Organizar minhas finanças': 66,
          'Evoluir no trabalho/estudos': 82,
          'Melhorar minha rotina': 72,
          'Cuidar mais da casa': 60,
          'Melhorar relações': 60,
          'Retomar o controle da vida': 74,
        }),
        _mapOption(studyWork, const {
          'Só trabalho': 64,
          'Só estudo': 72,
          'Trabalho e estudos': 76,
          'Casa e família': 56,
          'Estou sem rotina fixa': 48,
        }),
      ]),
      reason:
          'Base inicial vinda do objetivo principal e da rotina-base atual.',
    );

    await seedScore(
      'relations_community',
      'family',
      _mapOption(family, const {
        'Muito boa': 86,
        'Boa': 72,
        'Mais ou menos': 52,
        'Difícil': 28,
        'Muito difícil': 14,
      }),
      reason: 'Base inicial vinda do onboarding sobre relação com a família.',
    );

    await seedScore(
      'relations_community',
      'social_contact',
      _average([
        _mapOption(support, const {
          'Sim, bastante': 82,
          'Sim, um pouco': 64,
          'Quase não': 34,
          'Não': 18,
        }),
        _mapOption(loneliness, const {
          'Bem acompanhado(a)': 84,
          'Às vezes acompanhado(a)': 66,
          'Mais sozinho(a) do que gostaria': 34,
          'Muito sozinho(a)': 18,
        }),
        _mapOption(socialLife, const {
          'Muito boa': 82,
          'Boa': 68,
          'Média': 52,
          'Fraca': 32,
          'Muito fraca': 18,
        }),
      ]),
      reason: 'Base inicial vinda de apoio, solidão e vida social percebida.',
    );

    await seedScore(
      'purpose_values',
      'direction',
      _average([
        _mapOption(focus, const {
          'Corpo & saúde': 72,
          'Mental & emocional': 72,
          'Finanças': 74,
          'Trabalho/estudos': 76,
          'Família': 70,
          'Relacionamentos': 70,
          'Casa e organização': 72,
          'Hábitos e constância': 78,
        }),
        _mapOption(help, const {
          'Entender minha vida melhor': 74,
          'Ter mais clareza': 76,
          'Criar rotina': 78,
          'Melhorar hábitos': 76,
          'Organizar finanças': 72,
          'Cuidar da saúde': 72,
          'Sair do caos': 74,
          'Outro': 60,
        }),
      ]),
      reason: 'Base inicial vinda do foco e da intenção principal no app.',
    );

    await seedScore(
      'purpose_values',
      'goals_review',
      _mapOption(consistency, const {
        'Sim, muito': 82,
        'Sim, razoavelmente': 68,
        'Mais ou menos': 52,
        'Pouco': 30,
        'Não': 16,
      }),
      reason: 'Base inicial vinda da constância declarada.',
    );

    await seedScore(
      'purpose_values',
      'gratitude',
      _mapOption(support, const {
        'Sim, bastante': 78,
        'Sim, um pouco': 64,
        'Quase não': 40,
        'Não': 24,
      }),
      reason: 'Base inicial suave vinda da percepção de apoio atual.',
    );

    await seedScore(
      'purpose_values',
      'self_control',
      _average([
        _mapOption(consistency, const {
          'Sim, muito': 82,
          'Sim, razoavelmente': 68,
          'Mais ou menos': 50,
          'Pouco': 30,
          'Não': 16,
        }),
        _mapOption(organization, const {
          'Muito boa': 80,
          'Boa': 68,
          'Média': 52,
          'Ruim': 32,
          'Muito ruim': 16,
        }),
      ]),
      reason: 'Base inicial vinda da constância e da organização pessoal.',
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

  AreaStatus _statusFromScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }
}
