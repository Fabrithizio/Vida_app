// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// O que faz:
// - Dados por usuário (Hive box 'areas_box_<uid>')
// - "Computed assessments": alguns itens (checkups, sleep, screen_time, women_cycle)
//   são calculados dinamicamente a partir das respostas (SharedPreferences), então
//   mudam com o tempo e quando o usuário atualiza.
// - Checkups:
//   < 6 meses -> otimo (verde)
//   6..11 -> bom (amarelo)
//   >= 12 -> ruim (vermelho)
// - UI pode chamar updateLastCheckupDate() para mudar a data e recalcular.
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_status.dart';

class AreasStore {
  static const _boxPrefix = 'areas_box_';

  String _uidOrAnon() {
    final u = FirebaseAuth.instance.currentUser;
    final uid = (u?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> _open() async {
    final uid = _uidOrAnon();
    return Hive.openBox<dynamic>('$_boxPrefix$uid');
  }

  String _key(String areaId, String itemId) => '$areaId::$itemId';

  // --------------------------------------------------------------------------
  // Bootstrap inicial (apenas se o box estiver vazio)
  // --------------------------------------------------------------------------
  Future<void> ensureBootstrappedFromOnboarding() async {
    final box = await _open();
    if (box.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    Future<void> seed(
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

    // Seed leve baseado em foco (apenas um empurrão inicial)
    final focus = (prefs.getString('$uid:focus') ?? '').trim();
    if (focus == 'Saúde') {
      await seed('body_health', 'nutrition', AreaStatus.bom, reason: 'Foco');
      await seed('body_health', 'movement', AreaStatus.bom, reason: 'Foco');
    } else if (focus == 'Finanças') {
      await seed('finance_material', 'budget', AreaStatus.bom, reason: 'Foco');
    } else if (focus == 'Produtividade') {
      await seed('work_vocation', 'routine', AreaStatus.bom, reason: 'Foco');
    } else if (focus == 'Mental') {
      await seed('mind_emotion', 'selfcare', AreaStatus.bom, reason: 'Foco');
    } else if (focus == 'Relacionamentos') {
      await seed(
        'relations_community',
        'friends',
        AreaStatus.bom,
        reason: 'Foco',
      );
      await seed(
        'relations_community',
        'family',
        AreaStatus.bom,
        reason: 'Foco',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Computed assessment (dinâmico) — usado pelo detalhe da área
  // --------------------------------------------------------------------------
  Future<AreaAssessment?> getComputedAssessment(
    String areaId,
    String itemId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // sem usuário: só lê do Hive
      return getAssessment(areaId, itemId);
    }

    // Computados (mudam com o tempo / prefs)
    if (areaId == 'body_health' && itemId == 'checkups') {
      return _computedCheckups(user.uid);
    }
    if (areaId == 'body_health' && itemId == 'sleep') {
      return _computedSleep(user.uid);
    }
    if (areaId == 'digital_tech' && itemId == 'screen_time') {
      return _computedScreenTime(user.uid);
    }
    if (areaId == 'body_health' && itemId == 'women_cycle') {
      return _computedWomenCycle(user.uid);
    }

    // padrão
    return getAssessment(areaId, itemId);
  }

  // --------------------------------------------------------------------------
  // Checkups: calcula status a partir de $uid:last_checkup (ISO yyyy-mm-dd)
  // --------------------------------------------------------------------------
  Future<AreaAssessment?> _computedCheckups(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final iso = (prefs.getString('$uid:last_checkup') ?? '').trim();
    if (iso.isEmpty) return null;

    final dt = _parseIsoDate(iso);
    if (dt == null) return null;

    final now = DateTime.now();
    final days = now.difference(dt).inDays;
    final months = _monthsBetween(dt, now);

    final status = _statusForCheckups(months);
    final reason = 'Faz $days dias (~$months meses)';

    return AreaAssessment(status: status, reason: reason);
  }

  AreaStatus _statusForCheckups(int months) {
    if (months < 6) return AreaStatus.otimo; // verde
    if (months < 12) return AreaStatus.bom; // amarelo
    return AreaStatus.ruim; // vermelho
  }

  // --------------------------------------------------------------------------
  // Sono: $uid:sleep_hours (int)
  // <5 ruim, 5-6 bom, 7+ otimo
  // --------------------------------------------------------------------------
  Future<AreaAssessment?> _computedSleep(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString('$uid:sleep_hours') ?? '').trim();
    final h = int.tryParse(raw);
    if (h == null) return null;

    if (h < 5)
      return AreaAssessment(status: AreaStatus.ruim, reason: '$h h/noite');
    if (h <= 6)
      return AreaAssessment(status: AreaStatus.bom, reason: '$h h/noite');
    return AreaAssessment(status: AreaStatus.otimo, reason: '$h h/noite');
  }

  // --------------------------------------------------------------------------
  // Tempo de tela: $uid:screen_time (opção)
  // <2h otimo, 2-6 bom, >=6 ruim
  // --------------------------------------------------------------------------
  Future<AreaAssessment?> _computedScreenTime(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final st = (prefs.getString('$uid:screen_time') ?? '').trim();
    if (st.isEmpty) return null;

    if (st == '< 2h')
      return AreaAssessment(status: AreaStatus.otimo, reason: st);
    if (st == '2–4h' || st == '4–6h')
      return AreaAssessment(status: AreaStatus.bom, reason: st);
    return AreaAssessment(status: AreaStatus.ruim, reason: st);
  }

  // --------------------------------------------------------------------------
  // Ciclo: só aparece (bom) se mulher e idade >= 12
  // --------------------------------------------------------------------------
  Future<AreaAssessment?> _computedWomenCycle(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final gender = (prefs.getString('$uid:gender') ?? '').trim().toLowerCase();
    final dobIso = (prefs.getString('$uid:dob') ?? '').trim();

    final isWoman = gender.contains('mulher') || gender.contains('femin');
    if (!isWoman) return null;

    final age = _ageFromIsoDob(dobIso) ?? 0;
    if (age < 12) return null;

    return const AreaAssessment(status: AreaStatus.bom, reason: 'Disponível');
  }

  // --------------------------------------------------------------------------
  // Atualização da data do checkup (chamado pela UI)
  // --------------------------------------------------------------------------
  Future<void> updateLastCheckupDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final iso = _toIsoDate(date);
    await prefs.setString('${user.uid}:last_checkup', iso);

    // Opcional: também salva um snapshot no Hive (não obrigatório),
    // mas ajuda se você quiser mostrar no dashboard sem recomputar.
    final computed = await _computedCheckups(user.uid);
    if (computed != null) {
      final box = await _open();
      await box.put(_key('body_health', 'checkups'), computed.toMap());
    }
  }

  // --------------------------------------------------------------------------
  // Hive default methods (itens manuais / sem regra)
  // --------------------------------------------------------------------------
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

  Future<AreaStatus?> overallStatus(String areaId, List<String> itemIds) async {
    bool anyOtimo = false;
    bool anyBom = false;
    bool anyRuim = false;
    bool any = false;

    for (final itemId in itemIds) {
      final a = await getComputedAssessment(areaId, itemId);
      if (a == null) continue;

      any = true;
      if (a.status == AreaStatus.ruim) anyRuim = true;
      if (a.status == AreaStatus.bom) anyBom = true;
      if (a.status == AreaStatus.otimo) anyOtimo = true;
    }

    if (!any) return null;
    if (anyRuim) return AreaStatus.ruim;
    if (anyBom) return AreaStatus.bom;
    if (anyOtimo) return AreaStatus.otimo;
    return null;
  }

  Future<int?> score(String areaId, List<String> itemIds) async {
    int sum = 0;
    int count = 0;

    for (final itemId in itemIds) {
      final a = await getComputedAssessment(areaId, itemId);
      if (a == null) continue;

      sum += switch (a.status) {
        AreaStatus.otimo => 90,
        AreaStatus.bom => 65,
        AreaStatus.ruim => 30,
      };
      count += 1;
    }

    if (count == 0) return null;
    return (sum / count).round().clamp(0, 100);
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  DateTime? _parseIsoDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }

  String _toIsoDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  int _monthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months < 0 ? 0 : months;
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
      if (age < 0 || age > 150) return null;
      return age;
    } catch (_) {
      return null;
    }
  }
}
