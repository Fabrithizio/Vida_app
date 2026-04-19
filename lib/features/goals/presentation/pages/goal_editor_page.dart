// ============================================================================
// FILE: lib/features/goals/presentation/pages/goal_editor_page.dart
//
// O que este arquivo faz:
// - Cria ou edita uma meta/projeto/problema da nova central
// - Aceita captura livre
// - Quebra em marcos e próximas ações
// - Sugere um plano inicial automaticamente para não deixar o usuário travado
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

  GoalKind _kind = GoalKind.objective;
  GoalArea _area = GoalArea.pessoal;
  final List<_MilestoneDraft> _milestones = [];

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

  void _generateSuggestion() {
    final title = _titleCtrl.text.trim();
    final capture = _captureCtrl.text.trim();

    final suggestions = _suggestMilestones(title: title, capture: capture);
    setState(() {
      _milestones
        ..clear()
        ..addAll(suggestions);
    });
  }

  List<_MilestoneDraft> _suggestMilestones({
    required String title,
    required String capture,
  }) {
    final text = '${title.toLowerCase()} ${capture.toLowerCase()}';

    if (text.contains('cozin')) {
      return [
        _MilestoneDraft(
          title: 'Montar a base',
          description: 'Tirar a trava inicial e entender por onde começar.',
          actions: [
            'Escolher 3 pratos simples que quero aprender',
            'Ver 1 vídeo curto de básicos de cozinha',
            'Anotar utensílios que estão faltando',
          ],
        ),
        _MilestoneDraft(
          title: 'Dominar o simples',
          description: 'Ganhar confiança com refeições básicas.',
          actions: [
            'Fazer arroz sozinho',
            'Fazer ovo de 2 jeitos',
            'Fazer macarrão sem ajuda',
          ],
        ),
        _MilestoneDraft(
          title: 'Criar rotina mínima',
          description:
              'Transformar habilidade em algo que acontece de verdade.',
          actions: [
            'Cozinhar 1 refeição completa na semana',
            'Separar 1 dia fixo para praticar',
            'Repetir as receitas que deram certo',
          ],
        ),
      ];
    }

    if (text.contains('organizar') ||
        text.contains('bagun') ||
        text.contains('área de serviço') ||
        text.contains('area de serviço')) {
      return [
        _MilestoneDraft(
          title: 'Entender o caos',
          description: 'Ver o que existe e o que precisa sair.',
          actions: [
            'Tirar foto do espaço atual',
            'Separar o que fica, sai ou precisa de conserto',
            'Escolher uma pequena área para atacar primeiro',
          ],
        ),
        _MilestoneDraft(
          title: 'Criar ordem',
          description: 'Dar lugar para o que importa.',
          actions: [
            'Definir onde cada grupo de itens vai ficar',
            'Separar caixas/sacos para descarte e doação',
            'Limpar a primeira área escolhida',
          ],
        ),
        _MilestoneDraft(
          title: 'Fechar o sistema',
          description: 'Evitar voltar para a bagunça antiga.',
          actions: [
            'Finalizar o restante por blocos',
            'Criar regra simples de manutenção',
            'Fazer revisão rápida 1x por semana',
          ],
        ),
      ];
    }

    if (text.contains('empresa') ||
        text.contains('negócio') ||
        text.contains('negocio')) {
      return [
        _MilestoneDraft(
          title: 'Definir o problema real',
          description: 'Trocar preocupação solta por clareza.',
          actions: [
            'Escrever em uma frase o que precisa ser resolvido',
            'Listar o que está travando hoje',
            'Escolher o problema principal para atacar primeiro',
          ],
        ),
        _MilestoneDraft(
          title: 'Criar plano enxuto',
          description: 'Saber o próximo passo em vez de tentar resolver tudo.',
          actions: [
            'Separar o problema em 3 partes menores',
            'Definir o que pode ser feito esta semana',
            'Escolher 1 ação de alto impacto',
          ],
        ),
        _MilestoneDraft(
          title: 'Executar e revisar',
          description: 'Andar sem depender de perfeição.',
          actions: [
            'Executar a ação mais importante',
            'Revisar o resultado',
            'Definir o próximo movimento',
          ],
        ),
      ];
    }

    return [
      _MilestoneDraft(
        title: 'Clareza',
        description: 'Entender o que essa meta realmente significa.',
        actions: [
          'Escrever o objetivo de forma simples',
          'Definir por que isso importa agora',
          'Escolher o primeiro passo possível',
        ],
      ),
      _MilestoneDraft(
        title: 'Primeiro avanço',
        description: 'Sair da intenção e entrar em movimento.',
        actions: [
          'Executar uma ação pequena',
          'Remover um bloqueio óbvio',
          'Registrar o que funcionou',
        ],
      ),
      _MilestoneDraft(
        title: 'Constância',
        description: 'Continuar mesmo sem dia perfeito.',
        actions: [
          'Definir a próxima ação',
          'Criar um ritmo mínimo',
          'Revisar o objetivo no fim da semana',
        ],
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
          title: 'Primeiro avanço',
          description: 'Saída mínima do zero.',
          order: 0,
          isDone: false,
          actions: [
            GoalActionModel(
              id: 'a_1_1_$id',
              title: 'Definir a próxima ação',
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
          ? 'Nova meta'
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
      targetDateMs: widget.initialPlan?.targetDateMs,
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
        title: Text(_editing ? 'Editar objetivo' : 'Novo objetivo'),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: const Text(
              'Jogue aqui o que está travando sua cabeça. Depois o app ajuda a quebrar isso em etapas pequenas e próximas ações.',
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
            decoration: _input('Nome principal', 'Ex: aprender a cozinhar'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captureCtrl,
            minLines: 4,
            maxLines: 7,
            style: const TextStyle(color: Colors.white),
            decoration: _input(
              'Descarrego livre',
              'Escreva do seu jeito: problema, meta, confusão, vontade, trava, tudo junto...',
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
              'O que muda na sua vida quando isso andar?',
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generateSuggestion,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Gerar etapas'),
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
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Text(
                'Ainda não existem etapas. Você pode gerar um plano automático ou criar manualmente.',
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
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Salvar objetivo'),
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
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFFA855F7), width: 1.6),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                        labelText: 'Próxima ação ${actionIndex + 1}',
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
