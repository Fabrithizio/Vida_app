// lib/data/models/area_status.dart
enum AreaStatus { otimo, bom, ruim }

extension AreaStatusUi on AreaStatus {
  String get label => switch (this) {
    AreaStatus.otimo => 'Ótimo',
    AreaStatus.bom => 'Bom',
    AreaStatus.ruim => 'Ruim',
  };
}
