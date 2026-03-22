// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// Fixes:
// - Dados por usuário: box = 'areas_box_<uid>'
// - Bootstrap inicial (MVP): conecta respostas do onboarding com score das áreas
//   -> se o box estiver vazio, cria avaliações iniciais coerentes
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/area_assessment.dart';
import '../../data/models/area_status.dart';

class AreasStore {
  static const _boxPrefix = 'areas_box_';

  String _uidOrAnon() {
    final u = FirebaseAuth.instance.currentUser;
    return (u?.uid ?? 'anon').trim().isEmpty ? 'anon' : u!.uid;
  }

  Future<Box<dynamic>> _open() async {
    final uid = _uidOrAnon();
    return Hive.openBox<dynamic>('$_boxPrefix$uid');
  }

  String _key(String areaId, String itemId) => '$areaId::$itemId';

  Future<void> ensureBootstrappedFromOnboarding() async {
    final box = await _open();
    if (box.isNotEmpty) return; // já tem dados para este usuário

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    final focus = (prefs.getString('$uid:focus') ?? '').trim();
    final gender = (prefs.getString('$uid:gender') ?? '').trim().toLowerCase();
    final screenTime = (prefs.getString('$uid:screen_time') ?? '').trim();
    final lastCheckup = (prefs.getString('$uid:last_checkup') ?? '').trim();

    final dobIso = (prefs.getString('$uid:dob') ?? '').trim();
    final age = _ageFromIsoDob(dobIso);

    Future<void> set(
      String area,
      String item,
      AreaStatus status, {
      String? reason,
    }) async {
      await box.put(
        _key(area, item),
        AreaAssessment(status: status, reason: reason).toMap(),
      );
    }

    // ---- foco principal -> área principal "começa melhor"
    if (focus == 'Saúde') {
      await set('body_health', 'sleep', AreaStatus.bom);
      await set('body_health', 'nutrition', AreaStatus.bom);
      await set('body_health', 'movement', AreaStatus.bom);
    } else if (focus == 'Finanças') {
      await set('finance_material', 'budget', AreaStatus.bom);
      await set('finance_material', 'spending', AreaStatus.bom);
    } else if (focus == 'Produtividade') {
      await set('work_vocation', 'routine', AreaStatus.bom);
      await set('work_vocation', 'output', AreaStatus.bom);
      await set('digital_tech', 'distraction', AreaStatus.bom);
    } else if (focus == 'Mental') {
      await set('mind_emotion', 'selfcare', AreaStatus.bom);
      await set('mind_emotion', 'focus', AreaStatus.bom);
    } else if (focus == 'Relacionamentos') {
      await set('relations_community', 'friends', AreaStatus.bom);
      await set('relations_community', 'family', AreaStatus.bom);
    }

    // ---- tempo de tela -> digital
    if (screenTime.isNotEmpty) {
      final st = screenTime;
      if (st == '< 2h') {
        await set('digital_tech', 'screen_time', AreaStatus.otimo);
      } else if (st == '2–4h') {
        await set('digital_tech', 'screen_time', AreaStatus.bom);
      } else if (st == '4–6h') {
        await set('digital_tech', 'screen_time', AreaStatus.bom);
      } else if (st == '6–8h') {
        await set('digital_tech', 'screen_time', AreaStatus.ruim);
      } else if (st == '8h+') {
        await set('digital_tech', 'screen_time', AreaStatus.ruim);
      }
    }

    // ---- checkup -> corpo/saúde
    if (lastCheckup.isNotEmpty) {
      await set('body_health', 'checkups', AreaStatus.bom);
    }

    // ---- ciclo: só se for mulher e idade >= 12 (MVP)
    final isWoman = gender.contains('mulher') || gender.contains('femin');
    if (isWoman && (age != null && age >= 12)) {
      await set('body_health', 'women_cycle', AreaStatus.bom);
    }
  }

  int? _ageFromIsoDob(String iso) {
    if (iso.isEmpty) return null;
    try {
      final dob = DateTime.parse(iso);
      final now = DateTime.now();
      var age = now.year - dob.year;
      final hadBirthday =
          (now.month > dob.month) ||
          (now.month == dob.month && now.day >= dob.day);
      if (!hadBirthday) age--;
      return age.clamp(0, 150);
    } catch (_) {
      return null;
    }
  }

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
