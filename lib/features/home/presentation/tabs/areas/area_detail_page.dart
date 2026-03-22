// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/area_detail_page.dart
//
// O que faz:
// - Usa AreasStore.getComputedAssessment() para status dinâmico
// - Item "checkups": abre BottomSheet com explicação + editar data
// - Estrutura pronta para adicionar outros itens no mesmo padrão
// ============================================================================

import 'package:flutter/material.dart';

import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_status.dart';

import 'package:vida_app/features/home/presentation/tabs/areas/areas_catalog.dart';
import 'package:vida_app/features/home/presentation/tabs/areas/area_status_dot.dart';

class AreaDetailPage extends StatefulWidget {
  const AreaDetailPage({super.key, required this.areaId, required this.title});

  final String areaId;
  final String title;

  @override
  State<AreaDetailPage> createState() => _AreaDetailPageState();
}

class _AreaDetailPageState extends State<AreaDetailPage> {
  final AreasStore _store = AreasStore();

  @override
  void initState() {
    super.initState();
    _store.ensureBootstrappedFromOnboarding().then((_) {
      if (mounted) setState(() {});
    });
  }

  String _statusTitle(AreaStatus s) {
    switch (s) {
      case AreaStatus.otimo:
        return 'Ótimo';
      case AreaStatus.bom:
        return 'Atenção';
      case AreaStatus.ruim:
        return 'Crítico';
    }
  }

  String _explain(String areaId, String itemId, AreaAssessment? a) {
    if (a == null) {
      return 'Sem dados ainda. Preencha essa informação para o app calcular seu status.';
    }

    // CHECKUPS (regra principal do pedido)
    if (areaId == 'body_health' && itemId == 'checkups') {
      switch (a.status) {
        case AreaStatus.otimo:
          return 'Perfeito. Continue cuidando da sua saúde e mantendo seus check-ups em dia.\n\n${a.reason ?? ''}'
              .trim();
        case AreaStatus.bom:
          return 'Fique atento(a). Está na hora de planejar seu próximo check-up para não deixar passar.\n\n${a.reason ?? ''}'
              .trim();
        case AreaStatus.ruim:
          return 'Importante: faz bastante tempo desde o último check-up. Se possível, agende uma avaliação.\n\n${a.reason ?? ''}'
              .trim();
      }
    }

    // Outros exemplos (fáceis de expandir)
    if (areaId == 'body_health' && itemId == 'sleep') {
      switch (a.status) {
        case AreaStatus.otimo:
          return 'Ótimo sono. Manter 7h+ ajuda humor, foco e saúde.\n\n${a.reason ?? ''}'
              .trim();
        case AreaStatus.bom:
          return 'Sono ok, mas dá pra melhorar. Tente ajustar rotina e horários.\n\n${a.reason ?? ''}'
              .trim();
        case AreaStatus.ruim:
          return 'Sono muito baixo. Isso impacta energia e saúde. Ajuste aos poucos.\n\n${a.reason ?? ''}'
              .trim();
      }
    }

    if (areaId == 'digital_tech' && itemId == 'screen_time') {
      switch (a.status) {
        case AreaStatus.otimo:
          return 'Tempo de tela bem controlado. Continue assim.\n\n${a.reason ?? ''}'
              .trim();
        case AreaStatus.bom:
          return 'Moderado. Se estiver atrapalhando sono/foco, reduza um pouco.\n\n${a.reason ?? ''}'
              .trim();
        case AreaStatus.ruim:
          return 'Alto. Pode afetar sono, foco e ansiedade. Tente reduzir gradualmente.\n\n${a.reason ?? ''}'
              .trim();
      }
    }

    return (a.reason ?? '').trim().isEmpty
        ? 'Status calculado. Em breve teremos mais detalhes aqui.'
        : a.reason!.trim();
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
      builder: (_) {
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
                    if (status != null)
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
                const SizedBox(height: 14),

                // ✅ Só checkups tem edição de data por enquanto
                if (areaId == 'body_health' && itemId == 'checkups') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(now.year - 20),
                          lastDate: now,
                        );

                        if (picked == null) return;

                        await _store.updateLastCheckupDate(picked);
                        if (mounted) setState(() {});
                        if (Navigator.of(context).canPop())
                          Navigator.of(context).pop();
                      },
                      child: const Text('Atualizar data do check-up'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

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
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final def = AreasCatalog.byId(widget.areaId);

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

          ...def.items.map((it) {
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
