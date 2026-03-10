// lib/features/goals/presentation/pages/goals_hub_page.dart
import 'package:flutter/material.dart';

import '../../data/models/goal_tree_models.dart';
import '../../data/repositories/hive_goal_tree_repository.dart';
import '../../generation/goal_tree_generator.dart';
import '../../goal_tree_store.dart';
import 'goal_tree_page.dart';

class GoalsHubPage extends StatefulWidget {
  const GoalsHubPage({super.key});

  @override
  State<GoalsHubPage> createState() => _GoalsHubPageState();
}

class _GoalsHubPageState extends State<GoalsHubPage> {
  final _repo = HiveGoalTreeRepository();
  List<GoalSummaryModel> _goals = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final list = await _repo.listGoals();
    if (!mounted) return;
    setState(() {
      _goals = list;
      _loading = false;
    });
  }

  Future<void> _addNewGoal() async {
    final title = await showDialog<String?>(
      context: context,
      builder: (context) => const _NewGoalDialog(),
    );
    if (title == null) return;

    final generated = GoalTreeGenerator.generate(goalTitle: title);
    await _repo.saveGoal(generated);
    await _reload();

    if (!mounted) return;
    await _openGoal(generated.goalId);
  }

  Future<void> _openGoal(String goalId) async {
    final store = GoalTreeStore(repo: _repo, goalId: goalId);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GoalTreePage(store: store)));
    await _reload(); // volta e atualiza progresso
  }

  Future<void> _deleteGoal(String goalId) async {
    await _repo.deleteGoal(goalId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Metas'),
        actions: [
          IconButton(
            tooltip: 'Adicionar',
            onPressed: _addNewGoal,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree, size: 48),
                    const SizedBox(height: 12),
                    const Text('Nenhuma meta ainda.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _addNewGoal,
                      icon: const Icon(Icons.add),
                      label: const Text('Criar meta'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final g = _goals[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(g.goalTitle),
                    subtitle: Text(g.templateId),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete') await _deleteGoal(g.goalId);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                    onTap: () => _openGoal(g.goalId),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewGoal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NewGoalDialog extends StatefulWidget {
  const _NewGoalDialog();

  @override
  State<_NewGoalDialog> createState() => _NewGoalDialogState();
}

class _NewGoalDialogState extends State<_NewGoalDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova meta'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Ex: Ser dev Flutter',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => Navigator.of(context).pop(_ctrl.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Gerar passos'),
        ),
      ],
    );
  }
}
