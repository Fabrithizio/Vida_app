// lib/features/areas/areas_store.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_status.dart';

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
}
