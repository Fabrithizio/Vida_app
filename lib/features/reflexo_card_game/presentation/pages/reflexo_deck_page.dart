// lib/features/reflexo_card_game/presentation/pages/reflexo_deck_page.dart

import 'package:flutter/material.dart';

import '../../domain/reflexo_content.dart';
import '../widgets/reflexo_card_widgets.dart';

class ReflexoDeckPage extends StatelessWidget {
  const ReflexoDeckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = ReflexoContent.allCards;
    return Scaffold(
      backgroundColor: const Color(0xFF070A13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070A13),
        foregroundColor: Colors.white,
        title: const Text('Organizar Deck'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(
              'Cartas disponíveis',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Visualização inicial. Depois vamos permitir montar o deck manualmente e trocar imagens das cartas.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final card = cards[index];
                return ReflexoCardTile(
                  card: card,
                  cost: card.cost,
                  onTap: () => showReflexoCardDetails(context, card),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
