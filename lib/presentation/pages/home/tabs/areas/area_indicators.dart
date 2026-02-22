import 'dart:ui';

class AreaIndicator {
  const AreaIndicator({
    required this.areaId,
    required this.title,
    required this.anchor, // offset 0..1 relativo ao container do BodyMap
  });

  final String areaId;
  final String title;
  final Offset anchor;
}

/// Ajuste esses anchors quando trocar a imagem.
/// (0,0) = topo/esquerda, (1,1) = baixo/direita.
class AreaIndicators {
  static const all = <AreaIndicator>[
    AreaIndicator(areaId: 'head', title: 'Cabeça', anchor: Offset(0.50, 0.12)),
    AreaIndicator(areaId: 'chest', title: 'Peito', anchor: Offset(0.50, 0.30)),
    AreaIndicator(
      areaId: 'abdomen',
      title: 'Abdômen',
      anchor: Offset(0.50, 0.45),
    ),
    AreaIndicator(
      areaId: 'leftArm',
      title: 'Braço E',
      anchor: Offset(0.23, 0.33),
    ),
    AreaIndicator(
      areaId: 'rightArm',
      title: 'Braço D',
      anchor: Offset(0.77, 0.33),
    ),
    AreaIndicator(
      areaId: 'leftLeg',
      title: 'Perna E',
      anchor: Offset(0.44, 0.75),
    ),
    AreaIndicator(
      areaId: 'rightLeg',
      title: 'Perna D',
      anchor: Offset(0.56, 0.75),
    ),
  ];
}
