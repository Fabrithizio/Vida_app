// ============================================================================
// FILE: lib/features/reflexo_card_game/presentation/pages/reflexo_game_lobby_page.dart
// ============================================================================

import 'package:flutter/material.dart';

import '../../application/reflexo_deck_service.dart';
import '../../domain/reflexo_content.dart';
import '../../domain/reflexo_models.dart';
import 'reflexo_deck_page.dart';
import 'reflexo_duel_page.dart';

class ReflexoGameLobbyPage extends StatefulWidget {
  const ReflexoGameLobbyPage({super.key});

  @override
  State<ReflexoGameLobbyPage> createState() => _ReflexoGameLobbyPageState();
}

class _ReflexoGameLobbyPageState extends State<ReflexoGameLobbyPage> {
  ReflexoDeckTemplate _template = ReflexoContent.defaultDeck;
  List<String> _deckIds = ReflexoContent.defaultDeck.cardIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    final template = await ReflexoDeckService.loadTemplate();
    final ids = await ReflexoDeckService.loadDeckIds();
    if (!mounted) return;
    setState(() {
      _template = template;
      _deckIds = ids;
      _loading = false;
    });
  }

  Future<void> _selectTemplate(ReflexoDeckTemplate template) async {
    await ReflexoDeckService.saveTemplate(template);
    if (!mounted) return;
    setState(() {
      _template = template;
      _deckIds = template.cardIds;
    });
  }

  void _openDuel({required bool vsBot}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReflexoDuelPage(
          vsBot: vsBot,
          playerDeckIds: _deckIds,
          playerArchetype: _template.archetype,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validation = ReflexoContent.validateDeckIds(_deckIds);
    final cards = ReflexoContent.cardsFromIds(_deckIds);
    return Scaffold(
      backgroundColor: const Color(0xFF060915),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Reflexo Card Game',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF172554), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duelo de Reflexos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agora com artes, som e deck editável com regras para manter a jogabilidade justa.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LobbyButton(
                    icon: Icons.smart_toy_rounded,
                    title: 'Jogar contra Bot',
                    subtitle: 'Testa seu deck contra o Bot Estrategista.',
                    onTap: validation.isValid
                        ? () => _openDuel(vsBot: true)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _LobbyButton(
                    icon: Icons.sports_esports_rounded,
                    title: 'Jogar local 2 jogadores',
                    subtitle: 'Dois jogadores no mesmo aparelho.',
                    onTap: validation.isValid
                        ? () => _openDuel(vsBot: false)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _LobbyButton(
                    icon: Icons.style_rounded,
                    title: 'Montar Deck',
                    subtitle:
                        'Editar cartas com limite de unidades, feitiços e armadilhas.',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReflexoDeckPage(),
                        ),
                      );
                      await _loadDeck();
                    },
                  ),
                  const SizedBox(height: 10),
                  _LobbyButton(
                    icon: Icons.wifi_rounded,
                    title: 'Criar sala Wi-Fi',
                    subtitle: 'Preparado para etapa futura.',
                    disabled: true,
                    onTap: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DeckPreviewCard(
              loading: _loading,
              template: _template,
              validation: validation,
              cards: cards,
              onTemplateSelect: _selectTemplate,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckPreviewCard extends StatelessWidget {
  const _DeckPreviewCard({
    required this.loading,
    required this.template,
    required this.validation,
    required this.cards,
    required this.onTemplateSelect,
  });

  final bool loading;
  final ReflexoDeckTemplate template;
  final ReflexoDeckValidation validation;
  final List<ReflexoCardDefinition> cards;
  final ValueChanged<ReflexoDeckTemplate> onTemplateSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                        ),
                      ),
                      child: Icon(template.archetype.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${template.archetype.label} · ${template.description}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CounterChip(
                      label: 'Total',
                      value: validation.totalCount,
                      color: const Color(0xFF60A5FA),
                    ),
                    _CounterChip(
                      label: 'Unidades',
                      value: validation.unitCount,
                      color: const Color(0xFF22C55E),
                    ),
                    _CounterChip(
                      label: 'Feitiços',
                      value: validation.spellCount,
                      color: const Color(0xFFA78BFA),
                    ),
                    _CounterChip(
                      label: 'Armadilhas',
                      value: validation.trapCount,
                      color: const Color(0xFFF472B6),
                    ),
                    _CounterChip(
                      label: 'Pesadas',
                      value: validation.heavyCount,
                      color: const Color(0xFFFBBF24),
                    ),
                  ],
                ),
                if (!validation.isValid) ...[
                  const SizedBox(height: 10),
                  ...validation.messages.map(
                    (m) => Text(
                      '• $m',
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Decks rápidos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReflexoContent.starterDecks.map((deck) {
                    final selected = deck.id == template.id;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(deck.name),
                      onSelected: (_) => onTemplateSelect(deck),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 116,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: cards
                        .take(10)
                        .map((card) => _MiniCard(card: card))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.card});
  final ReflexoCardDefinition card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: card.imageAsset == null
                  ? Icon(card.attribute.icon, color: Colors.white54)
                  : Image.asset(
                      card.imageAsset!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(card.attribute.icon, color: Colors.white54),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LobbyButton extends StatelessWidget {
  const _LobbyButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final blocked = disabled || onTap == null;
    return Opacity(
      opacity: blocked ? 0.48 : 1,
      child: InkWell(
        onTap: blocked ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
