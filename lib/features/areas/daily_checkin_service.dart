// ============================================================================
// FILE: lib/features/areas/daily_checkin_service.dart
//
// O que faz:
// - Gerencia as perguntas diárias do usuário
// - Usa perguntas adaptadas ao tipo de subárea
// - Salva respostas graduais por usuário no Hive
// - Marca o check-in do dia como concluído
// - Informa se o usuário já pode usar o Areas
// - Escolhe perguntas de forma adaptativa com base no histórico recente
//
// Ajustes desta versão:
// - adiciona tipos de escala por pergunta
// - adiciona itemIds para ligar cada pergunta às subáreas corretas
// - usa somente a escala nova 0..4
// - permite o AreasStore calcular score por múltiplas perguntas
//
// Correção desta versão:
// - remove a conversão legada 0/1 -> 0/4
// - corrige o bug em que a 2ª opção era lida como a última
// ============================================================================
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum DailyQuestionScaleType {
  quality5,
  frequency5,
  intensity5,
  balance5,
  agreement5,
}

class DailyQuestion {
  const DailyQuestion({
    required this.id,
    required this.areaId,
    required this.itemIds,
    required this.text,
    required this.scaleType,
    this.priorityBoost = 0,
  });

  final String id;
  final String areaId;
  final List<String> itemIds;
  final String text;
  final DailyQuestionScaleType scaleType;
  final double priorityBoost;
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

  static const List<DailyQuestion> _pool = [
    // BODY HEALTH
    DailyQuestion(
      id: 'sleep_ok',
      areaId: 'body_health',
      itemIds: ['sleep', 'energy'],
      text: 'Como esteve a qualidade do seu sono na última noite?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.25,
    ),
    DailyQuestion(
      id: 'move',
      areaId: 'body_health',
      itemIds: ['movement'],
      text: 'Quanto você se movimentou, caminhou ou treinou hoje?',
      scaleType: DailyQuestionScaleType.frequency5,
      priorityBoost: 0.35,
    ),
    DailyQuestion(
      id: 'nutrition_ok',
      areaId: 'body_health',
      itemIds: ['nutrition'],
      text: 'Como esteve sua alimentação hoje?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.35,
    ),
    DailyQuestion(
      id: 'hydration_ok',
      areaId: 'body_health',
      itemIds: ['nutrition'],
      text: 'Como foi seu cuidado com água e hidratação hoje?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.18,
    ),
    DailyQuestion(
      id: 'energy_ok',
      areaId: 'body_health',
      itemIds: ['energy'],
      text: 'Como esteve sua energia ao longo do dia?',
      scaleType: DailyQuestionScaleType.intensity5,
      priorityBoost: 0.35,
    ),

    // MIND / EMOTION
    DailyQuestion(
      id: 'focus',
      areaId: 'mind_emotion',
      itemIds: ['focus', 'distraction'],
      text: 'Como esteve seu foco em algo importante hoje?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.35,
    ),
    DailyQuestion(
      id: 'stress_ok',
      areaId: 'mind_emotion',
      itemIds: ['stress', 'mental_load'],
      text: 'Quanto seu estresse ficou sob controle hoje?',
      scaleType: DailyQuestionScaleType.balance5,
      priorityBoost: 0.4,
    ),
    DailyQuestion(
      id: 'mood_ok',
      areaId: 'mind_emotion',
      itemIds: ['mood'],
      text: 'Como esteve seu humor hoje?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.35,
    ),
    DailyQuestion(
      id: 'mental_recovery',
      areaId: 'mind_emotion',
      itemIds: ['mental_load', 'mood'],
      text:
          'Você conseguiu ter pausas mentais ou se recuperar bem ao longo do dia?',
      scaleType: DailyQuestionScaleType.frequency5,
      priorityBoost: 0.22,
    ),

    // FINANCE
    DailyQuestion(
      id: 'fin_tx',
      areaId: 'finance_material',
      itemIds: ['budget'],
      text: 'Quanto você acompanhou ou registrou seus gastos hoje?',
      scaleType: DailyQuestionScaleType.frequency5,
      priorityBoost: 0.2,
    ),
    DailyQuestion(
      id: 'fin_control',
      areaId: 'finance_material',
      itemIds: ['spending', 'budget'],
      text: 'Quanto você conseguiu evitar gastos desnecessários hoje?',
      scaleType: DailyQuestionScaleType.balance5,
      priorityBoost: 0.2,
    ),

    // WORK / VOCATION
    DailyQuestion(
      id: 'routine_ok',
      areaId: 'work_vocation',
      itemIds: ['routine', 'consistency'],
      text: 'Como esteve sua organização de rotina hoje?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.35,
    ),
    DailyQuestion(
      id: 'day_planning',
      areaId: 'work_vocation',
      itemIds: ['routine', 'consistency'],
      text: 'Quanto você conseguiu seguir o que planejou para hoje?',
      scaleType: DailyQuestionScaleType.frequency5,
      priorityBoost: 0.22,
    ),

    // LEARNING
    DailyQuestion(
      id: 'study_ok',
      areaId: 'learning_intellect',
      itemIds: ['study'],
      text: 'Quanto você estudou ou aprendeu algo importante hoje?',
      scaleType: DailyQuestionScaleType.frequency5,
      priorityBoost: 0.35,
    ),
    DailyQuestion(
      id: 'study_quality',
      areaId: 'learning_intellect',
      itemIds: ['study', 'focus'],
      text: 'Se estudou, como foi a qualidade desse estudo?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.18,
    ),

    // RELATIONS
    DailyQuestion(
      id: 'social_ok',
      areaId: 'relations_community',
      itemIds: ['social_contact'],
      text: 'Como esteve sua conexão com alguém importante hoje?',
      scaleType: DailyQuestionScaleType.quality5,
      priorityBoost: 0.25,
    ),
    DailyQuestion(
      id: 'social_presence',
      areaId: 'relations_community',
      itemIds: ['social_contact'],
      text:
          'Você esteve presente de verdade nas suas conversas e relações hoje?',
      scaleType: DailyQuestionScaleType.agreement5,
      priorityBoost: 0.12,
    ),

    // DIGITAL
    DailyQuestion(
      id: 'digital_balance',
      areaId: 'digital_tech',
      itemIds: ['distraction'],
      text: 'Quanto você conseguiu controlar distrações digitais hoje?',
      scaleType: DailyQuestionScaleType.balance5,
      priorityBoost: 0.25,
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

  List<DailyQuestion> get allQuestions => List.unmodifiable(_pool);

  DailyQuestion? questionById(String id) => _questionById(id);

  List<DailyQuestion> questionsForItem(String itemId) {
    return _pool
        .where((q) => q.itemIds.contains(itemId))
        .toList(growable: false);
  }

  List<DailyAnswerOption> optionsFor(DailyQuestion question) {
    switch (question.scaleType) {
      case DailyQuestionScaleType.quality5:
        return const [
          DailyAnswerOption(
            value: 0,
            label: 'Muito ruim',
            shortLabel: 'Péssimo',
          ),
          DailyAnswerOption(value: 1, label: 'Ruim', shortLabel: 'Ruim'),
          DailyAnswerOption(
            value: 2,
            label: 'Mais ou menos',
            shortLabel: 'Médio',
          ),
          DailyAnswerOption(value: 3, label: 'Bom', shortLabel: 'Bom'),
          DailyAnswerOption(value: 4, label: 'Muito bom', shortLabel: 'Ótimo'),
        ];

      case DailyQuestionScaleType.frequency5:
        return const [
          DailyAnswerOption(value: 0, label: 'Nada', shortLabel: 'Nada'),
          DailyAnswerOption(value: 1, label: 'Pouco', shortLabel: 'Pouco'),
          DailyAnswerOption(value: 2, label: 'Moderado', shortLabel: 'Médio'),
          DailyAnswerOption(value: 3, label: 'Bastante', shortLabel: 'Bem'),
          DailyAnswerOption(value: 4, label: 'Muito', shortLabel: 'Muito'),
        ];

      case DailyQuestionScaleType.intensity5:
        return const [
          DailyAnswerOption(
            value: 0,
            label: 'Muito baixa',
            shortLabel: 'Muito baixa',
          ),
          DailyAnswerOption(value: 1, label: 'Baixa', shortLabel: 'Baixa'),
          DailyAnswerOption(value: 2, label: 'Média', shortLabel: 'Média'),
          DailyAnswerOption(value: 3, label: 'Boa', shortLabel: 'Boa'),
          DailyAnswerOption(value: 4, label: 'Muito boa', shortLabel: 'Ótima'),
        ];

      case DailyQuestionScaleType.balance5:
        return const [
          DailyAnswerOption(
            value: 0,
            label: 'Muito mal',
            shortLabel: 'Péssimo',
          ),
          DailyAnswerOption(value: 1, label: 'Mal', shortLabel: 'Ruim'),
          DailyAnswerOption(
            value: 2,
            label: 'Mais ou menos',
            shortLabel: 'Médio',
          ),
          DailyAnswerOption(value: 3, label: 'Bem', shortLabel: 'Bem'),
          DailyAnswerOption(value: 4, label: 'Muito bem', shortLabel: 'Ótimo'),
        ];

      case DailyQuestionScaleType.agreement5:
        return const [
          DailyAnswerOption(
            value: 0,
            label: 'Discordo totalmente',
            shortLabel: 'Nada',
          ),
          DailyAnswerOption(value: 1, label: 'Discordo', shortLabel: 'Pouco'),
          DailyAnswerOption(
            value: 2,
            label: 'Mais ou menos',
            shortLabel: 'Médio',
          ),
          DailyAnswerOption(value: 3, label: 'Concordo', shortLabel: 'Bem'),
          DailyAnswerOption(
            value: 4,
            label: 'Concordo muito',
            shortLabel: 'Muito',
          ),
        ];
    }
  }

  String answerLabel(int value, {DailyQuestion? question}) {
    final options = question == null ? _defaultOptions() : optionsFor(question);
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value.toString();
  }

  double normalizeAnswerValue(int value) =>
      _normalizeAnswerValueFromStored(value);

  int normalizeStoredValue({
    required String questionId,
    required int rawValue,
  }) {
    return rawValue.clamp(minAnswerValue, maxAnswerValue).toInt();
  }

  double normalizedProgress01({
    required String questionId,
    required int rawValue,
  }) {
    final normalized = normalizeStoredValue(
      questionId: questionId,
      rawValue: rawValue,
    );
    return normalized / maxAnswerValue;
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

    return selected.take(questionsPerDay).toList(growable: false);
  }

  Future<double> _priorityScore({
    required Box<dynamic> box,
    required DateTime now,
    required DailyQuestion question,
  }) async {
    double score = 1.0 + question.priorityBoost;

    for (var i = 1; i <= historyDays; i++) {
      final day = now.subtract(Duration(days: i));
      final raw = box.get(_answerKey(day, question.id));

      if (raw is! int) {
        score += 0.35;
        continue;
      }

      final normalizedStored = normalizeStoredValue(
        questionId: question.id,
        rawValue: raw,
      );
      final normalized = _normalizeAnswerValueFromStored(normalizedStored);
      final weight = (historyDays - i + 1) / historyDays;

      score += (1.0 - normalized) * 3.0 * weight;
      score += (normalized < 0.5 ? 0.8 : 0.0) * weight;
      score -= 0.18;
    }

    final yesterdayRaw = box.get(
      _answerKey(now.subtract(const Duration(days: 1)), question.id),
    );
    if (yesterdayRaw is int) {
      score -= 0.8;
    }

    final twoDaysAgoRaw = box.get(
      _answerKey(now.subtract(const Duration(days: 2)), question.id),
    );
    if (twoDaysAgoRaw is int) {
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
    final safeValue = value.clamp(minAnswerValue, maxAnswerValue).toInt();
    await box.put(_answerKey(day, questionId), safeValue);
  }

  Future<int?> getAnswer({
    required DateTime day,
    required String questionId,
  }) async {
    final box = await _open();
    final raw = box.get(_answerKey(day, questionId));

    if (raw is! int) return null;

    return raw.clamp(minAnswerValue, maxAnswerValue).toInt();
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

  List<DailyAnswerOption> _defaultOptions() {
    return const [
      DailyAnswerOption(value: 0, label: 'Nada', shortLabel: 'Nada'),
      DailyAnswerOption(value: 1, label: 'Pouco', shortLabel: 'Pouco'),
      DailyAnswerOption(value: 2, label: 'Médio', shortLabel: 'Médio'),
      DailyAnswerOption(value: 3, label: 'Bem', shortLabel: 'Bem'),
      DailyAnswerOption(value: 4, label: 'Excelente', shortLabel: 'Ótimo'),
    ];
  }

  double _normalizeAnswerValueFromStored(int stored) {
    final safe = stored.clamp(minAnswerValue, maxAnswerValue).toInt();
    return safe / maxAnswerValue;
  }
}

class _WeightedQuestion {
  const _WeightedQuestion({required this.question, required this.score});

  final DailyQuestion question;
  final double score;
}
