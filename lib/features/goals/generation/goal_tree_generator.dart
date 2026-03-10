// lib/features/goals/generation/goal_tree_generator.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../data/models/goal_tree_models.dart';

class GoalTreeGenerator {
  static GoalTreeStateModel generate({required String goalTitle}) {
    final now = DateTime.now();
    final goalId = _idFromNow(now);
    final normalized = goalTitle.trim().isEmpty
        ? 'Minha meta'
        : goalTitle.trim();
    final templateId = _inferTemplate(normalized);

    final nodes = _buildAutoTree(normalized, templateId);
    return GoalTreeStateModel(
      goalId: goalId,
      goalTitle: normalized,
      templateId: templateId,
      nodes: nodes,
      completedIds: <String>{},
      createdAtMs: now.millisecondsSinceEpoch,
    );
  }

  static String _idFromNow(DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    final r = math.Random(ms).nextInt(99999).toString().padLeft(5, '0');
    return '$ms$r';
  }

  static String _inferTemplate(String goalTitle) {
    final g = goalTitle.toLowerCase();

    if (g.contains('dev') ||
        g.contains('program') ||
        g.contains('flutter') ||
        g.contains('android') ||
        g.contains('front') ||
        g.contains('back')) {
      return 'auto_dev_v1';
    }
    if (g.contains('medic') || g.contains('medicina') || g.contains('resid')) {
      return 'auto_med_v1';
    }
    if (g.contains('ingl') ||
        g.contains('idioma') ||
        g.contains('espan') ||
        g.contains('language')) {
      return 'auto_language_v1';
    }
    if (g.contains('emag') ||
        g.contains('peso') ||
        g.contains('fitness') ||
        g.contains('trein')) {
      return 'auto_fitness_v1';
    }

    return 'auto_generic_v1';
  }

  static List<GoalNodeModel> _buildAutoTree(
    String goalTitle,
    String templateId,
  ) {
    // Base: 6 fases com ramificações leves
    // Mantém visual “skill tree” e evita ficar raso.
    final start = const Offset(240, 240);
    const dx = 260.0;
    const dy = 130.0;

    final root = GoalNodeModel(
      id: 'root',
      title: goalTitle,
      description: 'Início da meta',
      position: start,
      parents: const [],
      rewardLabel: '+10 XP',
    );

    final phases = _phasesFor(templateId);

    // cria nodes em 2 trilhas (superior/inferior) e um “boss” final
    final nodes = <GoalNodeModel>[root];

    // Phase 1
    nodes.add(
      GoalNodeModel(
        id: 'p1',
        title: phases[0],
        description: '',
        position: Offset(start.dx + dx, start.dy - dy),
        parents: const ['root'],
        rewardLabel: '+XP',
      ),
    );
    nodes.add(
      GoalNodeModel(
        id: 'p2',
        title: phases[1],
        description: '',
        position: Offset(start.dx + dx, start.dy + dy),
        parents: const ['root'],
        rewardLabel: '+XP',
      ),
    );

    // Phase 2 converge
    nodes.add(
      GoalNodeModel(
        id: 'p3',
        title: phases[2],
        description: '',
        position: Offset(start.dx + dx * 2, start.dy),
        parents: const ['p1', 'p2'],
        rewardLabel: '+XP',
      ),
    );

    // Phase 3 split
    nodes.add(
      GoalNodeModel(
        id: 'p4',
        title: phases[3],
        description: '',
        position: Offset(start.dx + dx * 3, start.dy - dy),
        parents: const ['p3'],
        rewardLabel: '+XP',
      ),
    );
    nodes.add(
      GoalNodeModel(
        id: 'p5',
        title: phases[4],
        description: '',
        position: Offset(start.dx + dx * 3, start.dy + dy),
        parents: const ['p3'],
        rewardLabel: '+XP',
      ),
    );

    // Boss final
    nodes.add(
      GoalNodeModel(
        id: 'boss',
        title: phases[5],
        description: 'Conclusão',
        position: Offset(start.dx + dx * 4, start.dy),
        parents: const ['p4', 'p5'],
        rewardLabel: '🏆 Final',
      ),
    );

    return nodes;
  }

  static List<String> _phasesFor(String templateId) {
    switch (templateId) {
      case 'auto_dev_v1':
        return const [
          'Escolher área (Mobile/Web/Back)',
          'Aprender fundamentos',
          'Construir 1º projeto',
          'Projetos reais (3)',
          'Portfólio + GitHub',
          'Conseguir vaga / freelas',
        ];
      case 'auto_language_v1':
        return const [
          'Definir nível e rotina',
          'Vocabulário base',
          'Compreensão (áudio)',
          'Leitura + escrita',
          'Conversação',
          'Fluência funcional',
        ];
      case 'auto_fitness_v1':
        return const [
          'Definir plano e medidas',
          'Rotina (3x semana)',
          'Nutrição (constância)',
          'Progressão de carga',
          'Sono e recuperação',
          'Meta atingida',
        ];
      case 'auto_med_v1':
        return const [
          'Entender o caminho',
          'Plano de estudos',
          'Base forte',
          'Aprovação',
          'Graduação',
          'Residência / fim',
        ];
      default:
        return const [
          'Definir meta e prazo',
          'Quebrar em etapas',
          'Primeira execução',
          'Consistência',
          'Ajustar estratégia',
          'Meta concluída',
        ];
    }
  }
}
