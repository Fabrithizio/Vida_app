// lib/features/goals/presentation/pages/custom_goal_wizard_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/models/goal_tree_models.dart';

class CustomGoalWizardPage extends StatefulWidget {
  const CustomGoalWizardPage({super.key});

  @override
  State<CustomGoalWizardPage> createState() => _CustomGoalWizardPageState();
}

class _CustomGoalWizardPageState extends State<CustomGoalWizardPage> {
  final _goalCtrl = TextEditingController();
  final _stepsCtrl = TextEditingController();

  @override
  void dispose() {
    _goalCtrl.dispose();
    _stepsCtrl.dispose();
    super.dispose();
  }

  String _newGoalId() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    final r = math.Random(ms).nextInt(99999).toString().padLeft(5, '0');
    return '$ms$r';
  }

  GoalTreeStateModel _buildTree({
    required String goalId,
    required String goalTitle,
    required List<String> steps,
  }) {
    const start = Offset(220, 240);
    const dx = 240.0;
    const dy = 95.0;

    final nodes = <GoalNodeModel>[
      GoalNodeModel(
        id: 'root',
        title: goalTitle,
        description: 'Início',
        position: start,
        parents: const [],
        rewardLabel: '+10 XP',
      ),
    ];

    var prev = 'root';

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i].trim();
      if (step.isEmpty) continue;

      final pos = Offset(
        start.dx + dx * (i + 1),
        start.dy + (i.isEven ? -dy : dy),
      );

      final id = 's${i + 1}';
      nodes.add(
        GoalNodeModel(
          id: id,
          title: step,
          description: '',
          position: pos,
          parents: [prev],
          rewardLabel: i == steps.length - 1 ? '🏁 Concluiu' : '+XP',
        ),
      );
      prev = id;
    }

    return GoalTreeStateModel(
      goalId: goalId,
      goalTitle: goalTitle,
      templateId: 'custom_v1',
      nodes: nodes,
      completedIds: <String>{},
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _submit() {
    final goalTitle = _goalCtrl.text.trim().isEmpty
        ? 'Minha meta'
        : _goalCtrl.text.trim();
    final steps = _stepsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos 1 passo (uma linha por passo).'),
        ),
      );
      return;
    }

    final goalId = _newGoalId();
    final tree = _buildTree(goalId: goalId, goalTitle: goalTitle, steps: steps);
    Navigator.of(context).pop<GoalTreeStateModel>(tree);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar meta personalizada')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _goalCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome da meta',
              hintText: 'Ex: Ser dev Flutter / Passar no concurso',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stepsCtrl,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Passos (1 por linha)',
              hintText:
                  'Ex:\nEstudar lógica\nAprender Dart\nFazer 3 apps\nCriar portfólio\n...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.account_tree),
            label: const Text('Gerar árvore'),
          ),
        ],
      ),
    );
  }
}
