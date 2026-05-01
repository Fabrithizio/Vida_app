// ============================================================================
// FILE: lib/features/reflexo_card_game/presentation/pages/reflexo_game_lobby_page.dart
// ============================================================================

import 'package:flutter/material.dart';

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
  String _selectedPresetId = ReflexoContent.deckPresets.first.id;

  ReflexoDeckPreset get _preset =>
      ReflexoContent.deckPresetById(_selectedPresetId);

  @override
  Widget build(BuildContext context) {
    final preview = _previewPlayer();
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
                    'Escolha um deck, use cartas, Destinos, Tática, Pressão e d20 para vencer o Reflexo inimigo.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DeckPresetPicker(
                    selectedId: _selectedPresetId,
                    onChanged: (id) => setState(() => _selectedPresetId = id),
                  ),
                  const SizedBox(height: 12),
                  _DeckPreviewPanel(presetId: _selectedPresetId),
                  const SizedBox(height: 16),
                  _LobbyButton(
                    icon: Icons.smart_toy_rounded,
                    title: 'Jogar contra Bot',
                    subtitle: 'Seu deck: ${_preset.name}. Bot usa Controle.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReflexoDuelPage(
                          vsBot: true,
                          playerDeckPresetId: _selectedPresetId,
                          opponentDeckPresetId: 'estrategista',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LobbyButton(
                    icon: Icons.group_rounded,
                    title: 'Jogar local 2 jogadores',
                    subtitle:
                        'Jogador 1 usa ${_preset.name}. Jogador 2 usa Controle.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReflexoDuelPage(
                          playerDeckPresetId: _selectedPresetId,
                          opponentDeckPresetId: 'estrategista',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LobbyButton(
                    icon: Icons.style_rounded,
                    title: 'Organizar Deck',
                    subtitle: 'Ver todas as cartas disponíveis.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReflexoDeckPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LobbyButton(
                    icon: Icons.wifi_rounded,
                    title: 'Criar sala Wi-Fi',
                    subtitle: 'Preparado para a próxima etapa.',
                    disabled: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LobbyAttributesPanel(player: preview, preset: _preset),
          ],
        ),
      ),
    );
  }

  ReflexoPlayerState _previewPlayer() {
    return ReflexoPlayerState(
      id: ReflexoPlayerId.one,
      name: 'Seu Reflexo',
      life: 100,
      energy: 0,
      reserve: 0,
      deck: ReflexoContent.buildDeck(
        seedOffset: 0,
        presetId: _selectedPresetId,
      ),
      hand: const [],
      field: const [],
      discard: const [],
      buffs: const [],
      attributes: ReflexoContent.attributesForPlayer(ReflexoPlayerId.one),
      mainArchetype: _preset.archetype,
      secondaryArchetype: null,
    );
  }
}

class _DeckPresetPicker extends StatelessWidget {
  const _DeckPresetPicker({required this.selectedId, required this.onChanged});

  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = ReflexoContent.deckPresetById(selectedId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deck inicial',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedId,
            dropdownColor: const Color(0xFF0B1020),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF111827),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            items: ReflexoContent.deckPresets
                .map(
                  (preset) => DropdownMenuItem<String>(
                    value: preset.id,
                    child: Text(preset.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            selected.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckPreviewPanel extends StatelessWidget {
  const _DeckPreviewPanel({required this.presetId});

  final String presetId;

  @override
  Widget build(BuildContext context) {
    final deck = ReflexoContent.buildDeck(seedOffset: 0, presetId: presetId);
    final units = deck.where((card) => card.isUnit).length;
    final spells = deck.where((card) => card.isSpell).length;
    final traps = deck.where((card) => card.isTrap).length;
    final uniqueCards = <String, ReflexoCardDefinition>{};
    for (final card in deck) {
      uniqueCards.putIfAbsent(card.id, () => card);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Prévia do deck',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _DeckCountChip(
                label: 'UN',
                value: units,
                color: const Color(0xFF60A5FA),
              ),
              const SizedBox(width: 6),
              _DeckCountChip(
                label: 'MAG',
                value: spells,
                color: const Color(0xFFA78BFA),
              ),
              const SizedBox(width: 6),
              _DeckCountChip(
                label: 'ARM',
                value: traps,
                color: const Color(0xFFF472B6),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: uniqueCards.values.take(12).map((card) {
              final color = card.isUnit
                  ? const Color(0xFF60A5FA)
                  : card.isSpell
                  ? const Color(0xFFA78BFA)
                  : const Color(0xFFF472B6);
              return Tooltip(
                message: card.text.isEmpty ? card.name : card.text,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.32)),
                  ),
                  child: Text(
                    card.name,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'O deck já está selecionado. Depois vamos liberar edição manual carta por carta.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckCountChip extends StatelessWidget {
  const _DeckCountChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LobbyAttributesPanel extends StatelessWidget {
  const _LobbyAttributesPanel({required this.player, required this.preset});

  final ReflexoPlayerState player;
  final ReflexoDeckPreset preset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(player.mainArchetype.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${player.mainArchetype.label} · ${player.mainArchetype.shortDescription}',
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
          Text(
            'Atributos do Reflexo',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...ReflexoAttribute.values.map((attribute) {
            final value = player.attributes[attribute] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    attribute.icon,
                    color: const Color(0xFF93C5FD),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 82,
                    child: Text(
                      attribute.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: (value / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF60A5FA),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$value',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.48 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
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
