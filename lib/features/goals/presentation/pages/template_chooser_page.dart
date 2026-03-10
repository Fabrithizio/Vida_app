// lib/features/goals/presentation/pages/template_chooser_page.dart
import 'package:flutter/material.dart';
import '../../data/models/goal_tree_models.dart';
import '../../templates/goal_tree_templates.dart';
import 'custom_goal_wizard_page.dart';

sealed class GoalTreeLaunch {
  const GoalTreeLaunch();
}

class GoalTreeLaunchTemplate extends GoalTreeLaunch {
  const GoalTreeLaunchTemplate(this.templateId);
  final String templateId;
}

class GoalTreeLaunchCustom extends GoalTreeLaunch {
  const GoalTreeLaunchCustom(this.initialState);
  final GoalTreeStateModel initialState;
}

class GoalTemplateChooserPage extends StatelessWidget {
  const GoalTemplateChooserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_TemplateItem>[
      _TemplateItem(
        kind: _TemplateKind.template,
        value: GoalTreeTemplates.medicoV1,
        title: 'Ser médico',
        subtitle: 'Template inicial (v1) com etapas principais.',
        icon: Icons.medical_information_outlined,
      ),
      _TemplateItem(
        kind: _TemplateKind.template,
        value: 'habitos_v1',
        title: 'Hábitos (genérico)',
        subtitle: 'Um caminho simples para metas do dia a dia.',
        icon: Icons.auto_awesome_outlined,
      ),
      _TemplateItem(
        kind: _TemplateKind.template,
        value: 'idioma_v1',
        title: 'Aprender um idioma',
        subtitle: 'Base → prática → fluência.',
        icon: Icons.language_outlined,
      ),
      _TemplateItem(
        kind: _TemplateKind.custom,
        value: 'custom',
        title: 'Meta personalizada',
        subtitle: 'Você cola os passos e o app gera a árvore automaticamente.',
        icon: Icons.edit_road_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Escolher template')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = items[i];
          return Card(
            child: ListTile(
              leading: Icon(t.icon),
              title: Text(t.title),
              subtitle: Text(t.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (t.kind == _TemplateKind.template) {
                  Navigator.of(
                    context,
                  ).pop<GoalTreeLaunch>(GoalTreeLaunchTemplate(t.value));
                  return;
                }

                final custom = await Navigator.of(context)
                    .push<GoalTreeStateModel?>(
                      MaterialPageRoute(
                        builder: (_) => const CustomGoalWizardPage(),
                      ),
                    );

                if (custom == null) return;
                Navigator.of(
                  context,
                ).pop<GoalTreeLaunch>(GoalTreeLaunchCustom(custom));
              },
            ),
          );
        },
      ),
    );
  }
}

enum _TemplateKind { template, custom }

class _TemplateItem {
  const _TemplateItem({
    required this.kind,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final _TemplateKind kind;
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
}
