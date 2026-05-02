// ============================================================================
// FILE: lib/features/reflexo_card_game/presentation/pages/reflexo_deck_page.dart
// ============================================================================

import 'package:flutter/material.dart';

import '../../application/reflexo_deck_service.dart';
import '../../domain/reflexo_content.dart';
import '../../domain/reflexo_models.dart';
import '../widgets/reflexo_card_widgets.dart';

class ReflexoDeckPage extends StatefulWidget {
  const ReflexoDeckPage({super.key});

  @override
  State<ReflexoDeckPage> createState() => _ReflexoDeckPageState();
}

class _ReflexoDeckPageState extends State<ReflexoDeckPage> {
  List<String> _deckIds = ReflexoContent.defaultDeck.cardIds;
  ReflexoCardType? _filter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await ReflexoDeckService.loadDeckIds();
    if (!mounted) return;
    setState(() {
      _deckIds = ids;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final validation = ReflexoContent.validateDeckIds(_deckIds);
    if (!validation.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation.messages.join('\n'))));
      return;
    }
    await ReflexoDeckService.saveCustomDeck(_deckIds);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deck salvo.')));
  }

  void _addCard(ReflexoCardDefinition card) {
    final next = [..._deckIds, card.id];
    final validation = ReflexoContent.validateDeckIds(next);
    if (!validation.isValid && next.length > ReflexoContent.deckSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deck cheio. Remova uma carta antes.')),
      );
      return;
    }
    setState(() => _deckIds = next);
  }

  void _removeCard(String id) {
    final next = [..._deckIds];
    next.remove(id);
    setState(() => _deckIds = next);
  }

  @override
  Widget build(BuildContext context) {
    final validation = ReflexoContent.validateDeckIds(_deckIds);
    final deckCards = ReflexoContent.cardsFromIds(_deckIds);
    final available = ReflexoContent.allCards.where((card) {
      final filter = _filter;
      return filter == null || card.type == filter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF060915),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060915),
        foregroundColor: Colors.white,
        title: const Text('Montar Deck'),
        actions: [
          TextButton.icon(
            onPressed: validation.isValid ? _save : null,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Salvar'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _ValidationPanel(validation: validation),
                  SizedBox(
                    height: 116,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      children: deckCards.map((card) {
                        return Stack(
                          children: [
                            ReflexoCardTile(
                              card: card,
                              cost: card.cost,
                              compact: true,
                              onTap: () => _removeCard(card.id),
                            ),
                            const Positioned(
                              top: 4,
                              left: 4,
                              child: Icon(
                                Icons.remove_circle_rounded,
                                color: Color(0xFFF87171),
                                size: 18,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                        ChoiceChip(
                          label: const Text('Unidades'),
                          selected: _filter == ReflexoCardType.unit,
                          onSelected: (_) =>
                              setState(() => _filter = ReflexoCardType.unit),
                        ),
                        ChoiceChip(
                          label: const Text('Feitiços'),
                          selected: _filter == ReflexoCardType.spell,
                          onSelected: (_) =>
                              setState(() => _filter = ReflexoCardType.spell),
                        ),
                        ChoiceChip(
                          label: const Text('Armadilhas'),
                          selected: _filter == ReflexoCardType.trap,
                          onSelected: (_) =>
                              setState(() => _filter = ReflexoCardType.trap),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.66,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final card = available[index];
                        final count = _deckIds
                            .where((id) => id == card.id)
                            .length;
                        final canAdd =
                            _deckIds.length < ReflexoContent.deckSize &&
                            count < ReflexoContent.maxCopies;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ReflexoCardTile(
                                card: card,
                                cost: card.cost,
                                enabled: canAdd,
                                onTap: () => _addCard(card),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  'x$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.validation});
  final ReflexoDeckValidation validation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: validation.isValid
              ? const Color(0xFF22C55E)
              : const Color(0xFFF97316),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: 'Total',
                value: '${validation.totalCount}/${ReflexoContent.deckSize}',
                color: const Color(0xFF60A5FA),
              ),
              _Chip(
                label: 'Unidades',
                value: '${validation.unitCount}',
                color: const Color(0xFF22C55E),
              ),
              _Chip(
                label: 'Feitiços',
                value: '${validation.spellCount}/${ReflexoContent.maxSpells}',
                color: const Color(0xFFA78BFA),
              ),
              _Chip(
                label: 'Armadilhas',
                value: '${validation.trapCount}/${ReflexoContent.maxTraps}',
                color: const Color(0xFFF472B6),
              ),
              _Chip(
                label: 'Pesadas',
                value:
                    '${validation.heavyCount}/${ReflexoContent.maxHeavyCards}',
                color: const Color(0xFFFBBF24),
              ),
            ],
          ),
          if (!validation.isValid) ...[
            const SizedBox(height: 8),
            ...validation.messages.map(
              (message) => Text(
                '• $message',
                style: const TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
