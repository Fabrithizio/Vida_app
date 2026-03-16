// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// Store local (Hive) para avaliações das áreas do Painel de Vida:
// - Salva/recupera o status (ótimo/bom/ruim) e motivo opcional por item
// - Calcula status geral (MVP)
// - NOVO: calcula score 0–100 (MVP) baseado na média dos itens avaliados
// ============================================================================

import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/area_assessment.dart';
import '../../data/models/area_status.dart';

class AreasStore {
  static const _boxName = 'areas_box';

  Future<Box<dynamic>> _open() async => Hive.openBox<dynamic>(_boxName);

  String _key(String areaId, String itemId) => '$areaId::$itemId';

  Future<AreaAssessment?> getAssessment(String areaId, String itemId) async {
    final box = await _open();
    final raw = box.get(_key(areaId, itemId));
    if (raw is! Map) return null;
    return AreaAssessment.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> setAssessment(
    String areaId,
    String itemId, {
    required AreaStatus status,
    String? reason,
  }) async {
    final box = await _open();
    final value = AreaAssessment(status: status, reason: reason).toMap();
    await box.put(_key(areaId, itemId), value);
  }

  Future<void> clearAssessment(String areaId, String itemId) async {
    final box = await _open();
    await box.delete(_key(areaId, itemId));
  }

  /// Status geral da área baseado nos itens do catálogo.
  ///
  /// Regras (simples/MVP):
  /// - Se tiver algum "ruim" => ruim
  /// - Senão se tiver algum "bom" => bom
  /// - Senão se tiver algum "otimo" => otimo
  /// - Se não tiver nada avaliado => null
  Future<AreaStatus?> overallStatus(String areaId, List<String> itemIds) async {
    final box = await _open();

    bool anyOtimo = false;
    bool anyBom = false;
    bool anyRuim = false;
    bool any = false;

    for (final itemId in itemIds) {
      final raw = box.get(_key(areaId, itemId));
      if (raw is! Map) continue;

      any = true;
      final m = Map<String, dynamic>.from(raw);
      final statusName = m['status'] as String?;
      if (statusName == null) continue;

      final s = AreaStatus.values.byName(statusName);
      if (s == AreaStatus.ruim) anyRuim = true;
      if (s == AreaStatus.bom) anyBom = true;
      if (s == AreaStatus.otimo) anyOtimo = true;
    }

    if (!any) return null;
    if (anyRuim) return AreaStatus.ruim;
    if (anyBom) return AreaStatus.bom;
    if (anyOtimo) return AreaStatus.otimo;
    return null;
  }

  /// Score 0–100 (MVP) baseado na média dos itens avaliados.
  ///
  /// Mapeamento (simples e previsível):
  /// - ótimo = 90
  /// - bom   = 65
  /// - ruim  = 30
  ///
  /// Se não houver nenhum item avaliado, retorna null (sem score ainda).
  Future<int?> score(String areaId, List<String> itemIds) async {
    final box = await _open();

    int sum = 0;
    int count = 0;

    for (final itemId in itemIds) {
      final raw = box.get(_key(areaId, itemId));
      if (raw is! Map) continue;

      final m = Map<String, dynamic>.from(raw);
      final statusName = m['status'] as String?;
      if (statusName == null) continue;

      final s = AreaStatus.values.byName(statusName);
      sum += switch (s) {
        AreaStatus.otimo => 90,
        AreaStatus.bom => 65,
        AreaStatus.ruim => 30,
      };
      count += 1;
    }

    if (count == 0) return null;
    return (sum / count).round().clamp(0, 100);
  }
}
