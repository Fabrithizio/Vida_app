// ============================================================================
// FILE: lib/features/goals/presentation/pages/goal_details_page.dart
//
// O que este arquivo faz:
// - Mostra o item da vida real já pronto para execução
// - Serve tanto para tarefa rápida quanto para projeto grande
// - Deixa claro prazo, etapa atual, próxima ação e checklist
// ============================================================================

import 'package:flutter/material.dart';

import '../../data/models/goals_models.dart';
import '../../data/repositories/goals_repository.dart';
import 'goal_editor_page.dart';

class GoalDetailsPage extends StatefulWidget {
  const GoalDetailsPage({
    super.key,
    required this.repository,
    required this.initialPlan,
  });

  final GoalsRepository repository;
  final GoalPlanModel initialPlan;

  @override
  State<GoalDetailsPage> createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<GoalDetailsPage> {
  late GoalPlanModel _plan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
  }

  Future<void> _persist(GoalPlanModel next) async {
    setState(() {
      _plan = next;
      _saving = true;
    });
    await widget.repository.saveGoal(next);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _toggleAction(int milestoneIndex, int actionIndex) async {
    final milestones = List<GoalMilestoneModel>.from(_plan.milestones);
    final milestone = milestones[milestoneIndex];
    final actions = List<GoalActionModel>.from(milestone.actions);

    final action = actions[actionIndex];
    actions[actionIndex] = action.copyWith(isDone: !action.isDone);

    final allDone = actions.isNotEmpty && actions.every((item) => item.isDone);
    milestones[milestoneIndex] = milestone.copyWith(
      actions: actions,
      isDone: allDone,
    );

    final doneEverything =
        milestones.isNotEmpty && milestones.every((item) => item.isDone);

    final next = _plan.copyWith(
      milestones: milestones,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      status: doneEverything ? GoalStatus.completed : GoalStatus.active,
      currentStageLabel: _nextStageLabel(milestones),
    );

    await _persist(next);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(action.isDone ? 'Ação reaberta.' : 'Ação concluída.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleMilestone(int milestoneIndex) async {
    final milestones = List<GoalMilestoneModel>.from(_plan.milestones);
    final milestone = milestones[milestoneIndex];
    final nextDone = !milestone.isDone;

    final nextActions = milestone.actions
        .map((item) => item.copyWith(isDone: nextDone))
        .toList();

    milestones[milestoneIndex] = milestone.copyWith(
      isDone: nextDone,
      actions: nextActions,
    );

    final doneEverything =
        milestones.isNotEmpty && milestones.every((item) => item.isDone);

    final next = _plan.copyWith(
      milestones: milestones,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      status: doneEverything ? GoalStatus.completed : GoalStatus.active,
      currentStageLabel: _nextStageLabel(milestones),
    );

    await _persist(next);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nextDone ? 'Etapa concluída.' : 'Etapa reaberta.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _nextStageLabel(List<GoalMilestoneModel> milestones) {
    for (final item in milestones) {
      if (!item.isDone) return item.title;
    }
    return milestones.isEmpty ? 'Sem etapa' : 'Concluído';
  }

  Future<void> _editPlan() async {
    final updated = await Navigator.of(context).push<GoalPlanModel>(
      MaterialPageRoute(builder: (_) => GoalEditorPage(initialPlan: _plan)),
    );

    if (updated == null) return;
    await _persist(
      updated.copyWith(updatedAtMs: DateTime.now().millisecondsSinceEpoch),
    );
  }

  Color _accentForStatus() {
    final now = DateTime.now();
    if (_plan.isCompleted) return const Color(0xFF22C55E);
    if (_plan.isOverdue(now)) return const Color(0xFFEF4444);
    if (_plan.isDueSoon(now, withinDays: 2)) return const Color(0xFFF59E0B);

    switch (_plan.kind) {
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

  String get _energyLabel {
    final now = DateTime.now();
    if (_plan.isCompleted) return 'Resolvido';
    if (_plan.isOverdue(now)) return 'Precisa atenção';
    if (_plan.isDueSoon(now, withinDays: 2)) return 'Prazo próximo';
    if (_plan.progress >= 0.80) return 'Reta final';
    if (_plan.progress >= 0.55) return 'Andando bem';
    if (_plan.progress >= 0.25) return 'Em movimento';
    return 'Começo';
  }

  String _dateLabel(int? ms) {
    if (ms == null) return 'Sem data definida';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentForStatus();
    final progressPercent = (_plan.progress * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);
    final nextAction = _plan.nextAction?.title ?? 'Sem próxima ação definida';

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_plan.title),
        actions: [
          IconButton(
            onPressed: _editPlan,
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.18), const Color(0xFF10182B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: accent.withOpacity(0.26)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(_kindLabel(_plan.kind), accent),
                    _pill(_areaLabel(_plan.area), Colors.white70),
                    _pill(_energyLabel, accent),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _plan.currentMilestone?.title ?? 'Sem etapa atual',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _plan.whyItMatters.isEmpty
                      ? 'Este item existe para te ajudar a parar de empurrar a vida com a barriga.'
                      : _plan.whyItMatters,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard('Progresso', '$progressPercent%'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        'Etapas',
                        '${_plan.doneMilestones}/${_plan.totalMilestones}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        'Ações',
                        '${_plan.doneActions}/${_plan.totalActions}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _infoCard('Próxima ação', nextAction)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard('Prazo', _dateLabel(_plan.targetDateMs)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _plan.progress,
                    minHeight: 12,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _plan.isCompleted
                      ? 'Barra cheia • item concluído'
                      : '$progressPercent% carregado • continue na próxima ação',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_plan.captureText.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10182B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anotação original',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _plan.captureText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          const Text(
            'Etapas e ações',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_plan.milestones.length, (index) {
            final milestone = _plan.milestones[index];
            final isCurrent =
                !milestone.isDone && _plan.currentMilestone?.id == milestone.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MilestoneCard(
                milestone: milestone,
                accent: accent,
                isCurrent: isCurrent,
                index: index,
                onToggleMilestone: () => _toggleMilestone(index),
                onToggleAction: (actionIndex) =>
                    _toggleAction(index, actionIndex),
              ),
            );
          }),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
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
            textAlign: TextAlign.center,
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

  Widget _infoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.accent,
    required this.isCurrent,
    required this.index,
    required this.onToggleMilestone,
    required this.onToggleAction,
  });

  final GoalMilestoneModel milestone;
  final Color accent;
  final bool isCurrent;
  final int index;
  final VoidCallback onToggleMilestone;
  final ValueChanged<int> onToggleAction;

  @override
  Widget build(BuildContext context) {
    final stageAccent = milestone.isDone
        ? const Color(0xFF22C55E)
        : isCurrent
        ? accent
        : Colors.white54;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10182B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: milestone.isDone || isCurrent
              ? stageAccent.withOpacity(0.28)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggleMilestone,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: stageAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: stageAccent.withOpacity(0.22)),
              ),
              child: Icon(
                milestone.isDone
                    ? Icons.check_circle_rounded
                    : isCurrent
                    ? Icons.play_circle_fill_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: stageAccent,
              ),
            ),
            title: Text(
              milestone.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              milestone.description.isEmpty
                  ? (milestone.actions.isEmpty
                        ? 'Sem ações'
                        : '${milestone.doneActions}/${milestone.totalActions} ações concluídas')
                  : milestone.description,
              style: TextStyle(color: Colors.white.withOpacity(0.64)),
            ),
            trailing: Text(
              '${(milestone.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: stageAccent, fontWeight: FontWeight.w900),
            ),
          ),
          if (milestone.actions.isNotEmpty)
            ...List.generate(milestone.actions.length, (index) {
              final action = milestone.actions[index];
              return CheckboxListTile(
                value: action.isDone,
                onChanged: (_) => onToggleAction(index),
                title: Text(
                  action.title,
                  style: TextStyle(
                    color: Colors.white,
                    decoration: action.isDone
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  action.isDone ? 'Concluído' : 'Ainda falta fazer',
                  style: TextStyle(color: Colors.white.withOpacity(0.54)),
                ),
                dense: true,
                activeColor: accent,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
        ],
      ),
    );
  }
}
