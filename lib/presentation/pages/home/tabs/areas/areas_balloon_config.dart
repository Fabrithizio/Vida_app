import 'dart:ui';

import 'areas_model_assets.dart';

class BalloonSpec {
  const BalloonSpec({
    required this.areaId,
    required this.title,
    required this.from, // ponto no corpo
    required this.to, // ponto do balão
    this.maxWidthFactor = 0.38,
  });

  final String areaId;
  final String title;
  final Offset from;
  final Offset to;
  final double maxWidthFactor;
}

class AreasBalloonConfig {
  static List<BalloonSpec> specs(UserSex sex) {
    // Ajuste fino depois (2 min no futuro). MVP já fica bom.
    if (sex == UserSex.female) {
      return const [
        BalloonSpec(
          areaId: 'head',
          title: 'Cabeça',
          from: Offset(0.50, 0.12),
          to: Offset(0.18, 0.18),
        ),
        BalloonSpec(
          areaId: 'chest',
          title: 'Peito',
          from: Offset(0.50, 0.30),
          to: Offset(0.82, 0.24),
        ),
        BalloonSpec(
          areaId: 'abdomen',
          title: 'Abdômen',
          from: Offset(0.50, 0.46),
          to: Offset(0.18, 0.48),
        ),
        BalloonSpec(
          areaId: 'leftArm',
          title: 'Braço E',
          from: Offset(0.28, 0.33),
          to: Offset(0.18, 0.34),
        ),
        BalloonSpec(
          areaId: 'rightArm',
          title: 'Braço D',
          from: Offset(0.72, 0.33),
          to: Offset(0.82, 0.34),
        ),
        BalloonSpec(
          areaId: 'leftLeg',
          title: 'Perna E',
          from: Offset(0.46, 0.76),
          to: Offset(0.18, 0.74),
        ),
        BalloonSpec(
          areaId: 'rightLeg',
          title: 'Perna D',
          from: Offset(0.54, 0.76),
          to: Offset(0.82, 0.74),
        ),
        // Se você tiver área pélvica no catálogo/hitmap feminino:
        BalloonSpec(
          areaId: 'pelvis',
          title: 'Pelve',
          from: Offset(0.50, 0.58),
          to: Offset(0.82, 0.52),
        ),
      ];
    }

    return const [
      BalloonSpec(
        areaId: 'head',
        title: 'Cabeça',
        from: Offset(0.50, 0.12),
        to: Offset(0.18, 0.18),
      ),
      BalloonSpec(
        areaId: 'chest',
        title: 'Peito',
        from: Offset(0.50, 0.30),
        to: Offset(0.82, 0.24),
      ),
      BalloonSpec(
        areaId: 'abdomen',
        title: 'Abdômen',
        from: Offset(0.50, 0.46),
        to: Offset(0.18, 0.48),
      ),
      BalloonSpec(
        areaId: 'leftArm',
        title: 'Braço E',
        from: Offset(0.28, 0.33),
        to: Offset(0.18, 0.34),
      ),
      BalloonSpec(
        areaId: 'rightArm',
        title: 'Braço D',
        from: Offset(0.72, 0.33),
        to: Offset(0.82, 0.34),
      ),
      BalloonSpec(
        areaId: 'leftLeg',
        title: 'Perna E',
        from: Offset(0.46, 0.76),
        to: Offset(0.18, 0.74),
      ),
      BalloonSpec(
        areaId: 'rightLeg',
        title: 'Perna D',
        from: Offset(0.54, 0.76),
        to: Offset(0.82, 0.74),
      ),
      BalloonSpec(
        areaId: 'pelvis',
        title: 'Pelve',
        from: Offset(0.50, 0.58),
        to: Offset(0.82, 0.52),
      ),
    ];
  }
}
