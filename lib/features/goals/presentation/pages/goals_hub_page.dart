// ============================================================================
// FILE: lib/features/goals/presentation/pages/goals_hub_page.dart
//
// O que este arquivo faz:
// - Vira a nova central de objetivos/metas/problemas
// - Mostra captura livre, progresso real e próxima ação
// - Substitui a sensação de "árvore bonita" por utilidade real
// ============================================================================

import 'package:flutter/material.dart';

import '../../data/models/goals_models.dart';
import '../../data/repositories/hive_goals_repository.dart';
import 'goal_details_page.dart';
import 'goal_editor_page.dart';

class GoalsHubPage extends StatefulWidget {
  const GoalsHubPage({super.key});

  @override
  State<GoalsHubPage> createState() => _GoalsHubPageState();
}

class _GoalsHubPageState extends State<GoalsHubPage> {
  final _repo = HiveGoalsRepository();

  bool _loading = true;
  List<GoalSummaryModel> _goals = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final items = await _repo.listGoals();
    if (!mounted) return;
    setState(() {
      _goals = items;
      _loading = false;
    });
  }

  Future<void> _createGoal() async {
    final created = await Navigator.of(context).push<GoalPlanModel>(
      MaterialPageRoute(builder: (_) => const GoalEditorPage()),
    );
    if (created == null) return;

    await _repo.saveGoal(created);
    await _reload();

    if (!mounted) return;
    await _openGoal(created.id);
  }

  Future<void> _openGoal(String id) async {
    final plan = await _repo.loadGoal(id);
    if (plan == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalDetailsPage(repository: _repo, initialPlan: plan),
      ),
    );

    await _reload();
  }

  Future<void> _deleteGoal(String id) async {
    await _repo.deleteGoal(id);
    await _reload();
  }

  int get _activeCount =>
      _goals.where((item) => item.status != GoalStatus.completed).length;

  int get _completedCount =>
      _goals.where((item) => item.status == GoalStatus.completed).length;

  double get _avgProgress {
    if (_goals.isEmpty) return 0;
    final total = _goals.fold<double>(0, (sum, item) => sum + item.progress);
    return total / _goals.length;
  }

  String _kindLabel(GoalKind value) {
    switch (value) {
      case GoalKind.objective:
        return 'Objetivo';
      case GoalKind.project:
        return 'Projeto';
      case GoalKind.problem:
        return 'Problema';
      case GoalKind.habit:
        return 'Hábito';
    }
  }

  String _areaLabel(GoalArea value) {
    switch (value) {
      case GoalArea.pessoal:
        return 'Pessoal';
      case GoalArea.casa:
        return 'Casa';
      case GoalArea.trabalho:
        return 'Trabalho';
      case GoalArea.empresa:
        return 'Empresa';
      case GoalArea.estudo:
        return 'Estudo';
      case GoalArea.saude:
        return 'Saúde';
      case GoalArea.financas:
        return 'Finanças';
      case GoalArea.relacionamento:
        return 'Relacionamento';
      case GoalArea.outro:
        return 'Outro';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Objetivos e pendências'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGoal,
        backgroundColor: const Color(0xFFA855F7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 94),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF26103B), Color(0xFF12091E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Central para destravar a vida',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Jogue aqui metas, projetos, problemas e pendências. O app te ajuda a quebrar isso em pequenas vitórias.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _heroMetric(
                                label: 'Ativos',
                                value: '$_activeCount',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroMetric(
                                label: 'Concluídos',
                                value: '$_completedCount',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroMetric(
                                label: 'Média',
                                value:
                                    '${(_avgProgress * 100).toStringAsFixed(0)}%',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _createGoal,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFA855F7),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Criar objetivo agora'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_goals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10182B),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.flag_circle_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Ainda não existe nada aqui',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pode ser uma meta, uma pendência, um problema ou uma coisa que você vive empurrando com a barriga.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._goals.map(
                      (goal) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalSummaryCard(
                          title: goal.title,
                          subtitle:
                              '${_kindLabel(goal.kind)} • ${_areaLabel(goal.area)}',
                          stage: goal.currentStageLabel,
                          nextAction: goal.nextActionTitle,
                          progress: goal.progress,
                          completed: goal.status == GoalStatus.completed,
                          onTap: () => _openGoal(goal.id),
                          onDelete: () => _deleteGoal(goal.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _heroMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.title,
    required this.subtitle,
    required this.stage,
    required this.nextAction,
    required this.progress,
    required this.completed,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String stage;
  final String nextAction;
  final double progress;
  final bool completed;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = completed
        ? const Color(0xFF22C55E)
        : const Color(0xFFA855F7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etapa atual',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Próxima ação: $nextAction',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              completed
                  ? 'Concluído. Você chegou lá.'
                  : '${(progress * 100).toStringAsFixed(0)}% do caminho concluído',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
