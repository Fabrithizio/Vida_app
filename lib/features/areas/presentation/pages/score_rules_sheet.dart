// ============================================================================
// FILE: lib/features/areas/presentation/pages/score_rules_sheet.dart
//
// O que faz:
// - Mostra o “livro de regras” do Areas em formato de bottom sheet
// - Explica o fluxo real do sistema de forma clara para o usuário
// - Resume de onde vêm os dados, como a nota nasce, como envelhece
//   e como o perfil vivo influencia as perguntas e prioridades
//
// Esta versão foi reescrita para refletir melhor o sistema atual:
// - perfil vivo adaptativo
// - perguntas diárias dinâmicas
// - pesos por fonte
// - cruzamento entre subáreas
// - persistência com envelhecimento do dado
// - leitura mais bonita, mais clara e menos “solta”
// ============================================================================

import 'package:flutter/material.dart';

class ScoreRulesSheet extends StatelessWidget {
  const ScoreRulesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
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
                    SizedBox(height: 8),
                    Text(
                      'O Areas tenta mostrar a sua realidade atual, não só uma impressão solta do dia. '
                      'Ele junta dados automáticos, uso real do app, registros manuais e perguntas diárias adaptativas para formar uma leitura viva do seu momento.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionTitle(
                icon: Icons.route_rounded,
                title: 'Fluxo do sistema',
                subtitle:
                    'A ordem abaixo mostra como o Areas pensa antes de desenhar uma nota na tela.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '1',
                title: 'O app observa sinais reais',
                text:
                    'Primeiro o sistema tenta ler o que já existe de forma concreta: '
                    'Health Connect, uso do aparelho, finanças lançadas, tarefas da casa, corpo e saúde, '
                    'histórico recente e registros feitos dentro do próprio app.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '2',
                title: 'O perfil vivo é recalculado',
                text:
                    'Depois o app monta um perfil atual do usuário. '
                    'Esse perfil não é um rótulo fixo: ele muda com o tempo conforme o uso, o histórico recente e os sinais reais do app.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '3',
                title: 'As perguntas do dia são escolhidas',
                text:
                    'O check-in diário não usa mais um bloco fixo. '
                    'O sistema escolhe perguntas mais úteis para aquele momento, tentando cobrir áreas importantes sem repetir demais.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '4',
                title: 'As respostas cruzam mais de uma área',
                text:
                    'Uma mesma resposta pode influenciar várias subáreas ao mesmo tempo. '
                    'Exemplo: estresse pode bater em mente, trabalho, recuperação e até na leitura geral da rotina.',
              ),
              const SizedBox(height: 10),
              const _StepCard(
                number: '5',
                title: 'A nota nasce e depois vira status visual',
                text:
                    'Cada subárea tenta chegar a uma nota de 0 a 100. '
                    'Depois disso o app converte a nota em um estado visual: ótimo, bom, médio, ruim, crítico ou sem dados.',
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.tune_rounded,
                title: 'Como a nota é formada',
                subtitle:
                    'O score não depende de uma única resposta. Ele mistura fonte, recência, consistência e completude.',
              ),
              const SizedBox(height: 8),
              const _RuleCard(
                icon: Icons.stacked_line_chart_rounded,
                title: 'Faixas visuais',
                text:
                    '• 80 a 100 = Ótimo\n'
                    '• 60 a 79 = Bom\n'
                    '• 40 a 59 = Médio\n'
                    '• 20 a 39 = Ruim\n'
                    '• 0 a 19 = Crítico\n'
                    '• Sem dado útil = cinza',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.verified_rounded,
                title: 'Peso da fonte',
                text:
                    'O app tenta confiar mais em dado automático e em informação real do próprio sistema. '
                    'Autorrelato continua valendo, mas normalmente entra com menos força do que um dado mais concreto.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.history_toggle_off_rounded,
                title: 'Recência do dado',
                text:
                    'Quanto mais atual for a informação, mais confiável ela tende a ser. '
                    'Dado recente pesa melhor. Dado velho continua existindo, mas perde força com o tempo.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.sync_alt_rounded,
                title: 'Consistência',
                text:
                    'O sistema olha se os sinais recentes fazem sentido entre si. '
                    'Se várias leituras próximas apontam para a mesma direção, a confiança sobe.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.dataset_rounded,
                title: 'Completude',
                text:
                    'Subáreas com mais sinais preenchidos ficam mais firmes. '
                    'Quando o app tem pouco material para julgar, ele tenta ser mais conservador.',
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.auto_graph_rounded,
                title: 'Persistência e envelhecimento',
                subtitle:
                    'O score não deveria sumir só porque o dia virou. O Areas guarda contexto.',
              ),
              const SizedBox(height: 8),
              const _RuleCard(
                icon: Icons.save_rounded,
                title: 'A nota persiste',
                text:
                    'Se uma subárea já teve dado válido, ela não volta para cinza no dia seguinte como se nada tivesse existido. '
                    'O histórico continua vivo.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.timelapse_rounded,
                title: 'O dado envelhece',
                text:
                    'Quando uma subárea fica tempo demais sem atualização, a leitura começa a perder força. '
                    'A ideia é evitar tanto o esquecimento instantâneo quanto uma nota congelada para sempre.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.trending_down_rounded,
                title: 'O objetivo do decaimento',
                text:
                    'O decaimento existe para lembrar que realidade atual precisa de sinal atual. '
                    'Se o usuário para de dar sinais, a certeza do app cai junto.',
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.person_search_rounded,
                title: 'Perfil vivo e perguntas adaptativas',
                subtitle: 'Esse é o coração do sistema novo.',
              ),
              const SizedBox(height: 8),
              const _RuleCard(
                icon: Icons.psychology_alt_rounded,
                title: 'Perfil vivo',
                text:
                    'O perfil vivo é a leitura atual do momento do usuário. '
                    'Ele usa onboarding, check-ins recentes e sinais reais do app. '
                    'Esse perfil ajuda a definir prioridades, sem deixar o usuário “trocar de perfil” manualmente quando quiser.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.quiz_rounded,
                title: 'Perguntas diárias dinâmicas',
                text:
                    'O sistema escolhe perguntas com base em:\n\n'
                    '• perfil atual\n'
                    '• áreas prioritárias\n'
                    '• histórico recente\n'
                    '• rotação para evitar repetição\n'
                    '• potencial de cruzamento entre subáreas',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.hub_rounded,
                title: 'Impactos cruzados',
                text:
                    'As respostas não vivem isoladas. '
                    'Uma mesma ação ou dificuldade pode melhorar uma subárea e piorar outra, dependendo do contexto. '
                    'Isso deixa a leitura menos rasa.',
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.dashboard_customize_rounded,
                title: 'Como cada área é lida hoje',
                subtitle:
                    'Resumo prático das fontes mais importantes de cada módulo.',
              ),
              const SizedBox(height: 8),
              const _AreaRuleCard(
                icon: Icons.favorite,
                title: 'Corpo & Saúde',
                body:
                    'Usa principalmente sinais reais do Health Connect e do módulo Corpo & Saúde.\n\n'
                    '• sono\n'
                    '• movimento\n'
                    '• energia\n'
                    '• alimentação\n'
                    '• hidratação\n'
                    '• IMC\n'
                    '• check-ups\n\n'
                    'Apps úteis de fitness e meditação podem reforçar levemente algumas leituras, mas nunca substituem dado real.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.psychology_rounded,
                title: 'Mente & Emoções',
                body:
                    'Cruza humor, estresse, foco e carga mental com sinais indiretos do resto do app.\n\n'
                    'Dinheiro, rotina, sono, distração, recuperação e uso noturno podem influenciar essa área. '
                    'Apps úteis como meditação e foco entram só como reforço leve.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Finanças & Material',
                body:
                    'Finanças depende principalmente dos dados reais do módulo financeiro.\n\n'
                    '• entradas\n'
                    '• saídas\n'
                    '• fluxo do mês\n'
                    '• orçamento\n'
                    '• dívidas\n'
                    '• reserva\n'
                    '• metas\n\n'
                    'Apps financeiros úteis podem reforçar a leitura, mas não valem mais do que movimentação real.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.work_rounded,
                title: 'Trabalho & Vocação',
                body:
                    'Lê rotina, consistência, execução do essencial e equilíbrio do dia. '
                    'É uma área fortemente alimentada pelo check-in adaptativo e pelo contexto recente.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.rocket_launch_rounded,
                title: 'Projetos & Progresso',
                body:
                    'Observa clareza, constância, ação prática e percepção de avanço. '
                    'Apps úteis de estudo e foco podem reforçar levemente esse entendimento.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.groups_rounded,
                title: 'Relações & Conexões',
                body:
                    'Usa convivência, apoio emocional, vínculo afetivo e presença social recente. '
                    'A nota nasce principalmente das respostas cruzadas e do contexto do usuário.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.autorenew_rounded,
                title: 'Hábitos & Constância',
                body:
                    'É uma das bases do sistema. '
                    'Olha repetição do básico, retorno ao eixo, autocontrole, estabilidade e manutenção da rotina.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.home_rounded,
                title: 'Ambiente & Casa',
                body:
                    'Depende principalmente das tarefas reais da casa.\n\n'
                    '• organização\n'
                    '• limpeza\n'
                    '• manutenção\n'
                    '• peso da casa\n\n'
                    'Pendência antiga, atraso e conclusão recente entram nessa leitura.',
              ),
              const SizedBox(height: 10),
              const _AreaRuleCard(
                icon: Icons.devices_rounded,
                title: 'Digital & Tecnologia',
                body:
                    'Usa o aparelho como fonte principal.\n\n'
                    '• tempo de tela\n'
                    '• redes sociais\n'
                    '• uso noturno\n\n'
                    'Apps úteis não criam subárea nova: eles só ajudam a interpretar melhor o uso digital quando fizer sentido.',
              ),
              const SizedBox(height: 16),
              const _SectionTitle(
                icon: Icons.fact_check_rounded,
                title: 'Resumo honesto',
                subtitle:
                    'Sem vender milagre. Só o que o sistema realmente tenta fazer hoje.',
              ),
              const SizedBox(height: 8),
              const _RuleCard(
                icon: Icons.verified_rounded,
                title: 'O que já está forte',
                text:
                    '• perfil vivo adaptativo\n'
                    '• perguntas diárias dinâmicas\n'
                    '• cruzamento entre subáreas\n'
                    '• mais uso de dado real\n'
                    '• persistência da nota\n'
                    '• leitura mais coerente do momento atual',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                icon: Icons.construction_rounded,
                title: 'O que ainda pode evoluir',
                text:
                    '• mais integrações automáticas\n'
                    '• ajustes finos de peso por subárea\n'
                    '• sinais internos ainda mais robustos\n'
                    '• explicações cada vez mais transparentes na interface',
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'Resumo rápido: o Areas tenta refletir sua realidade atual combinando o que você faz no app, o que o aparelho mostra, o que você responde e o que permanece coerente ao longo do tempo.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.text,
  });

  final String number;
  final String title;
  final String text;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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
