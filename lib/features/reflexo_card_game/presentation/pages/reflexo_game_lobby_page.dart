// lib/features/reflexo_card_game/presentation/pages/reflexo_game_lobby_page.dart

import 'package:flutter/material.dart';

import '../../domain/reflexo_content.dart';
import '../../domain/reflexo_models.dart';
import '../widgets/reflexo_duel_hud.dart';
import 'reflexo_deck_page.dart';
import 'reflexo_duel_page.dart';

class ReflexoGameLobbyPage extends StatelessWidget {
  const ReflexoGameLobbyPage({super.key});

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
                    'Use cartas, Destinos e d20 para vencer o Reflexo inimigo. Esta versão foca em deixar o jogo realmente jogável antes do Wi-Fi.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LobbyButton(
                    icon: Icons.sports_esports_rounded,
                    title: 'Jogar protótipo local',
                    subtitle: 'Dois jogadores no mesmo aparelho por enquanto.',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReflexoDuelPage(),
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
            ReflexoAttributesPanel(player: preview),
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
      deck: ReflexoContent.buildDeck(seedOffset: 0),
      hand: const [],
      field: const [],
      discard: const [],
      buffs: const [],
      attributes: ReflexoContent.attributesForPlayer(ReflexoPlayerId.one),
      mainArchetype: ReflexoArchetype.berserker,
      secondaryArchetype: ReflexoArchetype.guardiao,
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
