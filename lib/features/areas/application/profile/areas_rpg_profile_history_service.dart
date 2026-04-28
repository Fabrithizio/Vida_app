// ============================================================================
// FILE: lib/features/areas/application/profile/areas_rpg_profile_history_service.dart
//
// O que faz:
// - Salva snapshots diários da ficha RPG por usuário
// - Permite comparar hoje com ontem
// - Prepara a base para evolução, histórico e futuras mecânicas
// ============================================================================

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/areas/application/profile/areas_rpg_profile_models.dart';

class AreasRpgAttributeDelta {
  const AreasRpgAttributeDelta({
    required this.type,
    required this.currentValue,
    required this.previousValue,
  });

  final RpgAttributeType type;
  final int currentValue;
  final int previousValue;

  int get delta => currentValue - previousValue;
  bool get changed => delta != 0;
}

class AreasRpgEvolution {
  const AreasRpgEvolution({
    required this.current,
    required this.previous,
    required this.attributeDeltas,
    required this.powerDelta,
    required this.classChanged,
    required this.rankChanged,
    required this.diceFloorDelta,
    required this.diceCeilDelta,
  });

  final AreasRpgProfileSnapshot current;
  final AreasRpgProfileSnapshot? previous;
  final List<AreasRpgAttributeDelta> attributeDeltas;
  final int powerDelta;
  final bool classChanged;
  final bool rankChanged;
  final int diceFloorDelta;
  final int diceCeilDelta;

  bool get hasAnyChange =>
      powerDelta != 0 ||
      classChanged ||
      rankChanged ||
      diceFloorDelta != 0 ||
      diceCeilDelta != 0 ||
      attributeDeltas.any((e) => e.changed);
}

class AreasRpgProfileHistoryService {
  static const String _historyKey = 'areas_rpg_profile_history_v1';

  String _scopedKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    if (uid == null || uid.isEmpty) return _historyKey;
    return '$uid:$_historyKey';
  }

  String _dayKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }

  Future<Map<String, dynamic>> _loadRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_scopedKey()) ?? '').trim();
    if (raw.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveRaw(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(), jsonEncode(value));
  }

  Future<void> saveDailySnapshot(AreasRpgProfileSnapshot snapshot) async {
    final raw = await _loadRaw();
    raw[_dayKey(snapshot.updatedAt)] = snapshot.toHistoryMap();
    await _saveRaw(raw);
  }

  Future<AreasRpgProfileSnapshot?> readSnapshotForDay(
    DateTime date, {
    List<RpgRulesBookSection> rules = const <RpgRulesBookSection>[],
  }) async {
    final raw = await _loadRaw();
    final entry = raw[_dayKey(date)];
    if (entry is! Map) return null;

    return AreasRpgProfileSnapshot.fromHistoryMap(
      Map<String, dynamic>.from(entry),
      rules: rules,
    );
  }

  Future<AreasRpgProfileSnapshot?> readPreviousSnapshot(
    DateTime currentDate, {
    List<RpgRulesBookSection> rules = const <RpgRulesBookSection>[],
    int maxLookbackDays = 14,
  }) async {
    for (var i = 1; i <= maxLookbackDays; i++) {
      final probe = currentDate.subtract(Duration(days: i));
      final item = await readSnapshotForDay(probe, rules: rules);
      if (item != null) return item;
    }
    return null;
  }

  Future<AreasRpgEvolution> buildEvolution(
    AreasRpgProfileSnapshot current,
  ) async {
    final previous = await readPreviousSnapshot(
      current.updatedAt,
      rules: current.rules,
    );

    final deltas = RpgAttributeType.values
        .map((type) {
          final currentValue = current.attributeOf(type).value;
          final previousValue =
              previous?.attributeOf(type).value ?? currentValue;

          return AreasRpgAttributeDelta(
            type: type,
            currentValue: currentValue,
            previousValue: previousValue,
          );
        })
        .toList(growable: false);

    return AreasRpgEvolution(
      current: current,
      previous: previous,
      attributeDeltas: deltas,
      powerDelta:
          current.totalPower - (previous?.totalPower ?? current.totalPower),
      classChanged: previous != null && previous.archetype != current.archetype,
      rankChanged: previous != null && previous.rankLabel != current.rankLabel,
      diceFloorDelta:
          current.dice.minimumRoll -
          (previous?.dice.minimumRoll ?? current.dice.minimumRoll),
      diceCeilDelta:
          current.dice.maximumRoll -
          (previous?.dice.maximumRoll ?? current.dice.maximumRoll),
    );
  }
}
