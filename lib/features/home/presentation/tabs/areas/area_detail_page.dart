// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/area_detail_page.dart
//
// Detalhe da área (novo sistema):
// - READ-ONLY (remove escolha manual ótimo/bom/ruim)
// - Mostra subáreas/sinais previstos (por enquanto só lista)
// - Pontuação/estado será calculada automaticamente pelo motor (próxima etapa)
// ============================================================================

import 'package:flutter/material.dart';

import 'areas_catalog.dart';

class AreaDetailPage extends StatelessWidget {
  const AreaDetailPage({super.key, required this.areaId, required this.title});

  final String areaId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final def = AreasCatalog.byId(areaId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
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
          ...def.items.map(
            (it) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                it.title,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'O status/score desta área será calculado automaticamente com base nos dados do app (finanças, metas, tarefas, check-ins, eventos recorrentes).',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
