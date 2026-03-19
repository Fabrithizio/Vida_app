// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// Check-in diário:
// - 5 perguntas por dia, estáveis por data
// - salva respostas (0/1)
// - marca o dia como "completed" quando todas foram respondidas
// ============================================================================

import 'dart:math';

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
  static const _boxName = 'daily_checkin_box';

  Future<Box<dynamic>> _open() => Hive.openBox<dynamic>(_boxName);

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
      id: 'prod_tasks',
      areaId: 'work_vocation',
      text: 'Você concluiu suas tarefas principais hoje?',
    ),
    DailyQuestion(
      id: 'study_progress',
      areaId: 'learning_intellect',
      text: 'Você avançou nos estudos hoje?',
    ),
    DailyQuestion(
      id: 'health_move',
      areaId: 'body_health',
      text: 'Você se movimentou hoje?',
    ),
    DailyQuestion(
      id: 'health_sleep',
      areaId: 'body_health',
      text: 'Seu sono foi bom na última noite?',
    ),
    DailyQuestion(
      id: 'mind_mood',
      areaId: 'mind_emotion',
      text: 'Seu humor hoje foi ok?',
    ),
    DailyQuestion(
      id: 'social_connect',
      areaId: 'relations_community',
      text: 'Você se conectou com alguém importante hoje?',
    ),
    DailyQuestion(
      id: 'digital_focus',
      areaId: 'digital_tech',
      text: 'Você controlou distrações digitais hoje?',
    ),
  ];

  List<DailyQuestion> questionsForToday({DateTime? now}) {
    final d = now ?? DateTime.now();
    final seed = int.parse(
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}',
    );
    final rng = Random(seed);
    final copy = List<DailyQuestion>.from(_pool)..shuffle(rng);
    return copy.take(5).toList();
  }

  Future<void> answer({
    required DateTime day,
    required String questionId,
    required int value, // 1 = sim, 0 = não
  }) async {
    final box = await _open();
    await box.put('${_dayKey(day)}::$questionId', value);
  }

  Future<int?> getAnswer({
    required DateTime day,
    required String questionId,
  }) async {
    final box = await _open();
    final v = box.get('${_dayKey(day)}::$questionId');
    return v is int ? v : null;
  }

  Future<bool> isCompleted(DateTime day) async {
    final box = await _open();
    final v = box.get(_completedKey(day));
    return v is bool ? v : false;
  }

  Future<void> markCompleted(DateTime day) async {
    final box = await _open();
    await box.put(_completedKey(day), true);
  }

  Future<bool> tryCompleteIfAllAnswered(DateTime day) async {
    final questions = questionsForToday(now: day);
    for (final q in questions) {
      final a = await getAnswer(day: day, questionId: q.id);
      if (a == null) return false;
    }
    await markCompleted(day);
    return true;
  }
}
