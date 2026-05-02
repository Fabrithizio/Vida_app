// ============================================================================
// FILE: lib/features/reflexo_card_game/application/reflexo_sound_service.dart
// ============================================================================

import 'package:audioplayers/audioplayers.dart';

import '../domain/reflexo_models.dart';

class ReflexoSoundService {
  ReflexoSoundService._();

  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> play(ReflexoSoundCue cue) async {
    try {
      final path = switch (cue) {
        ReflexoSoundCue.playCard => 'audio/reflexo/Lanca_carta.mp3',
        ReflexoSoundCue.rollDice => 'audio/reflexo/rolar_dado.mp3',
        ReflexoSoundCue.attack => 'audio/reflexo/ataque.mp3',
        ReflexoSoundCue.directAttack => 'audio/reflexo/ataque_unico.mp3',
        ReflexoSoundCue.destroyCard => 'audio/reflexo/destruir_carta.mp3',
        ReflexoSoundCue.trapReveal => 'audio/reflexo/Armadilha_revelada.mp3',
        ReflexoSoundCue.victory => 'audio/reflexo/vitoria.mp3',
        ReflexoSoundCue.defeat => 'audio/reflexo/derrota.mp3',
      };
      await _player.stop();
      await _player.play(AssetSource(path), volume: 0.85);
    } catch (_) {
      // Som é melhoria de UX. Nunca deve travar o jogo se um asset estiver ausente.
    }
  }
}
