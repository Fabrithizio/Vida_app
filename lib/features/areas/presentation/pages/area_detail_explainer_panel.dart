// ============================================================================
// FILE: lib/features/areas/presentation/pages/area_detail_explainer_panel.dart
//
// O que faz:
// - Mostra um resumo padronizado da origem do score de uma subárea
// - Usa o AreasScoreExplainer em vez de textos antigos espalhados
// - Deixa a tela de detalhe mais alinhada com o sistema novo
//
// Correção desta revisão:
// - trata reason como nullable
// - evita trim() em valor nulo
// - evita passar String? para onde a UI espera String
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/features/areas/application/scoring/areas_score_explainer.dart';

class AreaDetailExplainerPanel extends StatelessWidget {
  const AreaDetailExplainerPanel({
    super.key,
    required this.assessment,
    required this.title,
  });

  final AreaAssessment assessment;
  final String title;

  @override
  Widget build(BuildContext context) {
    final explainer = const AreasScoreExplainer();
    final now = DateTime.now();
    final lastUpdatedAt = assessment.lastUpdatedAt;
    final daysSinceUpdate = lastUpdatedAt == null
        ? 999
        : now.difference(lastUpdatedAt).inDays;

    final reason = (assessment.reason ?? '').trim();
    final recommendedAction = (assessment.recommendedAction ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _RowItem(
            label: 'Origem',
            value: explainer.sourceLabel(assessment.source),
          ),
          const SizedBox(height: 6),
          Text(
            explainer.sourceDescription(assessment.source),
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 10),
          _RowItem(
            label: 'Recência',
            value: explainer.recencyLabel(daysSinceUpdate),
          ),
          const SizedBox(height: 6),
          Text(
            explainer.decayDescription(daysSinceUpdate),
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Leitura atual',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
          if (recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Próxima ação',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              recommendedAction,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
