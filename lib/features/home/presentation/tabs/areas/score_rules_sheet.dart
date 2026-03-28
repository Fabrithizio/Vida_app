// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/score_rules_sheet.dart
//
// O que faz:
// - Explica de forma curta e confiável como o score do Areas é calculado
// - Mostra as regras novas: score 0 a 100, histórico de 14 dias, decaimento
// - Explica tendência, fontes de dados e o que ainda será automático no futuro
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
              Row(
                children: const [
                  Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Como o score funciona',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _RuleCard(
                title: '1. Cada subárea recebe uma nota de 0 a 100',
                text:
                    'O app não usa mais só “ótimo” ou “ruim” como base. Primeiro ele calcula uma nota numérica. Depois essa nota vira um texto visual para facilitar a leitura.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '2. O histórico de 14 dias entra na conta',
                text:
                    'As subáreas ligadas ao check-in usam histórico recente. Assim, um único dia bom ou ruim não distorce tudo sozinho.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '3. Dias recentes valem mais',
                text:
                    'O sistema dá mais peso para os registros mais novos. Isso faz o score reagir mais rápido quando você melhora ou piora.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '4. Sem dado recente, a nota pode cair',
                text:
                    'Algumas subáreas têm decaimento. Se o sistema ficar muito tempo sem registro novo, a nota perde força aos poucos em vez de ficar congelada.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '5. Cada tipo de subárea usa uma lógica própria',
                text:
                    'Algumas usam respostas do check-in. Outras usam eventos, como check-up. E outras serão automáticas no futuro, como sono por relógio e tempo de tela pelo celular.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '6. Tendência mostra a direção recente',
                text:
                    '📈 melhorando = a média recente subiu\n📉 piorando = a média recente caiu\n➖ estável = mudou pouco',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '7. O score da área é formado pelas subáreas',
                text:
                    'Cada área junta as subáreas que já têm dados válidos. O sistema já está preparado para pesos diferentes no futuro, quando algumas partes passarem a valer mais que outras.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '8. Fontes usadas hoje e depois',
                text:
                    'Hoje o app usa check-in, registros do próprio sistema, datas salvas e o módulo de Finanças. Depois ele poderá usar fontes automáticas como smartwatch e dados do celular.',
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
                  'Resumo rápido: o score tenta refletir sua situação atual de forma gradual. Ele olha o histórico recente, reage ao que mudou e evita notas exageradas por causa de um único dia.',
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
  const _RuleCard({required this.title, required this.text});

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
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}
