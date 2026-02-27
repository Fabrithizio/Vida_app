// lib/presentation/pages/home/tabs/areas/areas_catalog.dart
class AreaItemDef {
  const AreaItemDef({required this.id, required this.title});

  final String id;
  final String title;
}

class AreasCatalog {
  static List<AreaItemDef> itemsFor(String areaId) {
    switch (areaId) {
      case 'head':
        return const [
          AreaItemDef(id: 'emocao', title: 'Emoção'),
          AreaItemDef(id: 'aprendizado', title: 'Aprendizado'),
          AreaItemDef(id: 'foco', title: 'Foco'),

          // ✅ ADICIONE MAIS AQUI
          AreaItemDef(id: 'memoria', title: 'Memória'),
          AreaItemDef(id: 'criatividade', title: 'Criatividade'),
          AreaItemDef(id: 'estresse', title: 'Estresse'),
        ];

      case 'chest':
        return const [
          AreaItemDef(id: 'respiracao', title: 'Respiração'),
          AreaItemDef(id: 'energia', title: 'Energia'),
          AreaItemDef(id: 'postura', title: 'Postura'),
        ];

      case 'abdomen':
        return const [
          AreaItemDef(id: 'alimentacao', title: 'Alimentação'),
          AreaItemDef(id: 'digestao', title: 'Digestão'),
          AreaItemDef(id: 'sono', title: 'Sono'),
        ];

      case 'leftArm':
      case 'rightArm':
        return const [
          AreaItemDef(id: 'forca', title: 'Força'),
          AreaItemDef(id: 'dor', title: 'Dor'),
          AreaItemDef(id: 'mobilidade', title: 'Mobilidade'),
        ];

      case 'leftLeg':
      case 'rightLeg':
        return const [
          AreaItemDef(id: 'caminhada', title: 'Caminhada'),
          AreaItemDef(id: 'treino', title: 'Treino'),
          AreaItemDef(id: 'flexibilidade', title: 'Flexibilidade'),
        ];

      case 'pelvis':
        return const [
          AreaItemDef(id: 'cuidados_intimos', title: 'Cuidados íntimos'),
          AreaItemDef(id: 'higiene', title: 'Higiene'),
          AreaItemDef(id: 'dor_desconforto', title: 'Dor / Desconforto'),
        ];

      default:
        return const [AreaItemDef(id: 'geral', title: 'Geral')];
    }
  }
}
