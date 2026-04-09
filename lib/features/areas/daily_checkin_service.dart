// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Define o pool de perguntas do check-in diário
// - Separa perguntas por frequência de reaparição
// - Permite que uma mesma pergunta afete 1 ou mais subáreas com pesos diferentes
// - Escolhe perguntas com base no histórico recente
// - Salva respostas graduais por usuário no Hive
// - Mantém o contrato usado pelo restante do app
//
// Nesta revisão:
// - mantém perguntas sobre ONTEM
// - mantém o formato curto, leve e rápido
// - adiciona impactos por área/subárea com pesos diferentes
// - preserva frequência por pergunta (diária, 3 dias, semanal, quinzenal)
// - preserva perguntas invertidas (ex.: estresse, distração)
// ============================================================================

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum DailyQuestionScaleType { quality5, amount5 }

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
  });

  final int value;
  final String label;
  final String shortLabel;
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
  static const String _boxPrefix = 'daily_checkin_box_';
  static const int questionsPerDay = 5;
  static const int historyDays = 21;
  static const int minAnswerValue = 0;
  static const int maxAnswerValue = 4;

  static const List<DailyQuestion> _pool = [
    // CORPO & SAÚDE
    DailyQuestion(
      id: 'sleep_quality',
      areaId: 'body_health',
      areaLabel: 'Corpo & saúde',
      impacts: [
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'sleep',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'energy',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.18,
        ),
      ],
      text: 'Como foi seu sono ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.42,
    ),
    DailyQuestion(
      id: 'food_quality',
      areaId: 'body_health',
      areaLabel: 'Corpo & saúde',
      impacts: [
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'nutrition',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'energy',
          weight: 0.20,
        ),
      ],
      text: 'Como foi sua alimentação ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.40,
    ),
    DailyQuestion(
      id: 'movement_amount',
      areaId: 'body_health',
      areaLabel: 'Corpo & saúde',
      impacts: [
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'movement',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'energy',
          weight: 0.15,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'goals_review',
          weight: 0.10,
        ),
      ],
      text: 'Quanto você se movimentou ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.40,
    ),
    DailyQuestion(
      id: 'energy_level',
      areaId: 'body_health',
      areaLabel: 'Corpo & saúde',
      impacts: [
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'energy',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.25,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.25,
        ),
      ],
      text: 'Como esteve sua energia ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.42,
    ),
    DailyQuestion(
      id: 'hydration_care',
      areaId: 'body_health',
      areaLabel: 'Corpo & saúde',
      impacts: [
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'hydration',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'nutrition',
          weight: 0.35,
        ),
      ],
      text: 'Como foi seu cuidado com água ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.22,
    ),
    DailyQuestion(
      id: 'body_wellbeing',
      areaId: 'body_health',
      areaLabel: 'Corpo & saúde',
      impacts: [
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'sleep',
          weight: 0.35,
        ),
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'energy',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'body_health',
          itemId: 'movement',
          weight: 0.20,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.18,
        ),
      ],
      text: 'Como seu corpo se sentiu ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
    ),

    // MENTAL & EMOCIONAL
    DailyQuestion(
      id: 'mood_state',
      areaId: 'mind_emotion',
      areaLabel: 'Mental & emocional',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.15,
        ),
      ],
      text: 'Como esteve seu humor ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.42,
    ),
    DailyQuestion(
      id: 'stress_amount',
      areaId: 'mind_emotion',
      areaLabel: 'Mental & emocional',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.75,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.45,
        ),
      ],
      text: 'Você se estressou ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.45,
      reverseScore: true,
    ),
    DailyQuestion(
      id: 'focus_quality',
      areaId: 'mind_emotion',
      areaLabel: 'Mental & emocional',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'digital_tech',
          itemId: 'distraction',
          weight: 0.30,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'study',
          weight: 0.25,
        ),
      ],
      text: 'Você conseguiu focar no que importava ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.38,
    ),
    DailyQuestion(
      id: 'mental_weight',
      areaId: 'mind_emotion',
      areaLabel: 'Mental & emocional',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.35,
        ),
      ],
      text: 'Ontem foi um dia leve para sua mente?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.22,
    ),
    DailyQuestion(
      id: 'self_relation',
      areaId: 'mind_emotion',
      areaLabel: 'Mental & emocional',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.80,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.20,
        ),
      ],
      text: 'Como esteve sua relação com você ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
    ),
    DailyQuestion(
      id: 'recovery_quality',
      areaId: 'mind_emotion',
      areaLabel: 'Mental & emocional',
      impacts: [
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mental_load',
          weight: 0.65,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.35,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'gratitude',
          weight: 0.15,
        ),
      ],
      text: 'Você conseguiu se recuperar bem ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
    ),

    // FINANÇAS
    DailyQuestion(
      id: 'money_care',
      areaId: 'finance_material',
      areaLabel: 'Finanças',
      impacts: [
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'budget',
          weight: 0.70,
        ),
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'spending',
          weight: 1.00,
        ),
      ],
      text: 'Como foi seu cuidado com dinheiro ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
    ),
    DailyQuestion(
      id: 'avoid_waste',
      areaId: 'finance_material',
      areaLabel: 'Finanças',
      impacts: [
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'budget',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'spending',
          weight: 0.90,
        ),
      ],
      text: 'Você evitou gastos desnecessários ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.24,
    ),
    DailyQuestion(
      id: 'track_expenses',
      areaId: 'finance_material',
      areaLabel: 'Finanças',
      impacts: [
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'budget',
          weight: 0.95,
        ),
      ],
      text: 'Você acompanhou seus gastos ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.22,
    ),
    DailyQuestion(
      id: 'money_pressure',
      areaId: 'finance_material',
      areaLabel: 'Finanças',
      impacts: [
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'spending',
          weight: 0.80,
        ),
        DailyQuestionImpact(
          areaId: 'finance_material',
          itemId: 'budget',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'stress',
          weight: 0.20,
        ),
      ],
      text: 'O dinheiro pesou na sua cabeça ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.biweekly,
      priorityBoost: 0.18,
      reverseScore: true,
    ),

    // TRABALHO / VOCAÇÃO
    DailyQuestion(
      id: 'routine_organization',
      areaId: 'work_vocation',
      areaLabel: 'Rotina & trabalho',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.70,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'direction',
          weight: 0.20,
        ),
      ],
      text: 'Como foi sua organização ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.38,
    ),
    DailyQuestion(
      id: 'important_tasks',
      areaId: 'work_vocation',
      areaLabel: 'Rotina & trabalho',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'purpose_values',
          itemId: 'goals_review',
          weight: 0.25,
        ),
      ],
      text: 'Você conseguiu fazer o que precisava ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.40,
    ),
    DailyQuestion(
      id: 'plan_following',
      areaId: 'work_vocation',
      areaLabel: 'Rotina & trabalho',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'routine',
          weight: 0.75,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.60,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 0.40,
        ),
      ],
      text: 'Você conseguiu seguir seu plano ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.25,
    ),
    DailyQuestion(
      id: 'day_yield',
      areaId: 'work_vocation',
      areaLabel: 'Rotina & trabalho',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 0.85,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.25,
        ),
      ],
      text: 'Ontem seu dia rendeu bem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.24,
    ),
    DailyQuestion(
      id: 'procrastination',
      areaId: 'work_vocation',
      areaLabel: 'Rotina & trabalho',
      impacts: [
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'consistency',
          weight: 0.70,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 0.25,
        ),
      ],
      text: 'Você procrastinou ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
      reverseScore: true,
    ),

    // APRENDIZADO & INTELECTO
    DailyQuestion(
      id: 'learn_something',
      areaId: 'learning_intellect',
      areaLabel: 'Aprendizado',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'study',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'courses',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'skills',
          weight: 0.40,
        ),
      ],
      text: 'Você aprendeu algo útil ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.26,
    ),
    DailyQuestion(
      id: 'growth_attention',
      areaId: 'learning_intellect',
      areaLabel: 'Aprendizado',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'study',
          weight: 0.65,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'skills',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'review_practice',
          weight: 0.45,
        ),
      ],
      text: 'Você deu atenção ao seu crescimento ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.24,
    ),
    DailyQuestion(
      id: 'mind_usefulness',
      areaId: 'learning_intellect',
      areaLabel: 'Aprendizado',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'reading',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'skills',
          weight: 0.60,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'study',
          weight: 0.35,
        ),
      ],
      text: 'Você usou bem sua mente ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
    ),
    DailyQuestion(
      id: 'small_progress',
      areaId: 'learning_intellect',
      areaLabel: 'Aprendizado',
      impacts: [
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'courses',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'skills',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'learning_intellect',
          itemId: 'review_practice',
          weight: 0.35,
        ),
      ],
      text: 'Você avançou um pouco em algo que quer desenvolver?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
    ),

    // RELAÇÕES & COMUNIDADE
    DailyQuestion(
      id: 'social_connection',
      areaId: 'relations_community',
      areaLabel: 'Relações',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'family',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'friends',
          weight: 0.55,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'partner',
          weight: 0.55,
        ),
      ],
      text: 'Como esteve sua conexão com pessoas importantes ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.28,
    ),
    DailyQuestion(
      id: 'social_presence',
      areaId: 'relations_community',
      areaLabel: 'Relações',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.80,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'family',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'friends',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'partner',
          weight: 0.45,
        ),
      ],
      text: 'Você deu atenção de verdade a alguém ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.20,
    ),
    DailyQuestion(
      id: 'support_feeling',
      areaId: 'relations_community',
      areaLabel: 'Relações',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.80,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'family',
          weight: 0.40,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'friends',
          weight: 0.40,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'partner',
          weight: 0.40,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'mood',
          weight: 0.20,
        ),
      ],
      text: 'Você se sentiu apoiado(a) ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
    ),
    DailyQuestion(
      id: 'social_coexistence',
      areaId: 'relations_community',
      areaLabel: 'Relações',
      impacts: [
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'family',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'friends',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'partner',
          weight: 0.45,
        ),
        DailyQuestionImpact(
          areaId: 'relations_community',
          itemId: 'social_contact',
          weight: 0.60,
        ),
      ],
      text: 'Como foi sua convivência com outras pessoas ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.biweekly,
      priorityBoost: 0.16,
    ),

    // DIGITAL & TECNOLOGIA
    DailyQuestion(
      id: 'phone_control',
      areaId: 'digital_tech',
      areaLabel: 'Digital',
      impacts: [
        DailyQuestionImpact(
          areaId: 'digital_tech',
          itemId: 'distraction',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'balance',
          weight: 0.10,
        ),
      ],
      text: 'Como foi seu controle com o celular ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.34,
    ),
    DailyQuestion(
      id: 'digital_distraction',
      areaId: 'digital_tech',
      areaLabel: 'Digital',
      impacts: [
        DailyQuestionImpact(
          areaId: 'digital_tech',
          itemId: 'distraction',
          weight: 1.00,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 0.20,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 0.20,
        ),
      ],
      text: 'Você conseguiu evitar distrações digitais ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.daily,
      priorityBoost: 0.34,
    ),
    DailyQuestion(
      id: 'phone_harm_focus',
      areaId: 'digital_tech',
      areaLabel: 'Digital',
      impacts: [
        DailyQuestionImpact(
          areaId: 'digital_tech',
          itemId: 'distraction',
          weight: 0.90,
        ),
        DailyQuestionImpact(
          areaId: 'mind_emotion',
          itemId: 'focus',
          weight: 0.35,
        ),
        DailyQuestionImpact(
          areaId: 'work_vocation',
          itemId: 'output',
          weight: 0.25,
        ),
      ],
      text: 'O celular atrapalhou seu foco ontem?',
      scaleType: DailyQuestionScaleType.amount5,
      cadence: DailyQuestionCadence.every3Days,
      priorityBoost: 0.24,
      reverseScore: true,
    ),
    DailyQuestion(
      id: 'phone_intention',
      areaId: 'digital_tech',
      areaLabel: 'Digital',
      impacts: [
        DailyQuestionImpact(
          areaId: 'digital_tech',
          itemId: 'distraction',
          weight: 0.85,
        ),
        DailyQuestionImpact(
          areaId: 'digital_tech',
          itemId: 'screen_time',
          weight: 0.35,
        ),
      ],
      text: 'Você usou o celular com intenção ontem?',
      scaleType: DailyQuestionScaleType.quality5,
      cadence: DailyQuestionCadence.weekly,
      priorityBoost: 0.18,
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
      case DailyQuestionScaleType.amount5:
        return const [
          DailyAnswerOption(value: 0, label: 'Nada', shortLabel: 'Nada'),
          DailyAnswerOption(value: 1, label: 'Pouco', shortLabel: 'Pouco'),
          DailyAnswerOption(value: 2, label: 'Médio', shortLabel: 'Médio'),
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
    if (question?.reverseScore == true) {
      return 1.0 - normalized;
    }
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
      if (restored.length == questionsPerDay) {
        return restored;
      }
    }

    final selected = await _buildAdaptiveQuestions(now);
    await box.put(cacheKey, selected.map((q) => q.id).toList());
    return selected;
  }

  Future<List<DailyQuestion>> _buildAdaptiveQuestions(DateTime now) async {
    final box = await _open();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);

    final dueCandidates = <_WeightedQuestion>[];
    final fallbackCandidates = <_WeightedQuestion>[];

    for (final question in _pool) {
      final score = await _priorityScore(
        box: box,
        now: now,
        question: question,
      );
      final weighted = _WeightedQuestion(
        question: question,
        score: score + random.nextDouble() * 0.20,
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

    void pickFrom(List<_WeightedQuestion> source) {
      for (final item in source) {
        if (selected.length >= questionsPerDay) return;
        final q = item.question;
        if (selected.any((s) => s.id == q.id)) continue;
        if (!usedAreas.contains(q.areaId)) {
          selected.add(q);
          usedAreas.add(q.areaId);
        }
      }
    }

    void fillFrom(List<_WeightedQuestion> source) {
      for (final item in source) {
        if (selected.length >= questionsPerDay) return;
        final q = item.question;
        if (selected.any((s) => s.id == q.id)) continue;
        selected.add(q);
      }
    }

    pickFrom(dueCandidates);
    if (selected.length < questionsPerDay) {
      pickFrom(fallbackCandidates);
    }
    if (selected.length < questionsPerDay) {
      fillFrom(dueCandidates);
    }
    if (selected.length < questionsPerDay) {
      fillFrom(fallbackCandidates);
    }

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
      if (ids.contains(questionId)) {
        return i;
      }
    }
    return null;
  }

  Future<double> _priorityScore({
    required Box<dynamic> box,
    required DateTime now,
    required DailyQuestion question,
  }) async {
    double score = 1.0 + question.priorityBoost;

    for (var i = 1; i <= historyDays; i++) {
      final day = now.subtract(Duration(days: i));
      final raw = box.get(_answerKey(day, question.id));

      if (raw is! int) {
        score += 0.24;
        continue;
      }

      final normalized = normalizedProgress01(
        questionId: question.id,
        rawValue: raw,
      );

      final weight = (historyDays - i + 1) / historyDays;
      score += (1.0 - normalized) * 2.6 * weight;

      if (normalized < 0.5) {
        score += 0.55 * weight;
      }

      score -= 0.10;
    }

    final daysAgoAsked = _lastAskedDaysAgo(
      box: box,
      now: now,
      questionId: question.id,
    );

    if (daysAgoAsked != null) {
      final cooldown = _cooldownDays(question.cadence);
      if (daysAgoAsked <= cooldown) {
        score -= 2.0;
      }
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

  Future<bool> canUseAreas(DateTime day) async {
    return isCompleted(day);
  }

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
