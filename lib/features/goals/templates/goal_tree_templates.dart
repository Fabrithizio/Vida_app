// lib/features/goals/templates/goal_tree_templates.dart
import 'package:flutter/material.dart';
import '../data/models/goal_tree_models.dart';

class GoalTreeTemplates {
  static const String medicoV1 = 'medico_v1';

  static GoalTreeStateModel createInitialState({
    required String goalId,
    required String goalTitle,
    required String templateId,
    int? createdAtMs,
  }) {
    final nowMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

    switch (templateId) {
      case medicoV1:
        return GoalTreeStateModel(
          goalId: goalId,
          goalTitle: goalTitle,
          templateId: medicoV1,
          nodes: _medicoNodesV1(goalTitle),
          completedIds: <String>{},
          createdAtMs: nowMs,
        );

      case 'habitos_v1':
        return GoalTreeStateModel(
          goalId: goalId,
          goalTitle: goalTitle,
          templateId: 'habitos_v1',
          nodes: _habitosNodesV1(goalTitle),
          completedIds: <String>{},
          createdAtMs: nowMs,
        );

      case 'idioma_v1':
        return GoalTreeStateModel(
          goalId: goalId,
          goalTitle: goalTitle,
          templateId: 'idioma_v1',
          nodes: _idiomaNodesV1(goalTitle),
          completedIds: <String>{},
          createdAtMs: nowMs,
        );

      default:
        return GoalTreeStateModel(
          goalId: goalId,
          goalTitle: goalTitle,
          templateId: medicoV1,
          nodes: _medicoNodesV1(goalTitle),
          completedIds: <String>{},
          createdAtMs: nowMs,
        );
    }
  }

  static List<GoalNodeModel> _habitosNodesV1(String goalTitle) => [
    GoalNodeModel(
      id: 'root',
      title: goalTitle,
      description: 'Início',
      position: const Offset(220, 220),
      parents: const [],
      rewardLabel: '+10 XP',
    ),
    const GoalNodeModel(
      id: 'dia1',
      title: 'Dia 1',
      description: 'Primeiro check-in.',
      position: Offset(420, 220),
      parents: ['root'],
      rewardLabel: '+1 streak',
    ),
    const GoalNodeModel(
      id: 'dia3',
      title: 'Dia 3',
      description: 'Consistência inicial.',
      position: Offset(620, 220),
      parents: ['dia1'],
      rewardLabel: '+2 streak',
    ),
    const GoalNodeModel(
      id: 'dia7',
      title: 'Dia 7',
      description: 'Uma semana!',
      position: Offset(820, 220),
      parents: ['dia3'],
      rewardLabel: '🏅 Badge',
    ),
  ];

  static List<GoalNodeModel> _idiomaNodesV1(String goalTitle) => [
    GoalNodeModel(
      id: 'root',
      title: goalTitle,
      description: 'Início',
      position: const Offset(220, 220),
      parents: const [],
      rewardLabel: '+10 XP',
    ),
    const GoalNodeModel(
      id: 'basico',
      title: 'Base',
      description: 'Vocabulário e gramática.',
      position: Offset(450, 170),
      parents: ['root'],
      rewardLabel: '+20 XP',
    ),
    const GoalNodeModel(
      id: 'escuta',
      title: 'Escuta',
      description: 'Áudio todo dia.',
      position: Offset(450, 300),
      parents: ['root'],
      rewardLabel: '+Foco',
    ),
    const GoalNodeModel(
      id: 'conversa',
      title: 'Conversação',
      description: 'Praticar falando.',
      position: Offset(700, 230),
      parents: ['basico', 'escuta'],
      rewardLabel: '+Confiança',
    ),
    const GoalNodeModel(
      id: 'fluencia',
      title: 'Fluência',
      description: 'Meta final do template.',
      position: Offset(960, 230),
      parents: ['conversa'],
      rewardLabel: '🏆 Final',
    ),
  ];

  static List<GoalNodeModel> _medicoNodesV1(String goalTitle) => [
    GoalNodeModel(
      id: 'root',
      title: goalTitle,
      description: 'Início',
      position: const Offset(220, 220),
      parents: const [],
      rewardLabel: '+10 XP',
    ),
    const GoalNodeModel(
      id: 'pesquisa',
      title: 'Pesquisar caminho',
      description: 'Como funciona no seu país.',
      position: Offset(420, 160),
      parents: ['root'],
      rewardLabel: '+Clareza',
    ),
    const GoalNodeModel(
      id: 'plano_estudos',
      title: 'Plano de estudos',
      description: 'Cronograma semanal.',
      position: Offset(420, 300),
      parents: ['root'],
      rewardLabel: '+Disciplina',
    ),
    const GoalNodeModel(
      id: 'base',
      title: 'Base',
      description: 'Fundamentos para provas.',
      position: Offset(640, 110),
      parents: ['pesquisa'],
      rewardLabel: '+20 XP',
    ),
    const GoalNodeModel(
      id: 'simulados',
      title: 'Simulados',
      description: 'Rotina de prova.',
      position: Offset(640, 240),
      parents: ['plano_estudos'],
      rewardLabel: '+Performance',
    ),
    const GoalNodeModel(
      id: 'aprovacao',
      title: 'Aprovação',
      description: 'Passar no seletivo.',
      position: Offset(640, 380),
      parents: ['base', 'simulados'],
      rewardLabel: '🎉 Badge',
    ),
    const GoalNodeModel(
      id: 'ciclo_basico',
      title: 'Ciclo básico',
      description: 'Fundamentos.',
      position: Offset(880, 160),
      parents: ['aprovacao'],
      rewardLabel: '+Conhecimento',
    ),
    const GoalNodeModel(
      id: 'ciclo_clinico',
      title: 'Ciclo clínico',
      description: 'Clínica.',
      position: Offset(880, 300),
      parents: ['ciclo_basico'],
      rewardLabel: '+Prática',
    ),
    const GoalNodeModel(
      id: 'internato',
      title: 'Internato',
      description: 'Rodízios.',
      position: Offset(1120, 230),
      parents: ['ciclo_clinico'],
      rewardLabel: '+Confiança',
    ),
    const GoalNodeModel(
      id: 'residencia',
      title: 'Residência',
      description: 'Meta final.',
      position: Offset(1340, 230),
      parents: ['internato'],
      rewardLabel: '🏆 Final',
    ),
  ];
}
