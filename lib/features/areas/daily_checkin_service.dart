// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// Fix:
// - Dados por usuário: box = 'daily_checkin_box_<uid>'
// ============================================================================

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DailyQuestion {
  const DailyQuestion({
    required this.id,
    required this.areaId,
    required this.text,
  });

  final String id;
  final String areaId;
  final String text;
}

class DailyCheckinService {
  static const _boxPrefix = 'daily_checkin_box_';

  String _uidOrAnon() {
    final u = FirebaseAuth.instance.currentUser;
    return (u?.uid ?? 'anon').trim().isEmpty ? 'anon' : u!.uid;
  }

  Future<Box<dynamic>> _open() =>
      Hive.openBox<dynamic>('$_boxPrefix${_uidOrAnon()}');

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String _completedKey(DateTime d) => '${_dayKey(d)}::completed';

  static const List<DailyQuestion> _pool = [
    DailyQuestion(
      id: 'fin_tx',
      areaId: 'finance_material',
      text: 'Você registrou seus gastos hoje?',
    ),
    DailyQuestion(
      id: 'fin_control',
      areaId: 'finance_material',
      text: 'Você evitou gastos desnecessários hoje?',
    ),
    DailyQuestion(
      id: 'sleep_ok',
      areaId: 'body_health',
      text: 'Você dormiu bem (ou está no caminho de dormir bem)?',
    ),
    DailyQuestion(
      id: 'move',
      areaId: 'body_health',
      text: 'Você se moveu (caminhou/treinou) hoje?',
    ),
    DailyQuestion(
      id: 'focus',
      areaId: 'mind_emotion',
      text: 'Você conseguiu manter o foco em algo importante hoje?',
    ),
  ];

  List<DailyQuestion> questionsForToday({required DateTime now}) {
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final r = Random(seed);

    final items = List<DailyQuestion>.from(_pool);
    items.shuffle(r);

    return items.take(5).toList();
  }

  Future<void> answer({
    required DateTime day,
    required String questionId,
    required int value,
  }) async {
    final box = await _open();
    await box.put('${_dayKey(day)}::$questionId', value);
  }

  Future<int?> getAnswer({
    required DateTime day,
    required String questionId,
  }) async {
    final box = await _open();
    final raw = box.get('${_dayKey(day)}::$questionId');
    return raw is int ? raw : null;
  }

  Future<bool> tryCompleteIfAllAnswered(DateTime day) async {
    final box = await _open();
    final qs = questionsForToday(now: day);

    for (final q in qs) {
      final v = box.get('${_dayKey(day)}::${q.id}');
      if (v is! int) return false;
    }

    await box.put(_completedKey(day), true);
    return true;
  }

  Future<bool> isCompleted(DateTime day) async {
    final box = await _open();
    final v = box.get(_completedKey(day));
    return v == true;
  }
}
