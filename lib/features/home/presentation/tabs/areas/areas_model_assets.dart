// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/areas_model_assets.dart
//
// Assets/config do personagem do Painel de Vida:
// - Usa base.webp (male/female)
// - Inclui "tuning" de render (crop + scale + alignment) para compensar padding do asset
// - Assim você consegue trocar a arte depois sem quebrar a UI
// ============================================================================

import 'package:flutter/widgets.dart';

enum UserSex { male, female }

class CharacterAssetSpec {
  const CharacterAssetSpec({
    required this.path,
    this.scale = 1.0,
    this.cropWidthFactor = 1.0,
    this.cropHeightFactor = 1.0,
    this.alignment = Alignment.center,
  });

  final String path;

  /// Escala aplicada no personagem dentro do slot
  final double scale;

  /// 1.0 = não corta. Valores menores recortam espaço vazio (centralizado).
  final double cropWidthFactor;

  /// 1.0 = não corta. Valores menores recortam espaço vazio (centralizado).
  final double cropHeightFactor;

  final Alignment alignment;
}

class AreasModelAssets {
  static CharacterAssetSpec character(UserSex sex) {
    // Ajuste fino para assets com padding grande.
    // Você pode mudar esses números depois sem mexer no resto do código.
    return sex == UserSex.male
        ? const CharacterAssetSpec(
            path: 'assets/models/male/base.webp',
            scale: 1.12,
            cropWidthFactor: 0.92,
            cropHeightFactor: 0.90,
            alignment: Alignment(0, -0.05),
          )
        : const CharacterAssetSpec(
            path: 'assets/models/female/base.webp',
            scale: 1.12,
            cropWidthFactor: 0.92,
            cropHeightFactor: 0.90,
            alignment: Alignment(0, -0.05),
          );
  }
}
