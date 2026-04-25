// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Define o pool adaptativo de perguntas do check-in diário
// - Lê o perfil-base vindo do onboarding
// - Cria um perfil vivo com nome, tags e prioridades
// - Escolhe 5 perguntas por dia com base no perfil + histórico recente
// - Permite que uma resposta afete várias áreas/subáreas com pesos diferentes
// - Salva respostas graduais por usuário no Hive
//
// Nesta revisão:
// - remove perguntas diretas de Saúde, Finanças, Ambiente e Digital como fonte
//   principal do check-in
// - foca o check-in em Mente, Trabalho, Projetos, Relações e Hábitos
// - prepara o sistema para perfis dinâmicos e mudança de perfil ao longo do uso
// ============================================================================

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DailyQuestionScaleType { quality5, amount5, agreement5 }

enum DailyQuestionCadence { daily, every3Days, weekly, biweekly }

class DailyQuestionImpact {
  const DailyQuestionImpact({
    required this.areaId,
    required this.itemId,
    required this.weight,
  });

  final String areaId;
  final String itemId;
  final double weight;
}

class DailyQuestion {
  const DailyQuestion({
    required this.id,
    required this.areaId,
    required this.areaLabel,
    required this.impacts,
    required this.text,
    required this.scaleType,
    required this.cadence,
    this.priorityBoost = 0,
    this.reverseScore = false,
    this.alwaysInclude = false,
    this.audienceTags = const [],
    this.blockedTags = const [],
  });

  final String id;
  final String areaId;
  final String areaLabel;
  final List<DailyQuestionImpact> impacts;
  final String text;
  final DailyQuestionScaleType scaleType;
  final DailyQuestionCadence cadence;
  final double priorityBoost;
  final bool reverseScore;
  final bool alwaysInclude;
  final List<String> audienceTags;
  final List<String> blockedTags;

  List<String> get itemIds =>
      impacts.map((impact) => impact.itemId).toSet().toList(growable: false);

  double impactWeightFor(String areaId, String itemId) {
    for (final impact in impacts) {
      if (impact.areaId == areaId && impact.itemId == itemId) {
        return impact.weight;
      }
    }
    return 0;
  }

  bool affects(String areaId, String itemId) {
    return impacts.any(
      (impact) => impact.areaId == areaId && impact.itemId == itemId,
    );
  }
}

class DailyAnswerOption {
  const DailyAnswerOption({
    required this.value,
    required this.label,
    required this.shortLabel,
    this.description,
  });

  final int value;
  final String label;
  final String shortLabel;
  final String? description;
}

class DailyCheckinSummary {
  const DailyCheckinSummary({
    required this.total,
    required this.answered,
    required this.isCompleted,
  });

  final int total;
  final int answered;
  final bool isCompleted;

  int get remaining => total - answered;

  double get progress {
    if (total == 0) return 0;
    return answered / total;
  }
}

class DailyProfileSnapshot {
  const DailyProfileSnapshot({
    required this.id,
    required this.label,
    required this.reason,
    required this.tags,
    required this.primaryAreaIds,
  });

  final String id;
  final String label;
  final String reason;
  final Set<String> tags;
  final Set<String> primaryAreaIds;
}

class DailyCheckinService {
  static const String _boxPrefix = 'daily_checkin_box_';
  static const int questionsPerDay = 5;
  static const int historyDays = 21;
  static const int minAnswerValue = 0;
  static const int maxAnswerValue = 4;

  static const List<DailyQuestion> _pool = [
    DailyQuestion(
      id: 'mood_balance',
      areaId: 'mind_emotion',
      areaLabel: 'Mente & emoções',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.30,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.18,
        ),
      ],
      text: 'Como ficou seu humor ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.42,
      audienceTags: ['stress_high', 'support_low', 'chaotic', 'transition'],
    ),
    DailyQuestion(
      id: 'mental_pressure',
      areaId: 'mind_emotion',
      areaLabel: 'Mente & emoções',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.78,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.35,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'gratitude',
          weight: 0.18,
        ),
      ],
      text: 'O peso mental do dia ontem ficou como?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.48,
      reverseScore: true,
      audienceTags: [
        'stress_high',
        'worker',
        'student',
        'caregiver',
        'financial_pressure',
      ],
    ),
    DailyQuestion(
      id: 'mental_clarity',
      areaId: 'mind_emotion',
      areaLabel: 'Mente & emoções',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 0.30,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'planning',
          weight: 0.20,
        ),
      ],
      text: 'Sua cabeça esteve clara para o que importava ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.38,
      audienceTags: ['worker', 'student', 'growth_focus', 'chaotic'],
    ),
    DailyQuestion(
      id: 'recovery_after_hit',
      areaId: 'mind_emotion',
      areaLabel: 'Mente & emoções',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.42,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'gratitude',
          weight: 0.65,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'self_control',
          weight: 0.28,
        ),
      ],
      text: 'Quando algo saiu do eixo ontem, você conseguiu voltar?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
      audienceTags: ['stress_high', 'chaotic', 'transition', 'low_constancy'],
    ),
    DailyQuestion(
      id: 'routine_control',
      areaId: 'work_vocation',
      areaLabel: 'Trabalho & vocação',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.52,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'direction',
          weight: 0.32,
        ),
      ],
      text: 'Você sentiu sua rotina sob controle ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.42,
      audienceTags: ['worker', 'student', 'chaotic', 'routine_focus'],
    ),
    DailyQuestion(
      id: 'essentials_done',
      areaId: 'work_vocation',
      areaLabel: 'Trabalho & vocação',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.75,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.25,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'direction',
          weight: 0.25,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'execution',
          weight: 0.18,
        ),
      ],
      text: 'Você conseguiu fazer o essencial ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.44,
      audienceTags: ['worker', 'student', 'caregiver', 'routine_focus'],
    ),
    DailyQuestion(
      id: 'pressure_vs_balance',
      areaId: 'work_vocation',
      areaLabel: 'Trabalho & vocação',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 0.25,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.25,
        ),
      ],
      text: 'Seu dia de trabalho/estudo ficou mais equilibrado ou mais pesado?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.24,
      audienceTags: ['worker', 'student', 'stress_high', 'financial_pressure'],
    ),
    DailyQuestion(
      id: 'planning_strength',
      areaId: 'learning_intellect',
      areaLabel: 'Projetos & progresso',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'planning',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 0.20,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'direction',
          weight: 0.24,
        ),
      ],
      text: 'Você teve clareza do próximo passo ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
      audienceTags: ['growth_focus', 'project_focus', 'student', 'worker'],
    ),
    DailyQuestion(
      id: 'execution_push',
      areaId: 'learning_intellect',
      areaLabel: 'Projetos & progresso',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'execution',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'progress',
          weight: 0.42,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.20,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'goals_review',
          weight: 0.25,
        ),
      ],
      text: 'Você conseguiu sair do plano e executar algo importante ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.38,
      audienceTags: ['growth_focus', 'project_focus', 'student', 'worker'],
    ),
    DailyQuestion(
      id: 'progress_notice',
      areaId: 'learning_intellect',
      areaLabel: 'Projetos & progresso',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'progress',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'execution',
          weight: 0.40,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'goals_review',
          weight: 0.30,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.12,
        ),
      ],
      text: 'No fim do dia, você sentiu avanço real em algo que importa?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
      audienceTags: ['growth_focus', 'project_focus', 'low_constancy'],
    ),
    DailyQuestion(
      id: 'home_climate',
      areaId: 'relations_community',
      areaLabel: 'Relações & conexões',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'family',
          weight: 0.82,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.28,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.20,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.15,
        ),
      ],
      text: 'Como a convivência em casa bateu em você ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
      audienceTags: [
        'caregiver',
        'with_family',
        'with_partner',
        'with_children',
      ],
    ),
    DailyQuestion(
      id: 'felt_supported',
      areaId: 'relations_community',
      areaLabel: 'Relações & conexões',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'family',
          weight: 0.28,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'friends',
          weight: 0.28,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'partner',
          weight: 0.28,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.18,
        ),
      ],
      text: 'Você se sentiu apoiado(a) por alguém ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.22,
      audienceTags: ['support_low', 'social_fragile', 'solo'],
    ),
    DailyQuestion(
      id: 'social_presence',
      areaId: 'relations_community',
      areaLabel: 'Relações & conexões',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.78,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'friends',
          weight: 0.42,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'partner',
          weight: 0.42,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.10,
        ),
      ],
      text: 'Você deu presença real para alguém importante ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
      audienceTags: ['social_fragile', 'with_partner', 'with_family', 'solo'],
    ),
    DailyQuestion(
      id: 'kept_the_basic',
      areaId: 'purpose_values',
      areaLabel: 'Hábitos & constância',
      impacts: [
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'direction',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'goals_review',
          weight: 0.38,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 0.22,
        ),
      ],
      text: 'Você conseguiu manter o básico do seu dia ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.42,
      audienceTags: ['low_constancy', 'chaotic', 'routine_focus', 'transition'],
    ),
    DailyQuestion(
      id: 'self_control_day',
      areaId: 'purpose_values',
      areaLabel: 'Hábitos & constância',
      impacts: [
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'self_control',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.18,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 0.12,
        ),
      ],
      text: 'Você conseguiu manter seus limites ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.24,
      audienceTags: [
        'low_constancy',
        'chaotic',
        'digital_risk',
        'financial_pressure',
      ],
    ),
    DailyQuestion(
      id: 'slipped_off_axis',
      areaId: 'purpose_values',
      areaLabel: 'Hábitos & constância',
      impacts: [
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'self_control',
          weight: 0.75,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'goals_review',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 0.20,
        ),
      ],
      text: 'Você saiu do eixo mais do que queria ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
      reverseScore: true,
      audienceTags: ['low_constancy', 'chaotic', 'stress_high'],
    ),
    DailyQuestion(
      id: 'money_pressure_mind',
      areaId: 'mind_emotion',
      areaLabel: 'Mente & emoções',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 0.72,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.18,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'self_control',
          weight: 0.15,
        ),
      ],
      text: 'O dinheiro pesou na sua cabeça ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.20,
      reverseScore: true,
      audienceTags: ['financial_pressure'],
    ),
    DailyQuestion(
      id: 'distraction_pull',
      areaId: 'purpose_values',
      areaLabel: 'Hábitos & constância',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.28,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'self_control',
          weight: 0.72,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'execution',
          weight: 0.18,
        ),
      ],
      text: 'As distrações puxaram mais você do que deveriam ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
      reverseScore: true,
      audienceTags: ['digital_risk', 'worker', 'student', 'low_constancy'],
    ),
  ];

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> _open() {
    return Hive.openBox<dynamic>('$_boxPrefix${_uidOrAnon()}');
  }

  String _dayKey(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _answerKey(DateTime d, String questionId) {
    return '${_dayKey(d)}::$questionId';
  }

  String _completedKey(DateTime d) {
    return '${_dayKey(d)}::completed';
  }

  String _questionsCacheKey(DateTime d) {
    return '${_dayKey(d)}::questions';
  }

  String _profileCacheKey(DateTime d) {
    return '${_dayKey(d)}::profile_label';
  }

  List<DailyQuestion> get allQuestions => List.unmodifiable(_pool);

  DailyQuestion? questionById(String id) => _questionById(id);

  List<DailyQuestion> get alwaysIncludedQuestions =>
      _pool.where((q) => q.alwaysInclude).toList(growable: false);

  List<DailyQuestion> questionsForItem(String itemId) {
    return _pool
        .where((q) => q.impacts.any((i) => i.itemId == itemId))
        .toList(growable: false);
  }

  List<DailyQuestion> questionsForTarget(String areaId, String itemId) {
    return _pool
        .where((q) => q.affects(areaId, itemId))
        .toList(growable: false);
  }

  double impactWeightFor({
    required String questionId,
    required String areaId,
    required String itemId,
  }) {
    final question = _questionById(questionId);
    if (question == null) return 0;
    return question.impactWeightFor(areaId, itemId);
  }

  Future<DailyProfileSnapshot> currentProfileSnapshot({
    required DateTime now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final answers = <String, String>{};

    if (uid != null) {
      for (final key in const [
        'living_with',
        'children_count',
        'family_relationship',
        'home_routine_load',
        'study_work',
        'occupation_type',
        'work_schedule_format',
        'work_demand_type',
        'work_field',
        'stress_level',
        'emotional_state',
        'rest_capacity',
        'mental_load',
        'financial_situation',
        'income_stability',
        'financial_main_difficulty',
        'dependents_financial',
        'social_life',
        'emotional_support',
        'loneliness',
        'personal_organization',
        'home_organization',
        'consistency',
        'routine_predictability',
        'routine_main_weight',
        'focus',
        'goal',
        'app_help',
        'start_preference',
      ]) {
        final value = (prefs.getString('$uid:$key') ?? '').trim();
        if (value.isNotEmpty) {
          answers[key] = value;
        }
      }
    }

    final tags = <String>{};
    final primaryAreaIds = <String>{};
    String id = 'perfil_em_adaptacao';
    String label = 'Em adaptação';
    String reason = 'Seu perfil ainda está se ajustando à sua rotina atual.';

    final studyWork = answers['study_work'] ?? '';
    final occupation = answers['occupation_type'] ?? '';
    final livingWith = answers['living_with'] ?? '';
    final children = answers['children_count'] ?? '';
    final homeLoad = answers['home_routine_load'] ?? '';
    final focus = answers['focus'] ?? '';
    final goal = answers['goal'] ?? '';
    final help = answers['app_help'] ?? '';
    final financial = answers['financial_situation'] ?? '';
    final support = answers['emotional_support'] ?? '';
    final loneliness = answers['loneliness'] ?? '';
    final routinePredictability = answers['routine_predictability'] ?? '';
    final consistency = answers['consistency'] ?? '';
    final stress = answers['stress_level'] ?? '';

    if (studyWork.contains('Estudos') || occupation.contains('Estudante'))
      tags.add('student');
    if (studyWork.contains('Trabalho') ||
        occupation.contains('Empregado') ||
        occupation.contains('Autônomo') ||
        occupation.contains('freelancer') ||
        occupation.contains('Empreendo'))
      tags.add('worker');
    if (studyWork.contains('Casa e família') ||
        occupation.contains('casa') ||
        occupation.contains('família'))
      tags.add('caregiver');
    if (occupation.contains('transição') ||
        studyWork.contains('reorganizar') ||
        studyWork.contains('sem rotina'))
      tags.add('transition');
    if (livingWith.contains('sozinho')) tags.add('solo');
    if (livingWith.contains('filhos') || children.startsWith('Sim')) {
      tags.add('with_children');
      tags.add('with_family');
    }
    if (livingWith.contains('parceiro')) tags.add('with_partner');
    if (livingWith.contains('familiares') || livingWith.contains('pais'))
      tags.add('with_family');
    if (homeLoad == 'Muito puxada' || homeLoad == 'Instável')
      tags.add('house_heavy');
    if (support == 'Quase não' || support == 'Não') tags.add('support_low');
    if (loneliness.contains('Sozinho')) tags.add('social_fragile');
    if (financial == 'Instável' || financial == 'Muito difícil')
      tags.add('financial_pressure');
    if (routinePredictability.contains('caótica') ||
        routinePredictability.contains('Muito caótica'))
      tags.add('chaotic');
    if (consistency.contains('Quase não') || consistency.contains('Não'))
      tags.add('low_constancy');
    if (stress == 'Alto' || stress == 'Muito alto') tags.add('stress_high');
    if (help.contains('Disciplina') ||
        help.contains('Controle da rotina') ||
        goal.contains('constância'))
      tags.add('routine_focus');
    if (focus.contains('Projetos') ||
        goal.contains('metas e projetos') ||
        help.contains('Progresso')) {
      tags.add('project_focus');
      tags.add('growth_focus');
      primaryAreaIds.add('learning_intellect');
    }
    if (focus.contains('Trabalho')) primaryAreaIds.add('work_vocation');
    if (focus.contains('Relações')) primaryAreaIds.add('relations_community');
    if (focus.contains('Mente')) primaryAreaIds.add('mind_emotion');
    if (focus.contains('Hábitos')) primaryAreaIds.add('purpose_values');

    final box = await _open();
    final recentSignals = await _recentSignalTags(box: box, now: now);
    tags.addAll(recentSignals);

    if (tags.contains('caregiver') && tags.contains('stress_high')) {
      id = 'pilar_sobrecarregado';
      label = 'Pilar sobrecarregado';
      reason =
          'Você está segurando muita coisa ao mesmo tempo e o dia cobra caro.';
      primaryAreaIds.addAll({
        'mind_emotion',
        'purpose_values',
        'relations_community',
      });
    } else if (tags.contains('worker') && tags.contains('stress_high')) {
      id = 'trabalhador_em_pressao';
      label = 'Trabalhador em pressão';
      reason =
          'Seu ritmo atual está forte e a pressão tem pesado na sua cabeça.';
      primaryAreaIds.addAll({'work_vocation', 'mind_emotion'});
    } else if (tags.contains('student') && tags.contains('growth_focus')) {
      id = 'estudante_em_evolucao';
      label = 'Estudante em evolução';
      reason = 'Seu perfil puxa crescimento, foco e construção de progresso.';
      primaryAreaIds.addAll({'learning_intellect', 'work_vocation'});
    } else if (tags.contains('transition')) {
      id = 'reorganizando_a_vida';
      label = 'Reorganizando a vida';
      reason = 'Seu momento pede reconstrução de base, clareza e constância.';
      primaryAreaIds.addAll({
        'purpose_values',
        'work_vocation',
        'mind_emotion',
      });
    } else if (tags.contains('chaotic') || tags.contains('low_constancy')) {
      id = 'retomando_o_eixo';
      label = 'Retomando o eixo';
      reason = 'Seu perfil atual precisa recuperar base, repetição e ritmo.';
      primaryAreaIds.addAll({'purpose_values', 'work_vocation'});
    } else if (tags.contains('project_focus')) {
      id = 'executor_em_progresso';
      label = 'Executor em progresso';
      reason = 'Seu momento puxa avanço real, execução e continuidade.';
      primaryAreaIds.addAll({'learning_intellect', 'purpose_values'});
    } else if (tags.contains('social_fragile') ||
        tags.contains('support_low')) {
      id = 'reconstruindo_conexoes';
      label = 'Reconstruindo conexões';
      reason = 'Seu perfil atual pede mais apoio, vínculo e presença real.';
      primaryAreaIds.addAll({'relations_community', 'mind_emotion'});
    } else {
      id = 'ritmo_em_construcao';
      label = 'Ritmo em construção';
      reason =
          'Seu perfil atual está montando base e ajustando o próprio ritmo.';
      primaryAreaIds.addAll({'purpose_values', 'work_vocation'});
    }

    if (primaryAreaIds.isEmpty)
      primaryAreaIds.addAll({'mind_emotion', 'purpose_values'});

    return DailyProfileSnapshot(
      id: id,
      label: label,
      reason: reason,
      tags: tags,
      primaryAreaIds: primaryAreaIds,
    );
  }

  Future<Set<String>> _recentSignalTags({
    required Box<dynamic> box,
    required DateTime now,
  }) async {
    final tags = <String>{};
    final answers = <double>[];
    final focusPulls = <double>[];
    for (var i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final pressure = box.get(_answerKey(day, 'mental_pressure'));
      final distraction = box.get(_answerKey(day, 'distraction_pull'));
      final essentials = box.get(_answerKey(day, 'essentials_done'));
      final support = box.get(_answerKey(day, 'felt_supported'));
      if (pressure is int)
        answers.add(
          normalizedProgress01(
            questionId: 'mental_pressure',
            rawValue: pressure,
          ),
        );
      if (distraction is int)
        focusPulls.add(
          normalizedProgress01(
            questionId: 'distraction_pull',
            rawValue: distraction,
          ),
        );
      if (essentials is int)
        answers.add(
          normalizedProgress01(
            questionId: 'essentials_done',
            rawValue: essentials,
          ),
        );
      if (support is int &&
          normalizedProgress01(
                questionId: 'felt_supported',
                rawValue: support,
              ) <
              0.35)
        tags.add('support_low');
    }
    if (answers.isNotEmpty) {
      final avg = answers.reduce((a, b) => a + b) / answers.length;
      if (avg < 0.35) tags.add('low_constancy');
    }
    if (focusPulls.isNotEmpty) {
      final avg = focusPulls.reduce((a, b) => a + b) / focusPulls.length;
      if (avg < 0.40) tags.add('digital_risk');
    }
    return tags;
  }

  Future<String> currentProfileLabel({required DateTime now}) async {
    final profile = await currentProfileSnapshot(now: now);
    final box = await _open();
    await box.put(_profileCacheKey(now), profile.label);
    return profile.label;
  }

  List<DailyAnswerOption> optionsFor(DailyQuestion question) {
    switch (question.scaleType) {
      case DailyQuestionScaleType.quality5:
        return const [
          DailyAnswerOption(
            value: 0,
            label: 'Muito ruim',
            shortLabel: 'Muito ruim',
          ),
          DailyAnswerOption(value: 1, label: 'Ruim', shortLabel: 'Ruim'),
          DailyAnswerOption(
            value: 2,
            label: 'Mais ou menos',
            shortLabel: 'Médio',
          ),
          DailyAnswerOption(value: 3, label: 'Bom', shortLabel: 'Bom'),
          DailyAnswerOption(value: 4, label: 'Ótimo', shortLabel: 'Ótimo'),
        ];
      case DailyQuestionScaleType.agreement5:
      case DailyQuestionScaleType.amount5:
        return const [
          DailyAnswerOption(value: 0, label: 'Nada', shortLabel: 'Nada'),
          DailyAnswerOption(value: 1, label: 'Pouco', shortLabel: 'Pouco'),
          DailyAnswerOption(
            value: 2,
            label: 'Mais ou menos',
            shortLabel: 'Médio',
          ),
          DailyAnswerOption(
            value: 3,
            label: 'Bastante',
            shortLabel: 'Bastante',
          ),
          DailyAnswerOption(value: 4, label: 'Muito', shortLabel: 'Muito'),
        ];
    }
  }

  String answerLabel(int value, {DailyQuestion? question}) {
    final options = question == null ? _defaultOptions() : optionsFor(question);
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value.toString();
  }

  double normalizeAnswerValue(int value) =>
      _normalizeAnswerValueFromStored(value);

  int normalizeStoredValue({
    required String questionId,
    required int rawValue,
  }) {
    return rawValue.clamp(minAnswerValue, maxAnswerValue).toInt();
  }

  double normalizedProgress01({
    required String questionId,
    required int rawValue,
  }) {
    final question = _questionById(questionId);
    final safeValue = normalizeStoredValue(
      questionId: questionId,
      rawValue: rawValue,
    );
    final normalized = _normalizeAnswerValueFromStored(safeValue);
    if (question?.reverseScore == true) return 1.0 - normalized;
    return normalized;
  }

  Future<List<DailyQuestion>> questionsForToday({required DateTime now}) async {
    final box = await _open();
    final cacheKey = _questionsCacheKey(now);
    final cached = box.get(cacheKey);
    if (cached is List) {
      final ids = cached.whereType<String>().toList();
      final restored = ids
          .map(_questionById)
          .whereType<DailyQuestion>()
          .toList();
      if (restored.length == questionsPerDay) return restored;
    }
    final selected = await _buildAdaptiveQuestions(now);
    await box.put(cacheKey, selected.map((q) => q.id).toList());
    return selected;
  }

  Future<List<DailyQuestion>> _buildAdaptiveQuestions(DateTime now) async {
    final box = await _open();
    final profile = await currentProfileSnapshot(now: now);
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    final dueCandidates = <_WeightedQuestion>[];
    final fallbackCandidates = <_WeightedQuestion>[];
    for (final question in _pool) {
      final score = await _priorityScore(
        box: box,
        now: now,
        question: question,
        profile: profile,
      );
      final weighted = _WeightedQuestion(
        question: question,
        score: score + random.nextDouble() * 0.18,
      );
      if (await _isQuestionDue(box: box, now: now, question: question))
        dueCandidates.add(weighted);
      else
        fallbackCandidates.add(weighted);
    }
    dueCandidates.sort((a, b) => b.score.compareTo(a.score));
    fallbackCandidates.sort((a, b) => b.score.compareTo(a.score));
    final selected = <DailyQuestion>[];
    final usedAreas = <String>{};
    void pickPriorityAreaQuestions(List<_WeightedQuestion> source) {
      for (final targetArea in profile.primaryAreaIds) {
        if (selected.length >= questionsPerDay) return;
        for (final item in source) {
          final q = item.question;
          if (selected.any((s) => s.id == q.id)) continue;
          final affectsPriority = q.impacts.any((i) => i.areaId == targetArea);
          if (!affectsPriority) continue;
          selected.add(q);
          usedAreas.add(q.areaId);
          break;
        }
      }
    }

    void pickUniqueAreas(List<_WeightedQuestion> source) {
      for (final item in source) {
        if (selected.length >= questionsPerDay) return;
        final q = item.question;
        if (selected.any((s) => s.id == q.id)) continue;
        if (usedAreas.contains(q.areaId)) continue;
        selected.add(q);
        usedAreas.add(q.areaId);
      }
    }

    void fillRemaining(List<_WeightedQuestion> source) {
      for (final item in source) {
        if (selected.length >= questionsPerDay) return;
        final q = item.question;
        if (selected.any((s) => s.id == q.id)) continue;
        selected.add(q);
      }
    }

    pickPriorityAreaQuestions(dueCandidates);
    pickUniqueAreas(dueCandidates);
    if (selected.length < questionsPerDay)
      pickPriorityAreaQuestions(fallbackCandidates);
    if (selected.length < questionsPerDay) pickUniqueAreas(fallbackCandidates);
    if (selected.length < questionsPerDay) fillRemaining(dueCandidates);
    if (selected.length < questionsPerDay) fillRemaining(fallbackCandidates);
    return selected.take(questionsPerDay).toList(growable: false);
  }

  Future<bool> _isQuestionDue({
    required Box<dynamic> box,
    required DateTime now,
    required DailyQuestion question,
  }) async {
    final lastAskedAgo = _lastAskedDaysAgo(
      box: box,
      now: now,
      questionId: question.id,
    );
    if (lastAskedAgo == null) return true;
    return lastAskedAgo > _cooldownDays(question.cadence);
  }

  int _cooldownDays(DailyQuestionCadence cadence) {
    switch (cadence) {
      case DailyQuestionCadence.daily:
        return 0;
      case DailyQuestionCadence.every3Days:
        return 2;
      case DailyQuestionCadence.weekly:
        return 6;
      case DailyQuestionCadence.biweekly:
        return 13;
    }
  }

  int? _lastAskedDaysAgo({
    required Box<dynamic> box,
    required DateTime now,
    required String questionId,
  }) {
    for (var i = 1; i <= 60; i++) {
      final day = now.subtract(Duration(days: i));
      final raw = box.get(_questionsCacheKey(day));
      if (raw is! List) continue;
      final ids = raw.whereType<String>();
      if (ids.contains(questionId)) return i;
    }
    return null;
  }

  Future<double> _priorityScore({
    required Box<dynamic> box,
    required DateTime now,
    required DailyQuestion question,
    required DailyProfileSnapshot profile,
  }) async {
    double score = 1.0 + question.priorityBoost;
    for (final blocked in question.blockedTags) {
      if (profile.tags.contains(blocked)) score -= 2.0;
    }
    var tagMatches = 0;
    for (final tag in question.audienceTags) {
      if (profile.tags.contains(tag)) tagMatches++;
    }
    score += min(tagMatches, 3) * 0.85;
    if (question.impacts.any(
      (impact) => profile.primaryAreaIds.contains(impact.areaId),
    ))
      score += 1.15;
    for (var i = 1; i <= historyDays; i++) {
      final day = now.subtract(Duration(days: i));
      final raw = box.get(_answerKey(day, question.id));
      if (raw is! int) {
        score += 0.18;
        continue;
      }
      final normalized = normalizedProgress01(
        questionId: question.id,
        rawValue: raw,
      );
      final weight = (historyDays - i + 1) / historyDays;
      score += (1.0 - normalized) * 2.1 * weight;
      if (normalized < 0.45) score += 0.42 * weight;
      score -= 0.08;
    }
    final daysAgoAsked = _lastAskedDaysAgo(
      box: box,
      now: now,
      questionId: question.id,
    );
    if (daysAgoAsked != null) {
      final cooldown = _cooldownDays(question.cadence);
      if (daysAgoAsked <= cooldown) score -= 2.2;
    }
    return score;
  }

  DailyQuestion? _questionById(String id) {
    for (final q in _pool) {
      if (q.id == id) return q;
    }
    return null;
  }

  Future<void> answer({
    required DateTime day,
    required String questionId,
    required int value,
  }) async {
    final box = await _open();
    final safeValue = value.clamp(minAnswerValue, maxAnswerValue).toInt();
    await box.put(_answerKey(day, questionId), safeValue);
  }

  Future<int?> getAnswer({
    required DateTime day,
    required String questionId,
  }) async {
    final box = await _open();
    final raw = box.get(_answerKey(day, questionId));
    if (raw is! int) return null;
    return raw.clamp(minAnswerValue, maxAnswerValue).toInt();
  }

  Future<int> answeredCount(DateTime day) async {
    final box = await _open();
    final questions = await questionsForToday(now: day);
    var count = 0;
    for (final question in questions) {
      final raw = box.get(_answerKey(day, question.id));
      if (raw is int) count++;
    }
    return count;
  }

  Future<bool> tryCompleteIfAllAnswered(DateTime day) async {
    final box = await _open();
    final questions = await questionsForToday(now: day);
    for (final question in questions) {
      final raw = box.get(_answerKey(day, question.id));
      if (raw is! int) return false;
    }
    await box.put(_completedKey(day), true);
    return true;
  }

  Future<bool> isCompleted(DateTime day) async {
    final box = await _open();
    final raw = box.get(_completedKey(day));
    return raw == true;
  }

  Future<bool> canUseAreas(DateTime day) async => isCompleted(day);

  Future<DailyCheckinSummary> summary(DateTime day) async {
    final questions = await questionsForToday(now: day);
    final answered = await answeredCount(day);
    final completed = await isCompleted(day);
    return DailyCheckinSummary(
      total: questions.length,
      answered: answered,
      isCompleted: completed,
    );
  }

  List<DailyAnswerOption> _defaultOptions() {
    return const [
      DailyAnswerOption(value: 0, label: 'Nada', shortLabel: 'Nada'),
      DailyAnswerOption(value: 1, label: 'Pouco', shortLabel: 'Pouco'),
      DailyAnswerOption(value: 2, label: 'Médio', shortLabel: 'Médio'),
      DailyAnswerOption(value: 3, label: 'Bem', shortLabel: 'Bem'),
      DailyAnswerOption(value: 4, label: 'Muito', shortLabel: 'Muito'),
    ];
  }

  double _normalizeAnswerValueFromStored(int stored) {
    final safe = stored.clamp(minAnswerValue, maxAnswerValue).toInt();
    return safe / maxAnswerValue;
  }
}

class _WeightedQuestion {
  const _WeightedQuestion({required this.question, required this.score});
  final DailyQuestion question;
  final double score;
}
