// ============================================================================
// FILE: lib/features/areas/presentation/pages/score_rules_sheet.dart
//
// O que faz:
// - Mostra o “livro de regras” do Areas em formato de bottom sheet
// - Explica como a nota de 0 a 100 é formada hoje
// - Deixa claro o que já é automático, o que é estimado e o que ainda é manual
// - Resume, por área, de onde vêm os dados e como o score reage
//
// Esta versão foi atualizada para o sistema atual:
// - perfil vivo do usuário
// - check-in adaptativo com 5 perguntas por dia
// - impactos cruzados entre subáreas
// - persistência com decaimento após 14 dias sem atualização
// - queda de 5% ao dia depois que o decaimento começa
// - volta para cinza quando o score morre até zero
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
                'Aqui está a lógica do app como ela funciona agora: perfil vivo, perguntas adaptativas, fontes cruzadas e decaimento quando os dados envelhecem.',
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
                    'Cada subárea tenta chegar em uma nota de 0 a 100. Só depois essa nota vira um estado visual.\n\n'
                    '• 80 a 100 = Ótimo\n'
                    '• 60 a 79 = Bom\n'
                    '• 40 a 59 = Médio\n'
                    '• 20 a 39 = Ruim\n'
                    '• 0 a 19 = Crítico\n'
                    '• Sem dado útil = cinza',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.auto_awesome_rounded,
                title: '2. O usuário tem um perfil vivo',
                text:
                    'O app monta um perfil atual com base no onboarding + histórico recente do check-in.\n\n'
                    'Esse perfil vivo muda conforme o uso e ajuda a escolher quais perguntas do dia têm mais sentido. Exemplos: Trabalhador em pressão, Retomando o eixo, Executor em progresso.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.quiz_rounded,
                title: '3. O check-in diário agora é adaptativo',
                text:
                    'O sistema escolhe 5 perguntas por dia, não um bloco fixo. A seleção considera:\n\n'
                    '• perfil atual\n'
                    '• áreas prioritárias\n'
                    '• histórico recente\n'
                    '• rotação para evitar repetição\n'
                    '• perguntas que conseguem cruzar mais de uma subárea',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.account_tree_rounded,
                title: '4. Uma resposta pode mexer em várias subáreas',
                text:
                    'As perguntas não são mais 100% isoladas. Uma resposta pode melhorar uma subárea e também afetar outra com peso menor.\n\n'
                    'Exemplo: pressão mental pode bater em estresse, sobrecarga mental e equilíbrio do trabalho ao mesmo tempo.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.verified_rounded,
                title: '5. Dados automáticos valem mais que autorrelato',
                text:
                    'O app tenta sempre priorizar:\n\n'
                    '• automático do relógio / Health Connect\n'
                    '• automático do aparelho\n'
                    '• integração confiável do próprio app\n'
                    '• manual assistido\n'
                    '• manual puro\n\n'
                    'Manual ainda vale, mas manda menos que dado real.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.update_rounded,
                title: '6. O score persiste e não some só porque virou o dia',
                text:
                    'Se uma subárea já teve dado, ela continua viva. O score fica salvo e não vira cinza no dia seguinte.\n\n'
                    'Ele só envelhece quando fica tempo demais sem atualização.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.timelapse_rounded,
                title: '7. O decaimento começa depois de 14 dias',
                text:
                    'Se uma subárea ficar 14 dias sem atualização, o decaimento começa.\n\n'
                    'Regra atual:\n'
                    '• até 14 dias = score preservado\n'
                    '• depois disso = cai 5% do valor por dia\n'
                    '• se o valor morrer até zero = volta para cinza',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.trending_up_rounded,
                title: '8. Tendência olha direção recente',
                text:
                    'Quando há histórico suficiente, o app compara o período mais recente com o anterior.\n\n'
                    '• 📈 Melhorando\n'
                    '• 📉 Piorando\n'
                    '• ➖ Estável',
              ),
              const SizedBox(height: 16),
              const Text(
                'Como cada área é lida hoje',
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
                    'Saúde saiu como fonte principal do check-in.\n\n'
                    'Hoje o foco é usar dados reais ou do próprio app:\n'
                    '• sono: Health Connect / fitness\n'
                    '• movimento: treino + atividade + passos quando houver\n'
                    '• energia: sono + movimento + passos\n'
                    '• alimentação e hidratação: fitness\n'
                    '• IMC: puxa do Corpo & Saúde\n'
                    '• check-ups: data registrada no app\n\n'
                    'Passos ajudam, mas não punem quem não tem relógio.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.psychology_rounded,
                title: 'Mente & Emoções',
                body:
                    'É uma das áreas mais alimentadas pelo check-in adaptativo.\n\n'
                    'Humor, estresse, foco e sobrecarga mental são lidos por perguntas cruzadas e sinais recentes. Dinheiro, rotina, apoio e distração podem influenciar essa área.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Finanças & Material',
                body:
                    'Finanças depende principalmente do módulo real de Finanças, não do check-in.\n\n'
                    'Entradas, saídas, fluxo do mês e orçamento vêm dos lançamentos reais. Dívidas, reserva e metas ainda podem depender de dado informado.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.work,
                title: 'Trabalho & Vocação',
                body:
                    'Rotina, consistência e equilíbrio hoje são fortemente alimentados pelo check-in adaptativo.\n\n'
                    'A área cruza perguntas sobre controle do dia, essencial feito, peso da rotina e estabilidade recente.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.rocket_launch_rounded,
                title: 'Projetos & Progresso',
                body:
                    'Planejamento, execução, constância e progresso são lidos por perguntas sobre clareza, ação real e percepção de avanço.\n\n'
                    'É uma área estimada, mas já com base mais robusta que antes.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.groups,
                title: 'Relações & Conexões',
                body:
                    'Família, amigos, vínculo afetivo e contato social recente são lidos principalmente por perguntas adaptativas.\n\n'
                    'A convivência em casa, apoio emocional e presença real ajudam a montar a nota.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.autorenew_rounded,
                title: 'Hábitos & Constância',
                body:
                    'Base da rotina, constância, recuperação e autocontrole hoje são um motor central do app.\n\n'
                    'Essa área cruza repetição do básico, retorno ao eixo, distrações e manutenção de limites.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.home,
                title: 'Ambiente & Casa',
                body:
                    'Ambiente & Casa depende principalmente das tarefas reais da casa.\n\n'
                    'Organização, limpeza, peso da casa e manutenção da casa usam volume de tarefas, atraso, conclusão recente e pendências antigas.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.devices,
                title: 'Digital & Tecnologia',
                body:
                    'Digital usa o aparelho como fonte principal.\n\n'
                    'Tempo de tela, uso noturno e redes sociais vêm do acesso de uso do Android. Distrações é uma leitura cruzada entre uso digital + foco + rotina.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Resumo honesto do sistema atual',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const _RuleCard(
                icon: Icons.verified_rounded,
                title: 'O que já está forte',
                text:
                    '• perfil vivo com nome\n'
                    '• 5 perguntas adaptativas por dia\n'
                    '• impactos cruzados entre subáreas\n'
                    '• Saúde mais baseada em dado real\n'
                    '• Finanças, Digital e Casa mais automáticos\n'
                    '• persistência com decaimento real',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.build_circle_rounded,
                title: 'O que ainda pode crescer',
                text:
                    '• mais integrações automáticas\n'
                    '• mais sinais cruzados internos do app\n'
                    '• perfis vivos ainda mais refinados\n'
                    '• ajustes finos de peso por subárea',
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
                  'Resumo rápido: o Areas agora tenta refletir a realidade atual do usuário com mais consistência, cruzando dados do app, dados automáticos e perguntas adaptativas, sem depender só de autorrelato puro.',
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
