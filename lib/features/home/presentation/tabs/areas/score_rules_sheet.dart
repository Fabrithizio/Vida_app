// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/score_rules_sheet.dart
//
// O que faz:
// - Mostra ao usuário, de forma curta e clara, como o score do Areas funciona
// - Explica fontes de dados, cálculo por subárea e cálculo do score geral
// - Aumenta a confiança no app sem mudar o layout principal
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
                title: '1. O score nasce das subáreas',
                text:
                    'Cada área é formada por subáreas. Exemplo: Finanças usa renda, gastos, fluxo do mês, orçamento, dívidas e reserva.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '2. Só entra no cálculo o que tem dado',
                text:
                    'Se uma subárea ainda não tem informação suficiente, ela não entra na média. Isso evita pontuação falsa.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '3. O app usa fontes diferentes',
                text:
                    'Hoje o sistema pode usar check-in diário, dados salvos no app, registros manuais e dados do módulo de Finanças.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '4. Cada subárea vira uma nota',
                text:
                    'Ótimo ≈ nota alta. Bom ≈ nota boa. Atenção ≈ nota média. Crítico ≈ nota baixa. Depois a área tira uma média dessas subáreas.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '5. O score geral é a média das áreas',
                text:
                    'O número principal no topo resume como suas áreas estão agora, usando apenas as áreas que já têm dados válidos.',
              ),
              const SizedBox(height: 10),
              const _RuleCard(
                title: '6. Nem tudo é automático ainda',
                text:
                    'Algumas subáreas já estão ligadas ao app agora. Outras já fazem sentido no sistema, mas serão conectadas a novos módulos e integrações nas próximas etapas.',
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
                  'Resumo rápido: o score não tenta adivinhar sua vida. Ele usa os dados que o app já tem, ignora o que ainda está sem base e recalcula conforme você usa o sistema.',
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
