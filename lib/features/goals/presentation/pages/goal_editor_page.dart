// ============================================================================
// FILE: lib/features/goals/presentation/pages/goal_editor_page.dart
//
// O que este arquivo faz:
// - Cria ou edita um item da vida real: tarefa, projeto, objetivo ou rotina
// - Aceita captura livre e rápida
// - Gera uma estrutura inicial útil para não deixar o usuário travado
// - Serve tanto para coisa pequena quanto para coisa grande
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/models/goals_models.dart';

class GoalEditorPage extends StatefulWidget {
  const GoalEditorPage({super.key, this.initialPlan});

  final GoalPlanModel? initialPlan;

  @override
  State<GoalEditorPage> createState() => _GoalEditorPageState();
}

class _GoalEditorPageState extends State<GoalEditorPage> {
  final _titleCtrl = TextEditingController();
  final _captureCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();

  GoalKind _kind = GoalKind.problem;
  GoalArea _area = GoalArea.pessoal;
  final List<_MilestoneDraft> _milestones = [];
  DateTime? _targetDate;

  bool get _editing => widget.initialPlan != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlan;
    if (initial != null) {
      _titleCtrl.text = initial.title;
      _captureCtrl.text = initial.captureText;
      _whyCtrl.text = initial.whyItMatters;
      _kind = initial.kind;
      _area = initial.area;
      if (initial.targetDateMs != null) {
        _targetDate = DateTime.fromMillisecondsSinceEpoch(
          initial.targetDateMs!,
        );
      }
      for (final milestone in initial.milestones) {
        _milestones.add(
          _MilestoneDraft(
            title: milestone.title,
            description: milestone.description,
            actions: milestone.actions.map((item) => item.title).toList(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captureCtrl.dispose();
    _whyCtrl.dispose();
    super.dispose();
  }

  String _newId() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch;
    final r = math.Random(ms).nextInt(99999).toString().padLeft(5, '0');
    return '$ms$r';
  }

  void _addMilestone() {
    setState(() {
      _milestones.add(
        _MilestoneDraft(title: '', description: '', actions: ['']),
      );
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  void _clearDate() {
    setState(() => _targetDate = null);
  }

  void _generateSuggestion() {
    final title = _titleCtrl.text.trim();
    final capture = _captureCtrl.text.trim();

    final suggestions = _suggestMilestones(
      title: title,
      capture: capture,
      kind: _kind,
    );
    setState(() {
      _milestones
        ..clear()
        ..addAll(suggestions);
    });
  }

  List<_MilestoneDraft> _suggestMilestones({
    required String title,
    required String capture,
    required GoalKind kind,
  }) {
    final text = '${title.toLowerCase()} ${capture.toLowerCase()}';

    if (kind == GoalKind.problem) {
      return [
        _MilestoneDraft(
          title: 'Resolver',
          description:
              'A menor forma possível de tirar isso da cabeça e levar para o mundo real.',
          actions: [
            if (title.trim().isNotEmpty)
              title.trim()
            else
              'Executar a pendência',
          ],
        ),
      ];
    }

    if (text.contains('casa') ||
        text.contains('constru') ||
        text.contains('obra')) {
      return [
        _MilestoneDraft(
          title: 'Planejamento base',
          description:
              'Entender custo, formato e viabilidade antes de sair comprando ou fechando serviço.',
          actions: [
            'Definir o que a casa precisa ter',
            'Levantar materiais principais',
            'Pesquisar faixa de custo inicial',
          ],
        ),
        _MilestoneDraft(
          title: 'Orçamento e fornecedores',
          description: 'Comparar preço e não decidir no escuro.',
          actions: [
            'Pedir orçamento de material',
            'Ver pedreiro / mão de obra',
            'Separar planilha simples de custos',
          ],
        ),
        _MilestoneDraft(
          title: 'Execução por etapas',
          description: 'Quebrar a obra para não virar um monstro sem fim.',
          actions: [
            'Definir primeira etapa da obra',
            'Reservar valor mínimo para começar',
            'Marcar a próxima decisão importante',
          ],
        ),
      ];
    }

    if (text.contains('médic') ||
        text.contains('consulta') ||
        text.contains('fono')) {
      return [
        _MilestoneDraft(
          title: 'Agendamento',
          description: 'Resolver o contato e garantir a data.',
          actions: [
            'Procurar número ou local',
            'Enviar mensagem ou ligar',
            'Salvar data e horário',
          ],
        ),
        _MilestoneDraft(
          title: 'Preparação',
          description: 'Chegar na consulta sem esquecer o que precisa.',
          actions: [
            'Separar documentos ou exames',
            'Anotar dúvidas principais',
          ],
        ),
      ];
    }

    if (text.contains('costur') ||
        text.contains('calça') ||
        text.contains('barbeador') ||
        text.contains('comprar')) {
      return [
        _MilestoneDraft(
          title: 'Resolver isso logo',
          description: 'Pendência pequena, ideal para destravar rápido.',
          actions: [
            title.trim().isNotEmpty ? title.trim() : 'Resolver a pendência',
          ],
        ),
      ];
    }

    return [
      _MilestoneDraft(
        title: 'Entender melhor',
        description: 'Clareza antes de sair fazendo qualquer coisa.',
        actions: [
          'Escrever a primeira decisão que preciso tomar',
          'Escolher o menor próximo passo possível',
        ],
      ),
      _MilestoneDraft(
        title: 'Executar',
        description: 'Levar do papel para a prática.',
        actions: ['Fazer a próxima ação', 'Registrar o que falta depois disso'],
      ),
    ];
  }

  GoalPlanModel _buildPlan() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = widget.initialPlan?.id ?? _newId();

    final milestones = <GoalMilestoneModel>[];
    for (var i = 0; i < _milestones.length; i++) {
      final draft = _milestones[i];
      final actions = draft.actions
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      if (draft.title.trim().isEmpty && actions.isEmpty) continue;

      milestones.add(
        GoalMilestoneModel(
          id: 'm_${i + 1}_$id',
          title: draft.title.trim().isEmpty
              ? 'Etapa ${i + 1}'
              : draft.title.trim(),
          description: draft.description.trim(),
          order: i,
          isDone: false,
          actions: List.generate(
            actions.length,
            (index) => GoalActionModel(
              id: 'a_${i + 1}_${index + 1}_$id',
              title: actions[index],
              isDone: false,
              createdAtMs: now,
            ),
          ),
        ),
      );
    }

    if (milestones.isEmpty) {
      milestones.add(
        GoalMilestoneModel(
          id: 'm_1_$id',
          title: _kind == GoalKind.problem ? 'Resolver' : 'Primeiro avanço',
          description: _kind == GoalKind.problem
              ? 'Pendência mínima para sair da cabeça.'
              : 'Saída mínima do zero.',
          order: 0,
          isDone: false,
          actions: [
            GoalActionModel(
              id: 'a_1_1_$id',
              title: _titleCtrl.text.trim().isEmpty
                  ? 'Definir a próxima ação'
                  : _titleCtrl.text.trim(),
              isDone: false,
              createdAtMs: now,
            ),
          ],
        ),
      );
    }

    return GoalPlanModel(
      id: id,
      title: _titleCtrl.text.trim().isEmpty
          ? 'Novo item'
          : _titleCtrl.text.trim(),
      captureText: _captureCtrl.text.trim(),
      kind: _kind,
      area: _area,
      status: GoalStatus.active,
      createdAtMs: widget.initialPlan?.createdAtMs ?? now,
      updatedAtMs: now,
      milestones: milestones,
      whyItMatters: _whyCtrl.text.trim(),
      currentStageLabel: milestones.first.title,
      targetDateMs: _targetDate == null
          ? widget.initialPlan?.targetDateMs
          : DateTime(
              _targetDate!.year,
              _targetDate!.month,
              _targetDate!.day,
            ).millisecondsSinceEpoch,
    );
  }

  void _save() {
    final plan = _buildPlan();
    Navigator.of(context).pop(plan);
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

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Sem prazo';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_editing ? 'Editar item' : 'Novo item'),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10182B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: const Text(
              'Jogue aqui qualquer coisa que você precisa resolver: tarefa pequena, consulta, compra, pendência chata, problema da empresa ou projeto grande.',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Nome principal',
              'Ex: marcar fono / construir minha casa',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captureCtrl,
            minLines: 4,
            maxLines: 7,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Texto bruto',
              'Escreva do seu jeito: tudo que precisa, o que está envolvido, o que está travando, o que não quer esquecer...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whyCtrl,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Por que isso importa',
              'O que muda na sua vida quando isso for resolvido?',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<GoalKind>(
                  value: _kind,
                  dropdownColor: const Color(0xFF10182B),
                  decoration: _input('Tipo', ''),
                  items: GoalKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_kindLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _kind = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<GoalArea>(
                  value: _area,
                  dropdownColor: const Color(0xFF10182B),
                  decoration: _input('Área', ''),
                  items: GoalArea.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_areaLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _area = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Prazo: ${_dateLabel(_targetDate)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: const Text('Escolher'),
                ),
                if (_targetDate != null)
                  TextButton.icon(
                    onPressed: _clearDate,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Limpar'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generateSuggestion,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Gerar estrutura'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _addMilestone,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Etapa'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_milestones.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Text(
                'Ainda não existem etapas. Gere uma base automática ou crie manualmente. Para pendência pequena, uma etapa com uma ação já resolve.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ...List.generate(_milestones.length, (index) {
            final item = _milestones[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MilestoneEditorCard(
                index: index,
                draft: item,
                onChanged: () => setState(() {}),
                onRemove: () {
                  setState(() => _milestones.removeAt(index));
                },
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_editing ? 'Salvar alterações' : 'Salvar item'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint.isEmpty ? null : hint,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.78)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.38)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.6),
      ),
    );
  }
}

class _MilestoneDraft {
  _MilestoneDraft({
    required this.title,
    required this.description,
    required this.actions,
  });

  String title;
  String description;
  List<String> actions;
}

class _MilestoneEditorCard extends StatelessWidget {
  const _MilestoneEditorCard({
    required this.index,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _MilestoneDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10182B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Etapa ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          TextFormField(
            initialValue: draft.title,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Nome da etapa'),
            onChanged: (value) {
              draft.title = value;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: draft.description,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Descrição curta'),
            onChanged: (value) {
              draft.description = value;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          ...List.generate(draft.actions.length, (actionIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: draft.actions[actionIndex],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Ação ${actionIndex + 1}',
                      ),
                      onChanged: (value) {
                        draft.actions[actionIndex] = value;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      draft.actions.removeAt(actionIndex);
                      onChanged();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.actions.add('');
                onChanged();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar ação'),
            ),
          ),
        ],
      ),
    );
  }
}
