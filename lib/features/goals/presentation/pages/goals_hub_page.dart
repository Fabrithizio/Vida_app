// ============================================================================
// FILE: lib/features/goals/presentation/pages/goals_hub_page.dart
//
// O que este arquivo faz:
// - Transforma a área de metas em uma central mais gamificada
// - Dá sensação de progresso com linguagem de missão, fase e próxima jogada
// - Mostra cards com energia visual sem perder utilidade real
// - Continua usando a nova estrutura de dados e persistência já criada
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

  int get _almostThereCount => _goals
      .where(
        (item) => item.progress >= 0.7 && item.status != GoalStatus.completed,
      )
      .length;

  double get _avgProgress {
    if (_goals.isEmpty) return 0;
    final total = _goals.fold<double>(0, (sum, item) => sum + item.progress);
    return total / _goals.length;
  }

  int _xpForGoal(GoalSummaryModel goal) {
    final base = (goal.progress * 100).round();
    return goal.status == GoalStatus.completed ? base + 80 : base + 15;
  }

  int get _totalXp =>
      _goals.fold<int>(0, (sum, item) => sum + _xpForGoal(item));

  String get _playerMood {
    if (_goals.isEmpty) return 'Modo preparação';
    if (_completedCount >= 3) return 'Modo imparável';
    if (_almostThereCount >= 2) return 'Quase virando fase';
    if (_activeCount >= 3) return 'Missões em andamento';
    return 'Ritmo crescente';
  }

  String _kindLabel(GoalKind value) {
    switch (value) {
      case GoalKind.objective:
        return 'Missão';
      case GoalKind.project:
        return 'Projeto';
      case GoalKind.problem:
        return 'Boss';
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

  String _progressLabel(double progress, bool completed) {
    if (completed) return 'Conquista desbloqueada';
    if (progress >= 0.85) return 'Chefão quase vencido';
    if (progress >= 0.60) return 'Fase bem encaminhada';
    if (progress >= 0.30) return 'Saindo do zero';
    return 'Início da jornada';
  }

  IconData _iconForKind(GoalKind kind) {
    switch (kind) {
      case GoalKind.objective:
        return Icons.flag_rounded;
      case GoalKind.project:
        return Icons.rocket_launch_rounded;
      case GoalKind.problem:
        return Icons.shield_moon_rounded;
      case GoalKind.habit:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgPercent = (_avgProgress * 100).toStringAsFixed(0);

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Missões da vida'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGoal,
        backgroundColor: const Color(0xFFA855F7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova missão'),
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
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2F1450), Color(0xFF12091E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFA855F7,
                          ).withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFFE9D5FF),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Painel de evolução',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Menos meta largada. Mais fase concluída.',
                                    style: TextStyle(
                                      color: Color(0xD9FFFFFF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _playerMood,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _goals.isEmpty
                                    ? 'Crie sua primeira missão para começar a sentir progresso real.'
                                    : 'Você está com $_activeCount missões ativas, $_completedCount concluídas e média de $avgPercent% de avanço.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _heroMetric(
                                label: 'XP total',
                                value: '$_totalXp',
                                icon: Icons.stars_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroMetric(
                                label: 'Ativas',
                                value: '$_activeCount',
                                icon: Icons.flash_on_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroMetric(
                                label: 'Quase lá',
                                value: '$_almostThereCount',
                                icon: Icons.whatshot_rounded,
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
                            icon: const Icon(Icons.add_circle_rounded),
                            label: const Text('Criar nova missão'),
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
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.flag_circle_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma missão aberta ainda',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pode ser aprender algo, resolver um problema, organizar uma área da vida ou parar de empurrar uma pendência com a barriga.',
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
                          xp: _xpForGoal(goal),
                          icon: _iconForKind(goal.kind),
                          statusText: _progressLabel(
                            goal.progress,
                            goal.status == GoalStatus.completed,
                          ),
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

  Widget _heroMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE9D5FF), size: 18),
          const SizedBox(height: 8),
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
    required this.xp,
    required this.icon,
    required this.statusText,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final String stage;
  final String nextAction;
  final double progress;
  final bool completed;
  final int xp;
  final IconData icon;
  final String statusText;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = completed
        ? const Color(0xFF22C55E)
        : const Color(0xFFA855F7);
    final percent = (progress * 100).toStringAsFixed(0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 10),
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
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniBadge('XP +$xp', accent),
                const SizedBox(width: 8),
                _miniBadge(statusText, Colors.white70),
              ],
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
                    'Fase atual',
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
                    'Próxima jogada: $nextAction',
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
                  ? '100% • missão finalizada'
                  : '$percent% • barra de evolução carregando',
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
