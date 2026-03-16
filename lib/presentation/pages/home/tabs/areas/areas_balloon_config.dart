// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/areas_balloon_config.dart
//
// Ajuste de layout das 9 orbes:
// - Move os 3 de baixo para cima (evita conflito com o FAB)
// - Dá mais “respiro” horizontal em Casa/Digital
// - Mantém bolhas menores (maxWidthFactor 0.29~0.34)
// ============================================================================

import 'dart:ui';

import 'areas_catalog.dart';
import 'areas_model_assets.dart';

class BalloonSpec {
  const BalloonSpec({
    required this.areaId,
    required this.title,
    required this.from,
    required this.to,
    this.maxWidthFactor = 0.29,
  });

  final String areaId;
  final String title;
  final Offset from;
  final Offset to;
  final double maxWidthFactor;
}

class AreasBalloonConfig {
  static List<BalloonSpec> specs(UserSex sex) {
    return const [
      // Top-left / Top-right
      BalloonSpec(
        areaId: AreasCatalog.mindEmotion,
        title: 'Mente',
        from: Offset(0.50, 0.40),
        to: Offset(0.18, 0.18),
        maxWidthFactor: 0.30,
      ),
      BalloonSpec(
        areaId: AreasCatalog.financeMaterial,
        title: 'Finanças',
        from: Offset(0.50, 0.40),
        to: Offset(0.82, 0.18),
        maxWidthFactor: 0.30,
      ),

      // Mid-left / Mid-right
      BalloonSpec(
        areaId: AreasCatalog.bodyHealth,
        title: 'Corpo',
        from: Offset(0.50, 0.40),
        to: Offset(0.14, 0.40),
        maxWidthFactor: 0.30,
      ),
      BalloonSpec(
        areaId: AreasCatalog.workVocation,
        title: 'Trabalho',
        from: Offset(0.50, 0.40),
        to: Offset(0.86, 0.40),
        maxWidthFactor: 0.30,
      ),

      // Upper-bottom left/right
      BalloonSpec(
        areaId: AreasCatalog.learningIntellect,
        title: 'Aprender',
        from: Offset(0.50, 0.40),
        to: Offset(0.18, 0.62),
        maxWidthFactor: 0.30,
      ),
      BalloonSpec(
        areaId: AreasCatalog.relationsCommunity,
        title: 'Relações',
        from: Offset(0.50, 0.40),
        to: Offset(0.82, 0.62),
        maxWidthFactor: 0.30,
      ),

      // Bottom row — subiu e abriu mais pros lados
      BalloonSpec(
        areaId: AreasCatalog.environmentHome,
        title: 'Casa',
        from: Offset(0.50, 0.40),
        to: Offset(0.20, 0.78),
        maxWidthFactor: 0.30,
      ),
      BalloonSpec(
        areaId: AreasCatalog.digitalTech,
        title: 'Digital',
        from: Offset(0.50, 0.40),
        to: Offset(0.80, 0.78),
        maxWidthFactor: 0.30,
      ),

      // Propósito — sobe bem pra não brigar com o FAB
      BalloonSpec(
        areaId: AreasCatalog.purposeValues,
        title: 'Propósito',
        from: Offset(0.50, 0.40),
        to: Offset(0.50, 0.86),
        maxWidthFactor: 0.34,
      ),
    ];
  }
}
