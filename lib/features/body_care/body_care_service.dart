// ============================================================================
// FILE: lib/features/body_care/body_care_service.dart
//
// O que este arquivo faz:
// - Salva e lê os registros do módulo "Corpo & Saúde"
// - Mantém comida, treino, água, sono, passos, minutos ativos, peso e cintura
// - Salva um perfil corporal simples com altura, meta e peso-alvo
// - Calcula streak, IMC, resumo semanal e referência corporal básica
// - Gera um guia visual de alimentação e foco para o módulo do Meu Dia
// - Preserva os dados de comida e treino usados no resto do app
//
// Observação importante:
// - As tabelas de alimentação e energia são guias gerais de bem-estar.
// - Para menores de 18 anos, o app mostra faixas amplas e evita metas rígidas.
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

enum BodyCareBiologicalSex { male, female, unknown }

class BodyCareReferenceResult {
  const BodyCareReferenceResult({required this.label, required this.hint});

  final String label;
  final String hint;
}

class BodyCareNutritionGuide {
  const BodyCareNutritionGuide({
    required this.title,
    required this.energyLabel,
    required this.energyHint,
    required this.hydrationLabel,
    required this.hydrationHint,
    required this.activityLabel,
    required this.activityHint,
    required this.plateTitle,
    required this.plateHint,
    required this.mainTips,
    required this.foodCareTips,
    required this.trainingCareTips,
    required this.meals,
    required this.foodTable,
  });

  final String title;
  final String energyLabel;
  final String energyHint;
  final String hydrationLabel;
  final String hydrationHint;
  final String activityLabel;
  final String activityHint;
  final String plateTitle;
  final String plateHint;
  final List<String> mainTips;
  final List<String> foodCareTips;
  final List<String> trainingCareTips;
  final List<BodyCareMealSuggestion> meals;
  final List<BodyCareFoodTableItem> foodTable;

  factory BodyCareNutritionGuide.fallback() {
    return BodyCareNutritionGuide(
      title: 'Base simples para seguir firme',
      energyLabel: 'Faixa geral',
      energyHint:
          'Use isso como noção de combustível, não como cobrança rígida.',
      hydrationLabel: '6–8 copos por dia',
      hydrationHint:
          'Em dias de treino, calor ou muito suor, normalmente você precisa de mais.',
      activityLabel: 'Movimento diário',
      activityHint:
          'Manter o corpo ativo quase todo dia ajuda mais do que treinos aleatórios.',
      plateTitle: 'Monte o prato com equilíbrio',
      plateHint:
          'Metade do prato com frutas e vegetais, um quarto com proteína e um quarto com carboidrato já resolve muito do básico.',
      mainTips: const [
        'Comida boa, treino possível e sono decente já fazem diferença real.',
        'Não tente compensar um dia ruim com radicalismo no dia seguinte.',
        'Consistência vence perfeição.',
      ],
      foodCareTips: const [
        'Evite passar o dia inteiro só beliscando.',
        'Ter uma base de refeições prontas reduz improviso.',
        'Proteína, fibra e água ajudam a sustentar melhor a fome ao longo do dia.',
      ],
      trainingCareTips: const [
        'Progresso vem de repetir o básico por semanas, não de um único treino forte.',
        'Sono e recuperação influenciam diretamente seu desempenho.',
        'Treino ruim, mas feito, ainda conta para o ritmo.',
      ],
      meals: const [
        BodyCareMealSuggestion(
          title: 'Café da manhã base',
          subtitle: 'Combina energia + proteína',
          items: [
            BodyCareMealItem(name: '2 ovos', portion: '2 un', calories: 156),
            BodyCareMealItem(
              name: 'Pão integral',
              portion: '2 fatias',
              calories: 140,
            ),
            BodyCareMealItem(name: 'Banana', portion: '1 un', calories: 90),
          ],
        ),
      ],
      foodTable: const [
        BodyCareFoodTableItem(
          group: 'Base',
          item: 'Banana',
          portion: '1 un',
          calories: 90,
          note: 'Boa para lanche rápido.',
        ),
      ],
    );
  }
}

class BodyCareMealSuggestion {
  const BodyCareMealSuggestion({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<BodyCareMealItem> items;

  int get totalCalories =>
      items.fold<int>(0, (sum, item) => sum + item.calories);
}

class BodyCareMealItem {
  const BodyCareMealItem({
    required this.name,
    required this.portion,
    required this.calories,
  });

  final String name;
  final String portion;
  final int calories;
}

class BodyCareFoodTableItem {
  const BodyCareFoodTableItem({
    required this.group,
    required this.item,
    required this.portion,
    required this.calories,
    required this.note,
  });

  final String group;
  final String item;
  final String portion;
  final int calories;
  final String note;
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
      description: 'Na maior parte do dia, você alimentou bem o corpo.',
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
    if (decoded is Map) {
      return BodyCareProfile.fromJson(Map<String, dynamic>.from(decoded));
    }
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
    if (value is Map) {
      return BodyCareEntry.fromJson(Map<String, dynamic>.from(value));
    }
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

  Future<BodyCareBiologicalSex> _loadBiologicalSex() async {
    final prefs = await _prefs();
    final uid = _uid();

    final raw = (prefs.getString('$uid:gender') ?? '').trim().toLowerCase();

    if (raw.contains('mulher') || raw.contains('femin')) {
      return BodyCareBiologicalSex.female;
    }
    if (raw.contains('homem') || raw.contains('masc')) {
      return BodyCareBiologicalSex.male;
    }
    return BodyCareBiologicalSex.unknown;
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

  BodyCareReferenceResult _referenceWeightInfo({
    required double? heightCm,
    required int? ageYears,
    required BodyCareBiologicalSex sex,
    required double? currentWeightKg,
  }) {
    if (heightCm == null || heightCm <= 0) {
      return const BodyCareReferenceResult(
        label: '--',
        hint: 'Preencha sua altura para liberar a faixa de referência.',
      );
    }

    if (ageYears != null && ageYears < 18) {
      return const BodyCareReferenceResult(
        label: 'Em desenvolvimento',
        hint:
            'Como você ainda está em fase de crescimento, use esta área mais para acompanhar hábitos, energia e evolução do dia a dia.',
      );
    }

    final meters = heightCm / 100.0;
    final minKg = 18.5 * meters * meters;
    final maxKg = 24.9 * meters * meters;

    final minLabel = minKg.toStringAsFixed(1);
    final maxLabel = maxKg.toStringAsFixed(1);

    String hint =
        'Faixa de referência para sua altura. Use isso como noção geral de saúde, não como cobrança estética.';

    if (currentWeightKg != null) {
      if (currentWeightKg < minKg) {
        hint =
            'Seu peso atual está abaixo dessa faixa de referência. Vale observar energia, alimentação e acompanhamento de saúde.';
      } else if (currentWeightKg > maxKg) {
        hint =
            'Seu peso atual está acima dessa faixa de referência. O foco principal deve ser constância em comida, treino, sono e rotina.';
      } else {
        hint =
            'Seu peso atual está dentro da faixa de referência para sua altura. O foco agora pode ser qualidade de rotina e composição corporal.';
      }
    }

    if (sex == BodyCareBiologicalSex.female) {
      hint +=
          ' O corpo feminino também oscila com ciclo, retenção e fase do mês.';
    } else if (sex == BodyCareBiologicalSex.male) {
      hint +=
          ' No corpo masculino, sono, rotina e constância influenciam bastante a evolução.';
    }

    return BodyCareReferenceResult(label: '$minLabel–$maxLabel kg', hint: hint);
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
    final sex = await _loadBiologicalSex();

    if (items.isEmpty) {
      final ref = _referenceWeightInfo(
        heightCm: profile.heightCm,
        ageYears: ageYears,
        sex: sex,
        currentWeightKg: null,
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

    final ref = _referenceWeightInfo(
      heightCm: profile.heightCm,
      ageYears: ageYears,
      sex: sex,
      currentWeightKg: latestWeight,
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

  String _energyLabel({
    required int? ageYears,
    required BodyCareBiologicalSex sex,
    required double? weeklyTrainingAverage,
  }) {
    final isActive = (weeklyTrainingAverage ?? 0) >= 3.0;

    if (ageYears != null && ageYears < 18) {
      if (sex == BodyCareBiologicalSex.male) {
        return isActive
            ? 'Referência geral: 2.500 kcal/dia ou um pouco mais em dias bem ativos'
            : 'Referência geral: perto de 2.500 kcal/dia';
      }
      if (sex == BodyCareBiologicalSex.female) {
        return isActive
            ? 'Referência geral: 2.000 kcal/dia ou um pouco mais em dias bem ativos'
            : 'Referência geral: perto de 2.000 kcal/dia';
      }
      return 'Referência geral: 2.000–2.500 kcal/dia';
    }

    if (sex == BodyCareBiologicalSex.male) {
      return isActive
          ? 'Base adulta: perto de 2.500 kcal/dia, variando com rotina e treino'
          : 'Base adulta: perto de 2.500 kcal/dia';
    }
    if (sex == BodyCareBiologicalSex.female) {
      return isActive
          ? 'Base adulta: perto de 2.000 kcal/dia, variando com rotina e treino'
          : 'Base adulta: perto de 2.000 kcal/dia';
    }
    return 'Base geral: algo entre 2.000 e 2.500 kcal/dia';
  }

  String _energyHint({
    required int? ageYears,
    required double? heightCm,
    required double? weightKg,
  }) {
    final hasBodyData =
        heightCm != null && heightCm > 0 && weightKg != null && weightKg > 0;
    if (ageYears != null && ageYears < 18) {
      return hasBodyData
          ? 'Como você ainda está crescendo, use esta faixa só como noção de combustível. Foque em regularidade, qualidade e sinais do corpo.'
          : 'Para adolescentes, a necessidade de energia muda muito com crescimento, treino e rotina. Use a faixa só como guia amplo.';
    }
    return hasBodyData
        ? 'Seu peso e sua altura já ajudam a dar contexto, mas treino, sono, rotina e trabalho também mudam sua necessidade diária.'
        : 'Sem peso e altura completos, o app usa uma faixa ampla para ajudar no dia a dia.';
  }

  String _hydrationLabel({
    required int? ageYears,
    required BodyCareBiologicalSex sex,
    required double? weeklyTrainingAverage,
  }) {
    final isActive = (weeklyTrainingAverage ?? 0) >= 3.0;
    if (ageYears != null && ageYears >= 14 && ageYears < 18) {
      if (sex == BodyCareBiologicalSex.male) {
        return isActive
            ? 'Meta base: 8–11 copos/dia'
            : 'Meta base: 8–10 copos/dia';
      }
      if (sex == BodyCareBiologicalSex.female) {
        return isActive ? 'Meta base: 8–9 copos/dia' : 'Meta base: 8 copos/dia';
      }
    }
    return isActive ? 'Meta base: 6–8+ copos/dia' : 'Meta base: 6–8 copos/dia';
  }

  String _hydrationHint({required double? weeklyTrainingAverage}) {
    final isActive = (weeklyTrainingAverage ?? 0) >= 3.0;
    return isActive
        ? 'Treino, calor e suor costumam pedir mais água. Um bom sinal prático é manter a urina clara ao longo do dia.'
        : 'Beba ao longo do dia, não só quando bater muita sede.';
  }

  String _activityLabel({required int? ageYears}) {
    if (ageYears != null && ageYears < 18) {
      return 'Movimento alvo: 60 min por dia';
    }
    return 'Movimento alvo: 150 min por semana + força 2x';
  }

  String _activityHint({required int? ageYears}) {
    if (ageYears != null && ageYears < 18) {
      return 'Para adolescentes, misturar movimento diário com atividades que fortaleçam músculo e osso durante a semana ajuda bastante.';
    }
    return 'Para adultos, caminhada forte, bike, corrida, dança e treino de força entram nessa conta.';
  }

  String _plateHint({required String goal}) {
    final lower = goal.toLowerCase();
    if (lower.contains('massa')) {
      return 'Metade do prato com vegetais e frutas ao longo do dia, um quarto com carboidrato e um quarto com proteína. Em fase de ganhar massa, vale reforçar carboidrato e proteína nas refeições principais.';
    }
    if (lower.contains('emag')) {
      return 'Metade do prato com vegetais e frutas, um quarto com proteína e um quarto com carboidrato ajuda a comer bem sem radicalizar.';
    }
    return 'Metade do prato com vegetais e frutas, um quarto com proteína e um quarto com carboidrato já resolve muito do básico.';
  }

  List<String> _mainNutritionTips({
    required BodyCareOverview overview,
    required BodyCareProfile profile,
  }) {
    final tips = <String>[
      'Coma em ritmo que você consegue repetir, não em modo extremo.',
      'Procure ter proteína, água e algum vegetal aparecendo com frequência na rotina.',
      'Quando o dia apertar, simplifique em vez de largar: um prato básico ainda conta.',
    ];

    final goal = (profile.goal ?? '').toLowerCase();
    if (goal.contains('massa')) {
      tips.add(
        'Se a meta é ganhar massa, não deixe treino e alimentação se desencontrarem no mesmo dia.',
      );
    } else if (goal.contains('emag')) {
      tips.add(
        'Se a meta é emagrecer, fuja da lógica de passar fome e depois compensar com exagero.',
      );
    }

    if ((overview.weeklyAverageTraining ?? 0) < 2.5) {
      tips.add(
        'Seu movimento ainda está oscilando. Regularidade pequena já vai ajudar no resto do módulo.',
      );
    }

    return tips.take(4).toList();
  }

  List<String> _foodCareTips({required int? ageYears}) {
    return [
      'Tente não trocar refeições por beliscos o dia inteiro.',
      'Monte pelo menos 2 refeições do dia com base simples: proteína + carboidrato + vegetal/fruta.',
      'Doces e ultraprocessados podem existir, mas não precisam virar o centro da rotina.',
      if (ageYears != null && ageYears < 18)
        'Como você ainda está em fase de crescimento, o foco deve ser nutrir e organizar, não entrar em dieta radical.',
    ];
  }

  List<String> _trainingCareTips({required int? ageYears}) {
    return [
      if (ageYears != null && ageYears < 18)
        'Seu corpo responde bem a movimento diário, esporte, treino e recuperação bem feitos.'
      else
        'Para adulto, força 2 vezes por semana já muda bastante a base do corpo e da disposição.',
      'Treino bom é o treino que cabe na sua semana real.',
      'Sono ruim atrapalha treino, fome, foco e recuperação ao mesmo tempo.',
      'Dias leves também contam para manter o corpo em movimento.',
    ];
  }

  List<BodyCareMealSuggestion> _mealSuggestions({required String goal}) {
    final lower = goal.toLowerCase();
    final defaultMeals = <BodyCareMealSuggestion>[
      const BodyCareMealSuggestion(
        title: 'Café da manhã base',
        subtitle: 'Energia + proteína para começar melhor',
        items: [
          BodyCareMealItem(name: '2 ovos', portion: '2 un', calories: 156),
          BodyCareMealItem(
            name: 'Pão integral',
            portion: '2 fatias',
            calories: 140,
          ),
          BodyCareMealItem(name: 'Banana', portion: '1 un', calories: 90),
        ],
      ),
      const BodyCareMealSuggestion(
        title: 'Almoço simples',
        subtitle: 'Prato base fácil de repetir',
        items: [
          BodyCareMealItem(
            name: 'Arroz cozido',
            portion: '120 g',
            calories: 156,
          ),
          BodyCareMealItem(
            name: 'Feijão cozido',
            portion: '100 g',
            calories: 76,
          ),
          BodyCareMealItem(
            name: 'Frango grelhado',
            portion: '120 g',
            calories: 198,
          ),
          BodyCareMealItem(
            name: 'Salada variada',
            portion: '1 prato',
            calories: 45,
          ),
        ],
      ),
      const BodyCareMealSuggestion(
        title: 'Lanche da tarde',
        subtitle: 'Ajuda a segurar o ritmo',
        items: [
          BodyCareMealItem(
            name: 'Iogurte natural',
            portion: '170 g',
            calories: 110,
          ),
          BodyCareMealItem(name: 'Aveia', portion: '30 g', calories: 114),
          BodyCareMealItem(name: 'Maçã', portion: '1 un', calories: 70),
        ],
      ),
      const BodyCareMealSuggestion(
        title: 'Jantar enxuto',
        subtitle: 'Leve, mas com sustento',
        items: [
          BodyCareMealItem(
            name: 'Batata-doce',
            portion: '150 g',
            calories: 129,
          ),
          BodyCareMealItem(
            name: 'Carne magra',
            portion: '120 g',
            calories: 210,
          ),
          BodyCareMealItem(name: 'Legumes', portion: '1 prato', calories: 60),
        ],
      ),
    ];

    if (lower.contains('massa')) {
      return [
        const BodyCareMealSuggestion(
          title: 'Café da manhã reforçado',
          subtitle: 'Mais sustento para fase de ganho',
          items: [
            BodyCareMealItem(name: '3 ovos', portion: '3 un', calories: 234),
            BodyCareMealItem(
              name: 'Pão integral',
              portion: '3 fatias',
              calories: 210,
            ),
            BodyCareMealItem(name: 'Leite', portion: '250 ml', calories: 150),
            BodyCareMealItem(name: 'Banana', portion: '1 un', calories: 90),
          ],
        ),
        ...defaultMeals.skip(1),
      ];
    }

    if (lower.contains('emag')) {
      return [
        const BodyCareMealSuggestion(
          title: 'Café da manhã enxuto',
          subtitle: 'Proteína + fruta + carboidrato simples',
          items: [
            BodyCareMealItem(name: '2 ovos', portion: '2 un', calories: 156),
            BodyCareMealItem(
              name: 'Pão integral',
              portion: '1 fatia',
              calories: 70,
            ),
            BodyCareMealItem(name: 'Mamão', portion: '1 fatia', calories: 55),
          ],
        ),
        ...defaultMeals.skip(1),
      ];
    }

    return defaultMeals;
  }

  List<BodyCareFoodTableItem> _foodTable() {
    return const [
      BodyCareFoodTableItem(
        group: 'Proteína',
        item: 'Ovo',
        portion: '1 un',
        calories: 78,
        note: 'Bom para café, lanche ou refeição.',
      ),
      BodyCareFoodTableItem(
        group: 'Proteína',
        item: 'Frango grelhado',
        portion: '100 g',
        calories: 165,
        note: 'Base prática para almoço ou jantar.',
      ),
      BodyCareFoodTableItem(
        group: 'Carboidrato',
        item: 'Arroz cozido',
        portion: '100 g',
        calories: 130,
        note: 'Energia simples e fácil de combinar.',
      ),
      BodyCareFoodTableItem(
        group: 'Carboidrato',
        item: 'Batata-doce',
        portion: '100 g',
        calories: 86,
        note: 'Boa opção para variar do arroz.',
      ),
      BodyCareFoodTableItem(
        group: 'Base',
        item: 'Feijão cozido',
        portion: '100 g',
        calories: 76,
        note: 'Ajuda com fibra e saciedade.',
      ),
      BodyCareFoodTableItem(
        group: 'Fruta',
        item: 'Banana',
        portion: '1 un',
        calories: 90,
        note: 'Lanche rápido e fácil.',
      ),
      BodyCareFoodTableItem(
        group: 'Fruta',
        item: 'Maçã',
        portion: '1 un',
        calories: 70,
        note: 'Boa para levar no dia.',
      ),
      BodyCareFoodTableItem(
        group: 'Laticínio',
        item: 'Iogurte natural',
        portion: '170 g',
        calories: 110,
        note: 'Vai bem com aveia e fruta.',
      ),
      BodyCareFoodTableItem(
        group: 'Grãos',
        item: 'Aveia',
        portion: '30 g',
        calories: 114,
        note: 'Ajuda a dar mais sustento ao lanche.',
      ),
      BodyCareFoodTableItem(
        group: 'Gordura boa',
        item: 'Azeite',
        portion: '1 colher sopa',
        calories: 90,
        note: 'Use com medida, não no olho.',
      ),
    ];
  }

  Future<BodyCareNutritionGuide> loadNutritionGuide() async {
    final overview = await loadOverview();
    final profile = await loadProfile();
    final birthDate = await _loadBirthDate();
    final ageYears = _ageFromBirthDate(birthDate, DateTime.now());
    final sex = await _loadBiologicalSex();

    final energyLabel = _energyLabel(
      ageYears: ageYears,
      sex: sex,
      weeklyTrainingAverage: overview.weeklyAverageTraining,
    );

    return BodyCareNutritionGuide(
      title: 'Combustível e constância',
      energyLabel: energyLabel,
      energyHint: _energyHint(
        ageYears: ageYears,
        heightCm: profile.heightCm,
        weightKg: overview.latestWeightKg,
      ),
      hydrationLabel: _hydrationLabel(
        ageYears: ageYears,
        sex: sex,
        weeklyTrainingAverage: overview.weeklyAverageTraining,
      ),
      hydrationHint: _hydrationHint(
        weeklyTrainingAverage: overview.weeklyAverageTraining,
      ),
      activityLabel: _activityLabel(ageYears: ageYears),
      activityHint: _activityHint(ageYears: ageYears),
      plateTitle: 'Prato base do seu foco',
      plateHint: _plateHint(goal: profile.goal ?? ''),
      mainTips: _mainNutritionTips(overview: overview, profile: profile),
      foodCareTips: _foodCareTips(ageYears: ageYears),
      trainingCareTips: _trainingCareTips(ageYears: ageYears),
      meals: _mealSuggestions(goal: profile.goal ?? ''),
      foodTable: _foodTable(),
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
