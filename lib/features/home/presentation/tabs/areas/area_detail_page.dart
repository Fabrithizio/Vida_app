// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/area_detail_page.dart
//
// O que faz:
// - Mostra os sinais/subáreas de uma área específica
// - Busca o status dinâmico de cada subárea no AreasStore
// - Esconde women_cycle para perfis que não devem ver esse item
// - Abre um bottom sheet com explicação, fonte do dado e ação recomendada
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/area_status_dot.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';

class AreaDetailPage extends StatefulWidget {
  const AreaDetailPage({
    super.key,
    required this.areaId,
    required this.title,
    required this.includeWomenCycle,
  });

  final String areaId;
  final String title;
  final bool includeWomenCycle;

  @override
  State<AreaDetailPage> createState() => _AreaDetailPageState();
}

class _AreaDetailPageState extends State<AreaDetailPage> {
  final AreasStore _store = AreasStore();

  @override
  void initState() {
    super.initState();
    _store.ensureBootstrappedFromOnboarding().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _statusTitle(AreaStatus? status) {
    return status?.label ?? 'Sem dados';
  }

  String _sourceLabel(AreaDataSource source) {
    final raw = source.toString().split('.').last;

    const labels = {
      'dailyCheckin': 'Check-in diário',
      'screenTime': 'Tempo de tela do aparelho',
      'sleep': 'Sono registrado no app',
      'financeSystem': 'Sistema de finanças do app',
      'lastCheckup': 'Data do último check-up',
      'manual': 'Registro manual do usuário',
      'onboarding': 'Dados iniciais do perfil',
      'unknown': 'Fonte não identificada',
    };

    return labels[raw] ?? raw;
  }

  String _fallbackExplain(String itemTitle) {
    return 'Essa subárea ainda não tem uma coleta automática completa. '
        'Ela permanece visível porque faz parte da lógica da área e pode ser '
        'ligada a dados do próprio app nas próximas etapas.';
  }

  String _explain(String areaId, String itemId, AreaAssessment? a) {
    if (a == null) {
      return 'Sem dados ainda. Conforme você usar o app e alimentar as fontes '
          'dessa subárea, o score passa a ser calculado aqui.';
    }

    if (areaId == 'body_health' && itemId == 'checkups') {
      switch (a.status) {
        case AreaStatus.excellent:
          return 'Seu check-up está em dia. O sistema usa a data do último '
              'registro para avaliar se esse cuidado continua recente.';
        case AreaStatus.good:
          return 'Seu check-up ainda está aceitável, mas já pede atenção para '
              'não ficar desatualizado.';
        case AreaStatus.attention:
        case AreaStatus.critical:
          return 'Faz bastante tempo desde o último check-up registrado. '
              'Atualizar essa data melhora a confiabilidade desta subárea.';
        case AreaStatus.noData:
          return 'Sem data suficiente para avaliar check-ups.';
      }
    }

    if (areaId == 'body_health' && itemId == 'sleep') {
      return 'Sono usa as horas registradas atualmente no app. Quanto mais '
          'próximo da faixa saudável, melhor tende a ficar o score.';
    }

    if (areaId == 'finance_material' && itemId == 'monthly_flow') {
      return 'Fluxo do mês compara entradas e saídas reais do mês atual. '
          'Se sobra dinheiro, a subárea sobe. Se sai mais do que entra, ela cai.';
    }

    if (areaId == 'digital_tech' && itemId == 'screen_time') {
      return 'Tempo de tela usa o valor salvo no app. Quanto menor e mais '
          'equilibrado o uso, melhor a pontuação.';
    }

    if (areaId == 'digital_tech' && itemId == 'distraction') {
      return 'Distrações é uma estimativa baseada no seu foco no check-in diário. '
          'Foco pior costuma indicar mais interferência digital.';
    }

    if (areaId == 'mind_emotion' && itemId == 'mental_load') {
      return 'Sobrecarga mental é uma estimativa baseada no estresse diário. '
          'Quando o estresse sobe, essa subárea tende a cair.';
    }

    if (areaId == 'work_vocation' && itemId == 'routine') {
      return 'Rotina usa o check-in diário sobre organização do dia. '
          'Constância e estrutura melhoram o score.';
    }

    if (areaId == 'learning_intellect' && itemId == 'study') {
      return 'Tempo de estudo usa o check-in diário de aprendizado. '
          'Quando há estudo recente, essa subárea melhora.';
    }

    if (areaId == 'relations_community' && itemId == 'social_contact') {
      return 'Contato social recente usa o check-in social do dia. '
          'Boas conexões recentes ajudam essa subárea.';
    }

    return (a.details ?? '').trim().isNotEmpty
        ? a.details!.trim()
        : _fallbackExplain(itemId);
  }

  Future<void> _openItemDetails(
    String areaId,
    String itemId,
    String title,
  ) async {
    final a = await _store.getComputedAssessment(areaId, itemId);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final status = a?.status;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AreaStatusDot(status: status, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _statusTitle(status),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _explain(areaId, itemId, a),
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                if ((a?.reason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBlock(title: 'Leitura atual', text: a!.reason!),
                ],
                if ((a?.recommendedAction ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoBlock(
                    title: 'Próxima ação',
                    text: a!.recommendedAction!,
                  ),
                ],
                if (a != null) ...[
                  const SizedBox(height: 10),
                  _InfoBlock(
                    title: 'Fonte usada',
                    text: _sourceLabel(a.source),
                  ),
                ],
                if (areaId == 'body_health' && itemId == 'checkups') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(sheetContext);
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: now,
                          firstDate: DateTime(now.year - 20),
                          lastDate: now,
                        );

                        if (picked == null) return;

                        await _store.updateLastCheckupDate(picked);

                        if (!mounted) return;

                        setState(() {});

                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      child: const Text('Atualizar data do check-up'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = AreasCatalog.byId(widget.areaId);
    final items = AreasCatalog.itemsForArea(
      def.id,
      includeWomenCycle: widget.includeWomenCycle,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Icon(def.icon, color: Colors.white70),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        def.subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sinais desta área',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((it) {
            return FutureBuilder<AreaAssessment?>(
              future: _store.getComputedAssessment(def.id, it.id),
              builder: (context, snap) {
                final a = snap.data;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openItemDetails(def.id, it.id, it.title),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        AreaStatusDot(status: a?.status, size: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                (a?.reason ?? 'Toque para ver detalhes'),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, height: 1.3),
          ),
        ],
      ),
    );
  }
}
