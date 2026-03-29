// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Gerencia as perguntas diárias do usuário
// - Salva respostas graduais por usuário no Hive
// - Marca o check-in do dia como concluído
// - Informa se o usuário já pode usar o Areas
// - Escolhe perguntas de forma adaptativa com base no histórico recente
//
// Ajustes desta versão:
// - histórico ampliado para 14 dias
// - respostas agora usam escala gradual de 0 a 4
// - adiciona metadados das opções para o sheet reutilizar sem duplicar regra
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

class DailyAnswerOption {
  const DailyAnswerOption({
    required this.value,
    required this.label,
    required this.shortLabel,
  });

  final int value;
  final String label;
  final String shortLabel;
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
  static const int historyDays = 14;
  static const int minAnswerValue = 0;
  static const int maxAnswerValue = 4;

  static const List<DailyAnswerOption> answerOptions = [
    DailyAnswerOption(value: 0, label: 'Nada', shortLabel: 'Nada'),
    DailyAnswerOption(value: 1, label: 'Pouco', shortLabel: 'Pouco'),
    DailyAnswerOption(value: 2, label: 'Médio', shortLabel: 'Médio'),
    DailyAnswerOption(value: 3, label: 'Bem', shortLabel: 'Bem'),
    DailyAnswerOption(value: 4, label: 'Excelente', shortLabel: 'Ótimo'),
  ];

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
      text: 'Quanto você se movimentou, caminhou ou treinou hoje?',
    ),
    DailyQuestion(
      id: 'nutrition_ok',
      areaId: 'body_health',
      text: 'Como esteve sua alimentação hoje?',
    ),
    DailyQuestion(
      id: 'energy_ok',
      areaId: 'body_health',
      text: 'Como esteve sua energia ao longo do dia?',
    ),
    DailyQuestion(
      id: 'focus',
      areaId: 'mind_emotion',
      text: 'Como esteve seu foco em algo importante hoje?',
    ),
    DailyQuestion(
      id: 'stress_ok',
      areaId: 'mind_emotion',
      text: 'Quanto seu estresse ficou sob controle hoje?',
    ),
    DailyQuestion(
      id: 'mood_ok',
      areaId: 'mind_emotion',
      text: 'Como esteve seu humor hoje?',
    ),
    DailyQuestion(
      id: 'fin_tx',
      areaId: 'finance_material',
      text: 'Quanto você acompanhou ou registrou seus gastos hoje?',
    ),
    DailyQuestion(
      id: 'fin_control',
      areaId: 'finance_material',
      text: 'Quanto você conseguiu evitar gastos desnecessários hoje?',
    ),
    DailyQuestion(
      id: 'routine_ok',
      areaId: 'work_vocation',
      text: 'Como esteve sua organização de rotina hoje?',
    ),
    DailyQuestion(
      id: 'study_ok',
      areaId: 'learning_intellect',
      text: 'Quanto você estudou ou aprendeu algo importante hoje?',
    ),
    DailyQuestion(
      id: 'social_ok',
      areaId: 'relations_community',
      text: 'Como esteve sua conexão com alguém importante hoje?',
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

    for (var i = 1; i <= historyDays; i++) {
      final day = now.subtract(Duration(days: i));
      final raw = box.get(_answerKey(day, question.id));

      if (raw is int) {
        final normalized = _normalizeAnswer(raw);
        final weight = (historyDays - i + 1) / historyDays;

        score += (1.0 - normalized) * 3.2 * weight;
        score += (normalized < 0.5 ? 0.8 : 0.0) * weight;
        score -= 0.18;
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

  double normalizeAnswerValue(int value) => _normalizeAnswer(value);

  String answerLabel(int value) {
    for (final option in answerOptions) {
      if (option.value == value) return option.label;
    }
    return value.toString();
  }

  Future<void> answer({
    required DateTime day,
    required String questionId,
    required int value,
  }) async {
    final box = await _open();
    final safeValue = value.clamp(minAnswerValue, maxAnswerValue).toInt();
    await box.put(_answerKey(day, questionId), safeValue);
  }

  Future<int?> getAnswer({
    required DateTime day,
    required String questionId,
  }) async {
    final box = await _open();
    final raw = box.get(_answerKey(day, questionId));
    return raw is int
        ? raw.clamp(minAnswerValue, maxAnswerValue).toInt()
        : null;
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

  double _normalizeAnswer(int raw) {
    final safe = raw.clamp(minAnswerValue, maxAnswerValue).toInt();
    return safe / maxAnswerValue;
  }
}

class _WeightedQuestion {
  const _WeightedQuestion({required this.question, required this.score});

  final DailyQuestion question;
  final double score;
}
