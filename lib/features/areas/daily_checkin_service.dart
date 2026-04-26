// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Define o pool adaptativo de perguntas do check-in diário
// - Escolhe 5 perguntas por dia com base no perfil vivo oficial
// - Permite que uma resposta afete várias áreas/subáreas com pesos diferentes
// - Salva respostas graduais por usuário no Hive
//
// Correção desta versão:
// - remove a duplicação de perfil que existia dentro do próprio check-in
// - passa a usar LiveUserProfileBridge como fonte oficial de tags e prioridades
// - mantém o hook que força refresh do perfil ao concluir o check-in
// ============================================================================

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_bridge.dart';
import 'package:vida_app/features/areas/daily_checkin_profile_hooks.dart';

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

class DailyCheckinService {
  DailyCheckinService({
    LiveUserProfileBridge? profileBridge,
    DailyCheckinProfileHooks? profileHooks,
  }) : _profileBridge = profileBridge ?? LiveUserProfileBridge(),
       _profileHooks = profileHooks ?? DailyCheckinProfileHooks();

  static const String _boxPrefix = 'daily_checkin_box_';
  static const int questionsPerDay = 5;
  static const int historyDays = 21;
  static const int minAnswerValue = 0;
  static const int maxAnswerValue = 4;

  final LiveUserProfileBridge _profileBridge;
  final DailyCheckinProfileHooks _profileHooks;

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

  Future<String> currentProfileLabel({required DateTime now}) async {
    return _profileBridge.currentLabel();
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
    final profile = await _resolveOfficialProfile();
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
      if (await _isQuestionDue(box: box, now: now, question: question)) {
        dueCandidates.add(weighted);
      } else {
        fallbackCandidates.add(weighted);
      }
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

    if (selected.length < questionsPerDay) {
      pickPriorityAreaQuestions(fallbackCandidates);
    }
    if (selected.length < questionsPerDay) {
      pickUniqueAreas(fallbackCandidates);
    }
    if (selected.length < questionsPerDay) fillRemaining(dueCandidates);
    if (selected.length < questionsPerDay) fillRemaining(fallbackCandidates);

    return selected.take(questionsPerDay).toList(growable: false);
  }

  Future<_ResolvedDailyProfile> _resolveOfficialProfile() async {
    final tags = await _profileBridge.currentTags();
    final areas = await _profileBridge.currentPrimaryAreas();
    return _ResolvedDailyProfile(
      tags: tags,
      primaryAreaIds: areas.isEmpty
          ? <String>{'mind_emotion', 'purpose_values'}
          : areas,
    );
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
    required _ResolvedDailyProfile profile,
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
    )) {
      score += 1.15;
    }

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
    await _profileHooks.onCheckinCompleted();
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

class _ResolvedDailyProfile {
  const _ResolvedDailyProfile({
    required this.tags,
    required this.primaryAreaIds,
  });

  final Set<String> tags;
  final Set<String> primaryAreaIds;
}

class _WeightedQuestion {
  const _WeightedQuestion({required this.question, required this.score});

  final DailyQuestion question;
  final double score;
}
