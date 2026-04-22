// ============================================================================
// FILE: lib/features/goals/presentation/pages/goals_hub_page.dart
//
// O que este arquivo faz:
// - Transforma "missões" em uma central de pendências da vida
// - Mistura tarefas rápidas, projetos grandes, objetivos e rotinas
// - Dá filtros úteis para hoje, próximas, atrasadas, projetos e concluídas
// - Mantém a base atual do módulo sem perder progresso já salvo
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

enum _GoalHubTab { inbox, today, upcoming, projects, done }

class _GoalsHubPageState extends State<GoalsHubPage> {
  final _repo = HiveGoalsRepository();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  _GoalHubTab _tab = _GoalHubTab.today;
  List<GoalPlanModel> _plans = const [];

  @override
  void initState() {
    super.initState();
    _reload();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final summaries = await _repo.listGoals();
    final plans = <GoalPlanModel>[];

    for (final item in summaries) {
      final plan = await _repo.loadGoal(item.id);
      if (plan != null) {
        plans.add(plan);
      }
    }

    plans.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));

    if (!mounted) return;
    setState(() {
      _plans = plans;
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

  Future<void> _quickComplete(GoalPlanModel plan) async {
    final doneMilestones = plan.milestones
        .map(
          (milestone) => milestone.copyWith(
            isDone: true,
            actions: milestone.actions
                .map((action) => action.copyWith(isDone: true))
                .toList(),
          ),
        )
        .toList();

    await _repo.saveGoal(
      plan.copyWith(
        milestones: doneMilestones,
        status: GoalStatus.completed,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        currentStageLabel: 'Concluído',
      ),
    );
    await _reload();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<GoalPlanModel> get _filteredPlans {
    final query = _searchCtrl.text.trim().toLowerCase();
    final now = _today;

    bool matchesQuery(GoalPlanModel plan) {
      if (query.isEmpty) return true;
      final text = [
        plan.title,
        plan.captureText,
        plan.whyItMatters,
        plan.currentStageLabel,
        plan.nextAction?.title ?? '',
      ].join(' ').toLowerCase();
      return text.contains(query);
    }

    bool matchesTab(GoalPlanModel plan) {
      switch (_tab) {
        case _GoalHubTab.inbox:
          return !plan.isCompleted;
        case _GoalHubTab.today:
          return !plan.isCompleted &&
              (plan.isOverdue(now) ||
                  plan.isDueSoon(now, withinDays: 2) ||
                  plan.isQuickTask);
        case _GoalHubTab.upcoming:
          return !plan.isCompleted &&
              !plan.isOverdue(now) &&
              plan.isDueSoon(now, withinDays: 14);
        case _GoalHubTab.projects:
          return !plan.isCompleted &&
              (plan.kind == GoalKind.project ||
                  plan.kind == GoalKind.objective);
        case _GoalHubTab.done:
          return plan.isCompleted;
      }
    }

    final items = _plans
        .where((plan) => matchesQuery(plan) && matchesTab(plan))
        .toList();

    items.sort((a, b) {
      final aOverdue = a.isOverdue(now) ? 1 : 0;
      final bOverdue = b.isOverdue(now) ? 1 : 0;
      if (aOverdue != bOverdue) return bOverdue.compareTo(aOverdue);

      final aDue = a.targetDateMs ?? 1 << 60;
      final bDue = b.targetDateMs ?? 1 << 60;
      if (aDue != bDue) return aDue.compareTo(bDue);

      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });

    return items;
  }

  int get _activeCount => _plans.where((item) => !item.isCompleted).length;
  int get _completedCount => _plans.where((item) => item.isCompleted).length;
  int get _overdueCount =>
      _plans.where((item) => item.isOverdue(_today)).length;
  int get _dueSoonCount => _plans
      .where(
        (item) =>
            !item.isOverdue(_today) && item.isDueSoon(_today, withinDays: 7),
      )
      .length;
  int get _quickCount =>
      _plans.where((item) => !item.isCompleted && item.isQuickTask).length;

  double get _avgProgress {
    final open = _plans.where((item) => !item.isCompleted).toList();
    if (open.isEmpty) return 0;
    final total = open.fold<double>(0, (sum, item) => sum + item.progress);
    return total / open.length;
  }

  String _kindLabel(GoalKind value) {
    switch (value) {
      case GoalKind.objective:
        return 'Objetivo';
      case GoalKind.project:
        return 'Projeto';
      case GoalKind.problem:
        return 'Pendência';
      case GoalKind.habit:
        return 'Rotina';
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

  Color _accentForGoal(GoalPlanModel goal) {
    if (goal.isCompleted) return const Color(0xFF22C55E);
    if (goal.isOverdue(_today)) return const Color(0xFFEF4444);
    if (goal.isDueSoon(_today, withinDays: 2)) return const Color(0xFFF59E0B);

    switch (goal.kind) {
      case GoalKind.objective:
        return const Color(0xFFA855F7);
      case GoalKind.project:
        return const Color(0xFF3B82F6);
      case GoalKind.problem:
        return const Color(0xFFF97316);
      case GoalKind.habit:
        return const Color(0xFF22C55E);
    }
  }

  IconData _iconForKind(GoalKind kind) {
    switch (kind) {
      case GoalKind.objective:
        return Icons.flag_rounded;
      case GoalKind.project:
        return Icons.account_tree_rounded;
      case GoalKind.problem:
        return Icons.checklist_rtl_rounded;
      case GoalKind.habit:
        return Icons.autorenew_rounded;
    }
  }

  String _dateLabel(int? ms) {
    if (ms == null) return 'Sem data';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _statusText(GoalPlanModel goal) {
    if (goal.isCompleted) return 'Concluído';
    if (goal.isOverdue(_today)) return 'Atrasado';
    if (goal.isDueSoon(_today, withinDays: 2)) return 'Perto do prazo';
    if (goal.isQuickTask) return 'Tarefa rápida';
    if (goal.progress >= 0.7) return 'Bem encaminhado';
    if (goal.progress > 0) return 'Em andamento';
    return 'Começar';
  }

  String _heroSentence() {
    if (_plans.isEmpty) {
      return 'Jogue aqui tudo que precisa resolver na vida: tarefa pequena, projeto grande, pendência esquecida ou objetivo de longo prazo.';
    }
    return 'Você está com $_activeCount itens ativos, $_overdueCount atrasados, $_dueSoonCount chegando perto do prazo e $_quickCount tarefas rápidas para destravar.';
  }

  @override
  Widget build(BuildContext context) {
    final avgPercent = (_avgProgress * 100).toStringAsFixed(0);
    final items = _filteredPlans;

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Objetivos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGoal,
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo item'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A2443), Color(0xFF0D1324)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
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
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: Color(0xFFDDE7FF),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Central da vida real',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tudo que você precisa resolver em um lugar só',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.82),
                                      fontWeight: FontWeight.w700,
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
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                          child: Text(
                            _heroSentence(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _heroMetric(
                                label: 'Ativos',
                                value: '$_activeCount',
                                icon: Icons.pending_actions_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroMetric(
                                label: 'Atrasados',
                                value: '$_overdueCount',
                                icon: Icons.notification_important_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _heroMetric(
                                label: 'Média',
                                value: '$avgPercent%',
                                icon: Icons.insights_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText:
                                'Buscar por título, texto bruto ou próxima ação',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.42),
                            ),
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(18),
                              ),
                              borderSide: BorderSide(
                                color: Color(0xFF7C3AED),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _hubTabChip(_GoalHubTab.inbox, 'Todos'),
                      _hubTabChip(_GoalHubTab.today, 'Hoje'),
                      _hubTabChip(_GoalHubTab.upcoming, 'Próximas'),
                      _hubTabChip(_GoalHubTab.projects, 'Projetos'),
                      _hubTabChip(_GoalHubTab.done, 'Concluídos'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10182B),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.inbox_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tab == _GoalHubTab.done
                                ? 'Nada concluído ainda'
                                : 'Nada apareceu nesse filtro',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _tab == _GoalHubTab.done
                                ? 'Quando você concluir itens da vida real, eles passam a morar aqui.'
                                : 'Crie um novo item ou troque o filtro. Pode ser uma tarefa rápida, um projeto grande ou uma rotina.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.74),
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...items.map(
                      (goal) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalSummaryCard(
                          title: goal.title,
                          subtitle:
                              '${_kindLabel(goal.kind)} • ${_areaLabel(goal.area)}',
                          stage: goal.currentMilestone?.title ?? 'Sem etapa',
                          nextAction:
                              goal.nextAction?.title ?? 'Sem próxima ação',
                          progress: goal.progress,
                          completed: goal.isCompleted,
                          icon: _iconForKind(goal.kind),
                          accent: _accentForGoal(goal),
                          statusText: _statusText(goal),
                          dueDateLabel: _dateLabel(goal.targetDateMs),
                          onTap: () => _openGoal(goal.id),
                          onDelete: () => _deleteGoal(goal.id),
                          onQuickDone: goal.isCompleted
                              ? null
                              : () => _quickComplete(goal),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _hubTabChip(_GoalHubTab tab, String label) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7C3AED)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF9F67FF)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(selected ? 0.96 : 0.74),
            fontWeight: FontWeight.w800,
          ),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFDDE7FF), size: 18),
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
              color: Colors.white.withOpacity(0.66),
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
    required this.icon,
    required this.accent,
    required this.statusText,
    required this.dueDateLabel,
    required this.onTap,
    required this.onDelete,
    this.onQuickDone,
  });

  final String title;
  final String subtitle;
  final String stage;
  final String nextAction;
  final double progress;
  final bool completed;
  final IconData icon;
  final Color accent;
  final String statusText;
  final String dueDateLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onQuickDone;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toStringAsFixed(0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
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
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(0.22)),
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
                    if (value == 'done' && onQuickDone != null) onQuickDone!();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (!completed)
                      const PopupMenuItem(
                        value: 'done',
                        child: Text('Concluir agora'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniBadge(statusText, accent),
                _miniBadge('Prazo: $dueDateLabel', Colors.white70),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etapa atual',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.54),
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
                      color: Colors.white.withOpacity(0.72),
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
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              completed ? '100% • resolvido' : '$percent% • em andamento',
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
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
