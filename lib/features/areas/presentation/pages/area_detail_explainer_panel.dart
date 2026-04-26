// ============================================================================
// FILE: lib/features/areas/presentation/pages/area_detail_explainer_panel.dart
//
// O que faz:
// - Mostra um resumo visual da lógica da subárea
// - Explica origem, recência, leitura atual e próxima ação
// - Mantém o conteúdo claro, bonito e sem poluição visual
//
// Ajustes desta versão:
// - melhora o visual interno do painel de explicação
// - usa chips e blocos visuais mais organizados
// - evita o visual simples demais do texto cru
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
    final sourceLabel = explainer.sourceLabel(assessment.source);
    final sourceDescription = explainer.sourceDescription(assessment.source);
    final recencyLabel = explainer.recencyLabel(daysSinceUpdate);
    final recencyDescription = explainer.decayDescription(daysSinceUpdate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetaCard(
                  icon: Icons.hub_rounded,
                  title: 'Origem',
                  value: sourceLabel,
                  description: sourceDescription,
                  color: const Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaCard(
                  icon: Icons.schedule_rounded,
                  title: 'Recência',
                  value: recencyLabel,
                  description: recencyDescription,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TextBlock(
              icon: Icons.visibility_rounded,
              title: 'Leitura atual',
              text: reason,
              color: const Color(0xFF34D399),
            ),
          ],
          if (recommendedAction.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TextBlock(
              icon: Icons.flag_rounded,
              title: 'Próxima ação',
              text: recommendedAction,
              color: const Color(0xFFA3E635),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
