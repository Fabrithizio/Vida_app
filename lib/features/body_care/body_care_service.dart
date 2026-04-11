// ============================================================================
// FILE: lib/features/body_care/body_care_service.dart
//
// O que este arquivo faz:
// - Salva e lê os registros do módulo "Corpo em dia"
// - Mantém comida, treino, água, sono, passos, minutos ativos, peso e cintura
// - Salva um perfil corporal simples com altura, meta e peso-alvo
// - Calcula streak, IMC, resumo semanal e referência corporal básica
// - Preserva os dados de comida e treino usados no Meu Dia
// ============================================================================

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BodyCareAnswerOption {
  const BodyCareAnswerOption({
    required this.value,
    required this.label,
    required this.shortLabel,
    required this.description,
  });

  final int value;
  final String label;
  final String shortLabel;
  final String description;
}

class BodyCareEntry {
  const BodyCareEntry({
    this.food,
    this.training,
    this.water,
    this.sleep,
    this.steps,
    this.activeMinutes,
    this.weightKg,
    this.waistCm,
    this.note,
    this.updatedAt,
  });

  final int? food;
  final int? training;
  final int? water;
  final int? sleep;
  final int? steps;
  final int? activeMinutes;
  final double? weightKg;
  final double? waistCm;
  final String? note;
  final DateTime? updatedAt;

  double? get average {
    final values = [food, training, water, sleep].whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String get statusLabel {
    final avg = average;
    if (avg == null) return 'Sem registro';
    if (avg >= 3.6) return 'Muito focado';
    if (avg >= 2.6) return 'No caminho';
    if (avg >= 1.6) return 'Oscilando';
    if (avg >= 0.6) return 'Saiu da linha';
    return 'Dia bem fora';
  }

  bool get dedicatedDay => (food ?? 0) >= 3 && (training ?? 0) >= 3;

  BodyCareEntry copyWith({
    int? food,
    int? training,
    int? water,
    int? sleep,
    int? steps,
    int? activeMinutes,
    double? weightKg,
    double? waistCm,
    String? note,
    DateTime? updatedAt,
  }) {
    return BodyCareEntry(
      food: food ?? this.food,
      training: training ?? this.training,
      water: water ?? this.water,
      sleep: sleep ?? this.sleep,
      steps: steps ?? this.steps,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      weightKg: weightKg ?? this.weightKg,
      waistCm: waistCm ?? this.waistCm,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'food': food,
    'training': training,
    'water': water,
    'sleep': sleep,
    'steps': steps,
    'activeMinutes': activeMinutes,
    'weightKg': weightKg,
    'waistCm': waistCm,
    'note': note,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory BodyCareEntry.fromJson(Map<String, dynamic> json) {
    return BodyCareEntry(
      food: json['food'] as int?,
      training: json['training'] as int?,
      water: json['water'] as int?,
      sleep: json['sleep'] as int?,
      steps: json['steps'] as int?,
      activeMinutes: json['activeMinutes'] as int?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      note: json['note'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}

class BodyCareProfile {
  const BodyCareProfile({
    this.heightCm,
    this.targetWeightKg,
    this.goal,
    this.updatedAt,
  });

  final double? heightCm;
  final double? targetWeightKg;
  final String? goal;
  final DateTime? updatedAt;

  BodyCareProfile copyWith({
    double? heightCm,
    double? targetWeightKg,
    String? goal,
    DateTime? updatedAt,
  }) {
    return BodyCareProfile(
      heightCm: heightCm ?? this.heightCm,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      goal: goal ?? this.goal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'heightCm': heightCm,
    'targetWeightKg': targetWeightKg,
    'goal': goal,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory BodyCareProfile.fromJson(Map<String, dynamic> json) {
    return BodyCareProfile(
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      goal: json['goal'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}

class BodyCareWeekPoint {
  const BodyCareWeekPoint({required this.day, required this.score});

  final DateTime day;
  final double? score;
}

class BodyCareOverview {
  const BodyCareOverview({
    required this.currentStreak,
    required this.weeklyFocusedDays,
    required this.weeklyAverageFood,
    required this.weeklyAverageTraining,
    required this.latestWeightKg,
    required this.weightDeltaKg,
    required this.bmi,
    required this.bmiLabel,
    required this.goalLabel,
    required this.referenceWeightLabel,
    required this.referenceWeightHint,
    required this.ageYears,
    required this.insight,
    required this.quickTips,
  });

  final int currentStreak;
  final int weeklyFocusedDays;
  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;
  final double? latestWeightKg;
  final double? weightDeltaKg;
  final double? bmi;
  final String bmiLabel;
  final String goalLabel;
  final String referenceWeightLabel;
  final String referenceWeightHint;
  final int? ageYears;
  final String insight;
  final List<String> quickTips;

  factory BodyCareOverview.empty() {
    return const BodyCareOverview(
      currentStreak: 0,
      weeklyFocusedDays: 0,
      weeklyAverageFood: null,
      weeklyAverageTraining: null,
      latestWeightKg: null,
      weightDeltaKg: null,
      bmi: null,
      bmiLabel: 'Sem dados',
      goalLabel: 'Sem meta definida',
      referenceWeightLabel: '--',
      referenceWeightHint: 'Preencha sua altura para liberar mais métricas.',
      ageYears: null,
      insight:
          'Comece pelo básico: registre comida, movimento, água e sono para enxergar seu padrão.',
      quickTips: [
        'Organize o básico antes de pensar em perfeição.',
        'Água, sono e comida boa já mudam muito o jogo.',
        'Treino leve e constante vale mais do que picos raros.',
      ],
    );
  }
}

class BodyCareService {
  static const List<String> goalOptions = [
    'Emagrecer',
    'Ganhar massa',
    'Definir o corpo',
    'Manter o peso',
    'Saúde geral',
  ];

  static const List<BodyCareAnswerOption> foodOptions = [
    BodyCareAnswerOption(
      value: 0,
      label: 'Chutei o balde',
      shortLabel: 'Balde',
      description: 'Dia bem fora da linha, com excesso e pouco cuidado.',
    ),
    BodyCareAnswerOption(
      value: 1,
      label: 'Ruim',
      shortLabel: 'Ruim',
      description: 'Teve muito descontrole e pouca comida que ajuda seu corpo.',
    ),
    BodyCareAnswerOption(
      value: 2,
      label: 'Mais ou menos',
      shortLabel: 'Médio',
      description: 'Ficou no meio do caminho, sem tanta constância.',
    ),
    BodyCareAnswerOption(
      value: 3,
      label: 'Boa',
      shortLabel: 'Boa',
      description:
          'Na maior parte do dia, você comeu de um jeito bom para o corpo.',
    ),
    BodyCareAnswerOption(
      value: 4,
      label: 'Mandou bem',
      shortLabel: 'Ótima',
      description: 'Seu dia ficou bem alinhado com seu objetivo corporal.',
    ),
  ];

  static const List<BodyCareAnswerOption> trainingOptions = [
    BodyCareAnswerOption(
      value: 0,
      label: 'Nada',
      shortLabel: 'Nada',
      description: 'Você não treinou e quase não se mexeu.',
    ),
    BodyCareAnswerOption(
      value: 1,
      label: 'Muito pouco',
      shortLabel: 'Pouco',
      description: 'Teve pouco movimento no dia.',
    ),
    BodyCareAnswerOption(
      value: 2,
      label: 'Mais ou menos',
      shortLabel: 'Médio',
      description: 'Você se mexeu, mas sem tanto ritmo.',
    ),
    BodyCareAnswerOption(
      value: 3,
      label: 'Bom',
      shortLabel: 'Bom',
      description: 'Seu corpo teve um bom nível de movimento.',
    ),
    BodyCareAnswerOption(
      value: 4,
      label: 'Mandou bem',
      shortLabel: 'Ótimo',
      description: 'Você treinou bem ou se mexeu muito bem no dia.',
    ),
  ];

  static const List<BodyCareAnswerOption> waterOptions = [
    BodyCareAnswerOption(
      value: 0,
      label: 'Quase nada',
      shortLabel: 'Baixa',
      description: 'Você ficou bem abaixo do ideal de água.',
    ),
    BodyCareAnswerOption(
      value: 1,
      label: 'Pouca',
      shortLabel: 'Pouca',
      description: 'Tomou água, mas menos do que precisava.',
    ),
    BodyCareAnswerOption(
      value: 2,
      label: 'Média',
      shortLabel: 'Média',
      description: 'Ficou razoável, mas ainda dava para caprichar.',
    ),
    BodyCareAnswerOption(
      value: 3,
      label: 'Boa',
      shortLabel: 'Boa',
      description: 'Seu cuidado com água foi bom no dia.',
    ),
    BodyCareAnswerOption(
      value: 4,
      label: 'Muito boa',
      shortLabel: 'Ótima',
      description: 'Você hidratou seu corpo muito bem.',
    ),
  ];

  static const List<BodyCareAnswerOption> sleepOptions = [
    BodyCareAnswerOption(
      value: 0,
      label: 'Péssimo',
      shortLabel: 'Péssimo',
      description: 'Seu corpo não descansou como precisava.',
    ),
    BodyCareAnswerOption(
      value: 1,
      label: 'Ruim',
      shortLabel: 'Ruim',
      description: 'O descanso ficou abaixo do que faria bem.',
    ),
    BodyCareAnswerOption(
      value: 2,
      label: 'Mais ou menos',
      shortLabel: 'Médio',
      description: 'Ficou aceitável, mas dava para melhorar.',
    ),
    BodyCareAnswerOption(
      value: 3,
      label: 'Bom',
      shortLabel: 'Bom',
      description: 'Seu corpo descansou bem.',
    ),
    BodyCareAnswerOption(
      value: 4,
      label: 'Muito bom',
      shortLabel: 'Ótimo',
      description: 'Você recuperou bem o corpo e a energia.',
    ),
  ];

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  String _uid() => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String keyForDay(DateTime day) {
    final d = dayOnly(day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _daysStorageKey() => '${_uid()}:body_care_days';

  String _profileStorageKey() => '${_uid()}:body_care_profile';

  Future<Map<String, dynamic>> _loadRawDaysMap() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_daysStorageKey());
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<void> _saveRawDaysMap(Map<String, dynamic> map) async {
    final prefs = await _prefs();
    await prefs.setString(_daysStorageKey(), jsonEncode(map));
  }

  Future<BodyCareProfile> loadProfile() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_profileStorageKey());
    if (raw == null || raw.trim().isEmpty) return const BodyCareProfile();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>)
      return BodyCareProfile.fromJson(decoded);
    if (decoded is Map)
      return BodyCareProfile.fromJson(Map<String, dynamic>.from(decoded));
    return const BodyCareProfile();
  }

  Future<void> saveProfile(BodyCareProfile profile) async {
    final prefs = await _prefs();
    await prefs.setString(
      _profileStorageKey(),
      jsonEncode(profile.copyWith(updatedAt: DateTime.now()).toJson()),
    );
  }

  Future<BodyCareEntry> loadDay(DateTime day) async {
    final raw = await _loadRawDaysMap();
    final value = raw[keyForDay(day)];
    if (value is Map<String, dynamic>) return BodyCareEntry.fromJson(value);
    if (value is Map)
      return BodyCareEntry.fromJson(Map<String, dynamic>.from(value));
    return const BodyCareEntry();
  }

  Future<void> saveDay(DateTime day, BodyCareEntry entry) async {
    final raw = await _loadRawDaysMap();
    raw[keyForDay(day)] = entry.copyWith(updatedAt: DateTime.now()).toJson();
    await _saveRawDaysMap(raw);
  }

  Future<void> saveFood(DateTime day, int value) async {
    final record = await loadDay(day);
    await saveDay(day, record.copyWith(food: value.clamp(0, 4)));
  }

  Future<void> saveTraining(DateTime day, int value) async {
    final record = await loadDay(day);
    await saveDay(day, record.copyWith(training: value.clamp(0, 4)));
  }

  Future<void> saveWater(DateTime day, int value) async {
    final record = await loadDay(day);
    await saveDay(day, record.copyWith(water: value.clamp(0, 4)));
  }

  Future<void> saveSleep(DateTime day, int value) async {
    final record = await loadDay(day);
    await saveDay(day, record.copyWith(sleep: value.clamp(0, 4)));
  }

  Future<void> saveWeight(DateTime day, double? value) async {
    final record = await loadDay(day);
    await saveDay(day, record.copyWith(weightKg: value));
  }

  Future<void> saveNote(DateTime day, String? note) async {
    final record = await loadDay(day);
    final clean = note?.trim();
    await saveDay(
      day,
      record.copyWith(note: (clean == null || clean.isEmpty) ? null : clean),
    );
  }

  Future<List<MapEntry<DateTime, BodyCareEntry>>> loadRecentEntries({
    int days = 21,
  }) async {
    final raw = await _loadRawDaysMap();
    final out = <MapEntry<DateTime, BodyCareEntry>>[];
    raw.forEach((key, value) {
      final parsedDay = DateTime.tryParse(key);
      if (parsedDay == null) return;
      if (value is Map<String, dynamic>) {
        out.add(MapEntry(dayOnly(parsedDay), BodyCareEntry.fromJson(value)));
      } else if (value is Map) {
        out.add(
          MapEntry(
            dayOnly(parsedDay),
            BodyCareEntry.fromJson(Map<String, dynamic>.from(value)),
          ),
        );
      }
    });
    out.sort((a, b) => b.key.compareTo(a.key));
    return out.take(days).toList();
  }

  Future<Map<String, BodyCareEntry>> loadRangeMap(List<DateTime> days) async {
    final out = <String, BodyCareEntry>{};
    for (final day in days) {
      out[keyForDay(day)] = await loadDay(day);
    }
    return out;
  }

  Future<List<BodyCareWeekPoint>> last7Days(DateTime anchorDay) async {
    final base = dayOnly(anchorDay);
    final out = <BodyCareWeekPoint>[];
    for (int i = 6; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      final record = await loadDay(day);
      out.add(BodyCareWeekPoint(day: day, score: record.average));
    }
    return out;
  }

  Future<int> dedicatedStreak(DateTime anchorDay) async {
    int streak = 0;
    final base = dayOnly(anchorDay);
    for (int i = 0; i < 30; i++) {
      final day = base.subtract(Duration(days: i));
      final record = await loadDay(day);
      if (record.dedicatedDay) {
        streak += 1;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<DateTime?> _loadBirthDate() async {
    final prefs = await _prefs();
    final uid = _uid();
    final raw =
        prefs.getString('birth_date_$uid') ??
        prefs.getString('$uid:birthDate') ??
        prefs.getString('$uid:birthdate') ??
        prefs.getString('$uid:dateOfBirth') ??
        prefs.getString('$uid:dob');
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  int? _ageFromBirthDate(DateTime? birthDate, DateTime now) {
    if (birthDate == null) return null;
    int age = now.year - birthDate.year;
    final hadBirthday =
        (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age -= 1;
    return age < 0 ? null : age;
  }

  double? calculateBmi({required double? weightKg, required double? heightCm}) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;
    final h = heightCm / 100.0;
    if (h <= 0) return null;
    return double.parse((weightKg / (h * h)).toStringAsFixed(1));
  }

  String bmiLabel(double? bmi, {required int? ageYears}) {
    if (bmi == null) return 'Sem dados';
    if (ageYears != null && ageYears < 18) return 'Em desenvolvimento';
    if (bmi < 18.5) return 'Abaixo';
    if (bmi < 25) return 'Adequado';
    if (bmi < 30) return 'Acima';
    return 'Obesidade';
  }

  ({String label, String hint}) referenceWeightInfo({
    required double? heightCm,
    required int? ageYears,
  }) {
    if (heightCm == null || heightCm <= 0) {
      return (
        label: '--',
        hint: 'Preencha sua altura para liberar a referência corporal.',
      );
    }
    if (ageYears != null && ageYears < 18) {
      return (
        label: 'Em desenvolvimento',
        hint:
            'Na adolescência, o foco principal é evolução de hábitos, energia, sono e acompanhamento responsável.',
      );
    }
    final h = heightCm / 100.0;
    final min = 18.5 * h * h;
    final max = 24.9 * h * h;
    return (
      label: '${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} kg',
      hint: 'Faixa de referência geral para adulto pela altura.',
    );
  }

  int focusScore(BodyCareEntry entry) {
    final parts = <double>[];
    if (entry.food != null) parts.add(entry.food!.toDouble());
    if (entry.training != null) parts.add(entry.training!.toDouble());
    if (entry.water != null) parts.add(entry.water!.toDouble());
    if (entry.sleep != null) parts.add(entry.sleep!.toDouble());
    if (parts.isEmpty) return 0;
    final avg = parts.reduce((a, b) => a + b) / parts.length;
    return avg.round().clamp(0, 4);
  }

  String _goalLabel(BodyCareProfile profile) {
    final goal = (profile.goal ?? '').trim();
    if (goal.isEmpty) return 'Sem meta definida';
    if (profile.targetWeightKg != null) {
      return '$goal · alvo ${profile.targetWeightKg!.toStringAsFixed(1)}kg';
    }
    return goal;
  }

  String _buildInsight({
    required BodyCareEntry latest,
    required int streak,
    required int weeklyFocusedDays,
  }) {
    if ((latest.food ?? -1) >= 3 && (latest.training ?? -1) >= 3) {
      if (streak >= 4) {
        return 'Você está encaixando comida e movimento juntos. A sequência já começou a virar rotina.';
      }
      return 'Seu último dia foi alinhado. Repetir o básico é o que faz a evolução aparecer.';
    }
    if ((latest.food ?? -1) >= 3 && (latest.training ?? -1) < 3) {
      return 'A comida já está melhor. O próximo passo é subir o nível do movimento.';
    }
    if ((latest.training ?? -1) >= 3 && (latest.food ?? -1) < 3) {
      return 'Você já está se mexendo. Agora vale proteger melhor o resultado com a alimentação.';
    }
    if (weeklyFocusedDays >= 3) {
      return 'Mesmo com oscilações, você já conseguiu alguns dias bons nesta semana. Continue empilhando dias úteis.';
    }
    return 'Volte ao simples: comida melhor, mais água, algum movimento e sono menos bagunçado.';
  }

  List<String> _buildTips({
    required BodyCareEntry latest,
    required BodyCareProfile profile,
  }) {
    final tips = <String>[];

    if ((latest.food ?? 0) <= 2) {
      tips.add('Monte refeições com mais comida de verdade e menos improviso.');
    }
    if ((latest.training ?? 0) <= 2) {
      tips.add(
        'Mesmo 20 a 30 minutos de movimento já ajudam a manter o ritmo.',
      );
    }
    if ((latest.water ?? 0) <= 2) {
      tips.add(
        'Água distribuída ao longo do dia costuma ser mais fácil do que compensar depois.',
      );
    }
    if ((latest.sleep ?? 0) <= 2) {
      tips.add(
        'Sono ruim costuma derrubar treino, fome e foco no dia seguinte.',
      );
    }

    final goal = (profile.goal ?? '').trim().toLowerCase();
    if (goal.contains('emag')) {
      tips.add(
        'Para emagrecer, constância vence radicalismo. Melhor vários dias bons do que um perfeito.',
      );
    } else if (goal.contains('massa')) {
      tips.add(
        'Para ganhar massa, comida suficiente e treino consistente precisam andar juntos.',
      );
    } else if (goal.contains('defin')) {
      tips.add(
        'Definição vem de boa constância, não só de um treino forte isolado.',
      );
    }

    while (tips.length < 3) {
      tips.add(
        'Registre seu dia por algumas semanas antes de tirar conclusões sobre seu corpo.',
      );
    }

    return tips.take(3).toList();
  }

  Future<BodyCareOverview> loadOverview() async {
    final profile = await loadProfile();
    final items = await loadRecentEntries(days: 30);
    final birthDate = await _loadBirthDate();
    final ageYears = _ageFromBirthDate(birthDate, DateTime.now());

    if (items.isEmpty) {
      final ref = referenceWeightInfo(
        heightCm: profile.heightCm,
        ageYears: ageYears,
      );
      return BodyCareOverview.empty().copyWith(
        bmi: calculateBmi(weightKg: null, heightCm: profile.heightCm),
        bmiLabel: bmiLabel(null, ageYears: ageYears),
        goalLabel: _goalLabel(profile),
        referenceWeightLabel: ref.label,
        referenceWeightHint: ref.hint,
        ageYears: ageYears,
      );
    }

    final latest = items.first.value;
    final today = dayOnly(DateTime.now());
    final weekItems = items
        .where((e) => today.difference(e.key).inDays < 7)
        .toList();

    int streak = 0;
    DateTime? expected;
    for (final pair in items) {
      final day = pair.key;
      final entry = pair.value;
      final goodDay = focusScore(entry) >= 3;
      if (!goodDay) break;
      if (expected != null && dayOnly(expected) != day) break;
      streak += 1;
      expected = day.subtract(const Duration(days: 1));
    }

    final weeklyFocusedDays = weekItems
        .where((e) => focusScore(e.value) >= 3)
        .length;

    final weeklyFoodValues = weekItems
        .map((e) => e.value.food)
        .whereType<int>()
        .toList();
    final weeklyTrainingValues = weekItems
        .map((e) => e.value.training)
        .whereType<int>()
        .toList();

    final weeklyAverageFood = weeklyFoodValues.isEmpty
        ? null
        : weeklyFoodValues.reduce((a, b) => a + b) / weeklyFoodValues.length;
    final weeklyAverageTraining = weeklyTrainingValues.isEmpty
        ? null
        : weeklyTrainingValues.reduce((a, b) => a + b) /
              weeklyTrainingValues.length;

    final weights = items
        .map((e) => e.value.weightKg)
        .whereType<double>()
        .toList();
    final latestWeight = weights.isNotEmpty ? weights.first : null;
    final olderWeight = weights.length >= 2 ? weights.last : null;
    final weightDelta = (latestWeight != null && olderWeight != null)
        ? double.parse((latestWeight - olderWeight).toStringAsFixed(1))
        : null;

    final bmi = calculateBmi(
      weightKg: latestWeight,
      heightCm: profile.heightCm,
    );
    final ref = referenceWeightInfo(
      heightCm: profile.heightCm,
      ageYears: ageYears,
    );

    return BodyCareOverview(
      currentStreak: streak,
      weeklyFocusedDays: weeklyFocusedDays,
      weeklyAverageFood: weeklyAverageFood,
      weeklyAverageTraining: weeklyAverageTraining,
      latestWeightKg: latestWeight,
      weightDeltaKg: weightDelta,
      bmi: bmi,
      bmiLabel: bmiLabel(bmi, ageYears: ageYears),
      goalLabel: _goalLabel(profile),
      referenceWeightLabel: ref.label,
      referenceWeightHint: ref.hint,
      ageYears: ageYears,
      insight: _buildInsight(
        latest: latest,
        streak: streak,
        weeklyFocusedDays: weeklyFocusedDays,
      ),
      quickTips: _buildTips(latest: latest, profile: profile),
    );
  }
}

extension on BodyCareOverview {
  BodyCareOverview copyWith({
    int? currentStreak,
    int? weeklyFocusedDays,
    double? weeklyAverageFood,
    double? weeklyAverageTraining,
    double? latestWeightKg,
    double? weightDeltaKg,
    double? bmi,
    String? bmiLabel,
    String? goalLabel,
    String? referenceWeightLabel,
    String? referenceWeightHint,
    int? ageYears,
    String? insight,
    List<String>? quickTips,
  }) {
    return BodyCareOverview(
      currentStreak: currentStreak ?? this.currentStreak,
      weeklyFocusedDays: weeklyFocusedDays ?? this.weeklyFocusedDays,
      weeklyAverageFood: weeklyAverageFood ?? this.weeklyAverageFood,
      weeklyAverageTraining:
          weeklyAverageTraining ?? this.weeklyAverageTraining,
      latestWeightKg: latestWeightKg ?? this.latestWeightKg,
      weightDeltaKg: weightDeltaKg ?? this.weightDeltaKg,
      bmi: bmi ?? this.bmi,
      bmiLabel: bmiLabel ?? this.bmiLabel,
      goalLabel: goalLabel ?? this.goalLabel,
      referenceWeightLabel: referenceWeightLabel ?? this.referenceWeightLabel,
      referenceWeightHint: referenceWeightHint ?? this.referenceWeightHint,
      ageYears: ageYears ?? this.ageYears,
      insight: insight ?? this.insight,
      quickTips: quickTips ?? this.quickTips,
    );
  }
}
