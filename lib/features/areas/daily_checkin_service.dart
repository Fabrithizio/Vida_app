// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Gerencia as perguntas diárias do usuário
// - Salva respostas por usuário no Hive
// - Marca o check-in do dia como concluído
// - Informa se o usuário já pode usar o Areas
// - Agora escolhe perguntas de forma adaptativa com base no histórico recente
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
  static const int _historyDays = 7;

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

  String _questionsCacheKey(DateTime d) {
    return '${_dayKey(d)}::questions';
  }

  Future<List<DailyQuestion>> questionsForToday({required DateTime now}) async {
    final box = await _open();
    final cacheKey = _questionsCacheKey(now);

    final cached = box.get(cacheKey);
    if (cached is List) {
      final ids = cached.whereType<String>().toList();
      final restored = ids
          .map(_questionById)
          .whereType<DailyQuestion>()
          .toList();

      if (restored.length == questionsPerDay) {
        return restored;
      }
    }

    final selected = await _buildAdaptiveQuestions(now);
    await box.put(cacheKey, selected.map((q) => q.id).toList());
    return selected;
  }

  Future<List<DailyQuestion>> _buildAdaptiveQuestions(DateTime now) async {
    final box = await _open();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = Random(seed);

    final candidates = <_WeightedQuestion>[];

    for (final question in _pool) {
      final score = await _priorityScore(
        box: box,
        now: now,
        question: question,
      );

      candidates.add(
        _WeightedQuestion(
          question: question,
          score: score + random.nextDouble() * 0.25,
        ),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final selected = <DailyQuestion>[];
    final usedAreas = <String>{};

    for (final item in candidates) {
      if (selected.length >= questionsPerDay) break;

      final q = item.question;

      if (!usedAreas.contains(q.areaId)) {
        selected.add(q);
        usedAreas.add(q.areaId);
      }
    }

    if (selected.length < questionsPerDay) {
      for (final item in candidates) {
        if (selected.length >= questionsPerDay) break;
        if (selected.any((q) => q.id == item.question.id)) continue;
        selected.add(item.question);
      }
    }

    return selected.take(questionsPerDay).toList();
  }

  Future<double> _priorityScore({
    required Box<dynamic> box,
    required DateTime now,
    required DailyQuestion question,
  }) async {
    double score = 1.0;

    for (var i = 1; i <= _historyDays; i++) {
      final day = now.subtract(Duration(days: i));
      final raw = box.get(_answerKey(day, question.id));

      if (raw is int) {
        final weight = (_historyDays - i + 1) / _historyDays;

        if (raw == 0) {
          score += 3.0 * weight;
        } else if (raw == 1) {
          score += 0.6 * weight;
        }

        score -= 0.45;
      }
    }

    final yesterday = box.get(
      _answerKey(now.subtract(const Duration(days: 1)), question.id),
    );
    if (yesterday is int) {
      score -= 0.8;
    }

    final twoDaysAgo = box.get(
      _answerKey(now.subtract(const Duration(days: 2)), question.id),
    );
    if (twoDaysAgo is int) {
      score -= 0.35;
    }

    return score;
  }

  DailyQuestion? _questionById(String id) {
    for (final q in _pool) {
      if (q.id == id) return q;
    }
    return null;
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
    final questions = await questionsForToday(now: day);

    var count = 0;
    for (final question in questions) {
      final raw = box.get(_answerKey(day, question.id));
      if (raw is int) count++;
    }
    return count;
  }

  Future<bool> tryCompleteIfAllAnswered(DateTime day) async {
    final box = await _open();
    final questions = await questionsForToday(now: day);

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
    final questions = await questionsForToday(now: day);
    final answered = await answeredCount(day);
    final completed = await isCompleted(day);

    return DailyCheckinSummary(
      total: questions.length,
      answered: answered,
      isCompleted: completed,
    );
  }
}

class _WeightedQuestion {
  const _WeightedQuestion({required this.question, required this.score});

  final DailyQuestion question;
  final double score;
}
