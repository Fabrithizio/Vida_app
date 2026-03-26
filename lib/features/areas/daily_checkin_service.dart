// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Gerencia as perguntas diárias do usuário
// - Salva respostas por usuário no Hive
// - Marca o check-in do dia como concluído
// - Informa se o usuário já pode usar o Areas
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

class DailyCheckinSummary {
  const DailyCheckinSummary({
    required this.total,
    required this.answered,
    required this.isCompleted,
  });

  final int total;
  final int answered;
  final bool isCompleted;

  int get remaining => total - answered;

  double get progress {
    if (total == 0) return 0;
    return answered / total;
  }
}

class DailyCheckinService {
  static const String _boxPrefix = 'daily_checkin_box_';
  static const int questionsPerDay = 5;

  static const List<DailyQuestion> _pool = [
    DailyQuestion(
      id: 'sleep_ok',
      areaId: 'body_health',
      text:
          'Você dormiu bem ou está conseguindo cuidar melhor do seu sono hoje?',
    ),
    DailyQuestion(
      id: 'move',
      areaId: 'body_health',
      text: 'Você se movimentou, caminhou ou treinou hoje?',
    ),
    DailyQuestion(
      id: 'nutrition_ok',
      areaId: 'body_health',
      text: 'Sua alimentação esteve razoável hoje?',
    ),
    DailyQuestion(
      id: 'energy_ok',
      areaId: 'body_health',
      text: 'Você teve uma energia boa na maior parte do dia?',
    ),
    DailyQuestion(
      id: 'focus',
      areaId: 'mind_emotion',
      text: 'Você conseguiu manter foco em algo importante hoje?',
    ),
    DailyQuestion(
      id: 'stress_ok',
      areaId: 'mind_emotion',
      text: 'Seu nível de estresse esteve controlado hoje?',
    ),
    DailyQuestion(
      id: 'mood_ok',
      areaId: 'mind_emotion',
      text: 'Seu humor esteve razoavelmente bem hoje?',
    ),
    DailyQuestion(
      id: 'fin_tx',
      areaId: 'finance_material',
      text: 'Você registrou ou acompanhou seus gastos hoje?',
    ),
    DailyQuestion(
      id: 'fin_control',
      areaId: 'finance_material',
      text: 'Você evitou gastos desnecessários hoje?',
    ),
    DailyQuestion(
      id: 'routine_ok',
      areaId: 'work_vocation',
      text: 'Sua rotina esteve minimamente organizada hoje?',
    ),
    DailyQuestion(
      id: 'study_ok',
      areaId: 'learning_intellect',
      text: 'Você estudou ou aprendeu algo importante hoje?',
    ),
    DailyQuestion(
      id: 'social_ok',
      areaId: 'relations_community',
      text: 'Você teve uma boa conexão com alguém hoje?',
    ),
  ];

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  Future<Box<dynamic>> _open() {
    return Hive.openBox<dynamic>('$_boxPrefix${_uidOrAnon()}');
  }

  String _dayKey(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _answerKey(DateTime d, String questionId) {
    return '${_dayKey(d)}::$questionId';
  }

  String _completedKey(DateTime d) {
    return '${_dayKey(d)}::completed';
  }

  List<DailyQuestion> questionsForToday({required DateTime now}) {
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);
    final items = List<DailyQuestion>.from(_pool);
    items.shuffle(random);
    return items.take(questionsPerDay).toList();
  }

  Future<void> answer({
    required DateTime day,
    required String questionId,
    required int value,
  }) async {
    final box = await _open();
    await box.put(_answerKey(day, questionId), value);
  }

  Future<int?> getAnswer({
    required DateTime day,
    required String questionId,
  }) async {
    final box = await _open();
    final raw = box.get(_answerKey(day, questionId));
    return raw is int ? raw : null;
  }

  Future<int> answeredCount(DateTime day) async {
    final box = await _open();
    final questions = questionsForToday(now: day);

    var count = 0;
    for (final question in questions) {
      final raw = box.get(_answerKey(day, question.id));
      if (raw is int) count++;
    }
    return count;
  }

  Future<bool> tryCompleteIfAllAnswered(DateTime day) async {
    final box = await _open();
    final questions = questionsForToday(now: day);

    for (final question in questions) {
      final raw = box.get(_answerKey(day, question.id));
      if (raw is! int) return false;
    }

    await box.put(_completedKey(day), true);
    return true;
  }

  Future<bool> isCompleted(DateTime day) async {
    final box = await _open();
    final raw = box.get(_completedKey(day));
    return raw == true;
  }

  Future<bool> canUseAreas(DateTime day) async {
    return isCompleted(day);
  }

  Future<DailyCheckinSummary> summary(DateTime day) async {
    final questions = questionsForToday(now: day);
    final answered = await answeredCount(day);
    final completed = await isCompleted(day);

    return DailyCheckinSummary(
      total: questions.length,
      answered: answered,
      isCompleted: completed,
    );
  }
}
