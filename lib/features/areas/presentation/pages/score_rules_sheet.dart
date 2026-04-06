// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/score_rules_sheet.dart
//
// O que faz:
// - Mostra o “livro de regras” do Areas em formato de bottom sheet
// - Explica como a nota de 0 a 100 é formada hoje
// - Deixa claro o que já é automático, o que é estimado e o que ainda é manual
// - Resume, por área, de onde vêm os dados e como o score reage
//
// Esta versão foi atualizada para ficar coerente com o app atual:
// - régua 0–100 com 5 faixas reais
// - check-in com 5 perguntas por dia e histórico de 14 dias
// - Digital automático pelo uso do aparelho
// - Finanças com score gradual a partir de dados reais
// - Ambiente & Casa ligado às tarefas reais da casa
// - Hábitos & Constância explicado como área em transição
// ============================================================================

import 'package:flutter/material.dart';

class ScoreRulesSheet extends StatelessWidget {
  const ScoreRulesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: Colors.white12),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Livro de regras do Areas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Aqui está a lógica do app como ela funciona hoje: o que já é automático, o que é estimado e o que ainda depende de registro manual.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              const _RuleCard(
                icon: Icons.stacked_line_chart_rounded,
                title: '1. Primeiro vem a nota, depois o nome visual',
                text:
                    'Cada subárea tenta chegar em uma nota de 0 a 100. Só depois essa nota vira um estado visual. A régua atual é:\n\n'
                    '• 80 a 100 = Ótimo\n'
                    '• 60 a 79 = Bom\n'
                    '• 40 a 59 = Médio\n'
                    '• 20 a 39 = Ruim\n'
                    '• 0 a 19 = Crítico',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.calendar_today_rounded,
                title:
                    '2. O check-in diário usa 5 perguntas e histórico de 14 dias',
                text:
                    'Quando uma subárea é ligada ao check-in, o app usa até 5 perguntas por dia e olha o histórico recente de 14 dias. As respostas ficam na escala 0 a 4, depois são convertidas para uma nota de 0 a 100.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.update_rounded,
                title:
                    '3. Dias recentes valem mais e falta de registro pode derrubar a nota',
                text:
                    'Nas subáreas de check-in, os dias mais novos pesam mais. Se o app ficar alguns dias sem dado recente, a nota perde força aos poucos. Isso evita score congelado.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.trending_up_rounded,
                title: '4. Tendência mostra a direção recente',
                text:
                    'A tendência compara o período mais recente com o anterior.\n\n'
                    '• 📈 Melhorando = a média recente subiu\n'
                    '• 📉 Piorando = a média recente caiu\n'
                    '• ➖ Estável = mudou pouco',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.account_tree_rounded,
                title: '5. O score da área junta as subáreas com dados válidos',
                text:
                    'O score de cada área é a média ponderada das subáreas que já têm dado útil. Subárea sem dado não entra na conta. Algumas já têm peso maior que outras.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Como cada área é calculada hoje',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const _AreaRuleCard(
                icon: Icons.favorite,
                title: 'Corpo & Saúde',
                body:
                    'Hoje Corpo & Saúde está focado em sinais simples e testáveis do dia a dia.\n\n'
                    '• energia, sono, movimento, alimentação e hidratação usam histórico recente do check-in diário;\n'
                    '• check-ups usam a data do último check-up informada no app;\n'
                    '• ciclo menstrual aparece só quando fizer sentido para o perfil.\n\n'
                    'Na prática, esta área reage ao básico do dia a dia e também considera o tempo desde o último cuidado importante.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.psychology_rounded,
                title: 'Mente & Emoções',
                body:
                    'Humor, estresse e foco já são lidos principalmente pelo check-in diário. A sobrecarga mental hoje é uma leitura estimada, usando sinais próximos de estresse e recuperação.\n\n'
                    'É uma área que tenta refletir como sua cabeça está agora, não uma opinião fixa sobre você.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Finanças & Material',
                body:
                    'Esta é uma das áreas mais automáticas do app hoje. Ela já usa dados reais do módulo de Finanças para calcular score gradual, sem depender só de degraus fixos.\n\n'
                    '• renda e gastos usam lançamentos reais do mês;\n'
                    '• orçamento compara gasto real com limite manual;\n'
                    '• fluxo mensal olha sobra ou falta no mês;\n'
                    '• dívidas, reserva e metas ainda dependem mais de dados informados, mas a nota já tenta crescer ou cair de forma gradual.\n\n'
                    'Se faltar gasto real em “gastos”, o app ainda consegue usar apoio do check-in financeiro como fallback.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.work,
                title: 'Trabalho & Vocação',
                body:
                    'Hoje esta área já usa sinais recentes do check-in diário para as quatro subáreas.\n\n'
                    '• rotina e consistência usam rotina e planejamento;\n'
                    '• entrega usa foco, planejamento e ritmo recente;\n'
                    '• equilíbrio usa rotina, estresse e recuperação.\n\n'
                    'Ou seja: ela ainda não depende de timeline ou agenda, mas já consegue gerar nota de forma coerente.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.school_rounded,
                title: 'Aprendizado & Intelecto',
                body:
                    'Hoje todas as subáreas desta área já conseguem gerar nota por estimativa leve usando o histórico recente do check-in.\n\n'
                    '• estudo usa constância e qualidade;\n'
                    '• cursos, leitura, habilidades e revisão/prática derivam dos sinais recentes de estudo, foco e rotina.\n\n'
                    'Ainda é uma leitura estimada, mas já não fica só no manual.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.groups,
                title: 'Relações & Conexões',
                body:
                    'Hoje esta área usa sinais recentes do check-in social para gerar nota em todas as subáreas.\n\n'
                    '• contato social recente vem direto das perguntas sociais;\n'
                    '• família, amigos e relacionamento usam uma estimativa leve baseada em presença social, conexão e humor recente.\n\n'
                    'Não é leitura perfeita, mas já evita que a área fique cinza sem necessidade.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.autorenew_rounded,
                title: 'Hábitos & Constância',
                body:
                    'Hoje esta área já funciona como motor real, não só como catálogo.\n\n'
                    '• base da rotina combina rotina, planejamento, energia e ambiente;\n'
                    '• constância olha a repetição recente do básico;\n'
                    '• recuperação mistura sinais de recuperação mental, humor, estresse e sono.\n\n'
                    'Ela ainda pode evoluir, mas já gera nota de forma coerente.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.home,
                title: 'Ambiente & Casa',
                body:
                    'Esta área já começou a ficar automática de verdade.\n\n'
                    '• organização usa tarefas reais da casa da categoria de organização;\n'
                    '• limpeza usa tarefas reais da categoria de limpeza.\n\n'
                    'A nota considera:\n'
                    '• quantas tarefas existem;\n'
                    '• quantas estão concluídas;\n'
                    '• quantas foram concluídas na última semana;\n'
                    '• há quanto tempo aconteceu a última conclusão;\n'
                    '• penalidade por tarefa pendente antiga.\n\n'
                    'Pendências domésticas e manutenção também já entram nessa leitura, com base nas tarefas reais da casa.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.devices,
                title: 'Digital & Tecnologia',
                body:
                    'Hoje esta é a outra área bem automática do app. No Android, se você liberar o acesso de uso, o app lê o uso do aparelho e salva faixas de uso para:\n\n'
                    '• tempo de tela;\n'
                    '• redes sociais;\n'
                    '• uso noturno.\n\n'
                    'Além disso, a parte de distração digital também usa sinais do check-in diário. Assim, o digital mistura leitura real do aparelho com percepção recente do seu foco.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Leitura honesta do estado atual do app',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const _RuleCard(
                icon: Icons.verified_rounded,
                title: 'O que já está forte hoje',
                text:
                    '• score 0 a 100 com 5 faixas reais\n'
                    '• check-in com histórico recente\n'
                    '• Finanças com cálculo bem mais gradual\n'
                    '• Digital automático pelo uso do aparelho\n'
                    '• Casa já usando tarefas reais em várias subáreas',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.build_circle_rounded,
                title: 'O que ainda está em construção',
                text:
                    '• algumas leituras ainda são estimadas, não medições diretas\n'
                    '• check-ups e ciclo dependem mais de atualização manual\n'
                    '• o sistema ainda pode ganhar mais integrações fortes no futuro',
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'Resumo rápido: hoje o Areas já consegue dar nota para praticamente todas as partes centrais do app, usando histórico recente, sinais estimados e fontes automáticas quando elas existem. Ainda não é o ponto final, mas já está bem mais coerente e testável do que antes.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaRuleCard extends StatelessWidget {
  const _AreaRuleCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}
