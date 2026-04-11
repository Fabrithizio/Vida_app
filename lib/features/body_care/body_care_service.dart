// ============================================================================
// FILE: lib/features/body_care/body_care_service.dart
//
// O que faz:
// - Salva registros diários do módulo corporal
// - Mantém alimentação, treino, água, sono e peso por dia
// - Gera visão rápida da semana e consistência
// ============================================================================

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

class BodyCareDayRecord {
  const BodyCareDayRecord({
    required this.day,
    this.food,
    this.training,
    this.water,
    this.sleep,
    this.weightKg,
    this.note,
  });

  final DateTime day;
  final int? food;
  final int? training;
  final int? water;
  final int? sleep;
  final double? weightKg;
  final String? note;

  double? get average {
    final values = [food, training, water, sleep].whereType<int>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String get statusLabel {
    final avg = average;
    if (avg == null) return 'Sem registro';
    if (avg >= 3.6) return 'Mandou bem';
    if (avg >= 2.6) return 'Na linha';
    if (avg >= 1.6) return 'Mais ou menos';
    if (avg >= 0.6) return 'Escapou';
    return 'Chutou o balde';
  }

  bool get dedicatedDay => (food ?? 0) >= 3 && (training ?? 0) >= 3;
}

class BodyCareWeekPoint {
  const BodyCareWeekPoint({required this.day, required this.score});

  final DateTime day;
  final double? score;
}

class BodyCareService {
  static const List<BodyCareAnswerOption> foodOptions = [
    BodyCareAnswerOption(
      value: 0,
      label: 'Chutei o balde',
      shortLabel: 'Balde',
      description:
          'Dia bem fora da linha, com muita besteira e pouco controle.',
    ),
    BodyCareAnswerOption(
      value: 1,
      label: 'Ruim',
      shortLabel: 'Ruim',
      description: 'Teve exagero e pouca comida que ajuda seu corpo.',
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

  String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  String _key(String suffix, DateTime day) =>
      '${_uid()}:body_care:${_dayKey(day)}:$suffix';

  Future<int?> _readInt(String suffix, DateTime day) async {
    final prefs = await _prefs();
    return prefs.getInt(_key(suffix, day));
  }

  Future<double?> _readDouble(String suffix, DateTime day) async {
    final prefs = await _prefs();
    return prefs.getDouble(_key(suffix, day));
  }

  Future<String?> _readString(String suffix, DateTime day) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_key(suffix, day));
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  Future<void> _writeInt(String suffix, DateTime day, int value) async {
    final prefs = await _prefs();
    await prefs.setInt(_key(suffix, day), value.clamp(0, 4));
  }

  Future<void> saveFood(DateTime day, int value) =>
      _writeInt('food', day, value);
  Future<void> saveTraining(DateTime day, int value) =>
      _writeInt('training', day, value);
  Future<void> saveWater(DateTime day, int value) =>
      _writeInt('water', day, value);
  Future<void> saveSleep(DateTime day, int value) =>
      _writeInt('sleep', day, value);

  Future<void> saveWeight(DateTime day, double? weightKg) async {
    final prefs = await _prefs();
    final key = _key('weightKg', day);
    if (weightKg == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setDouble(key, weightKg);
  }

  Future<void> saveNote(DateTime day, String? note) async {
    final prefs = await _prefs();
    final key = _key('note', day);
    if (note == null || note.trim().isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, note.trim());
  }

  Future<BodyCareDayRecord> loadDay(DateTime day) async {
    return BodyCareDayRecord(
      day: DateTime(day.year, day.month, day.day),
      food: await _readInt('food', day),
      training: await _readInt('training', day),
      water: await _readInt('water', day),
      sleep: await _readInt('sleep', day),
      weightKg: await _readDouble('weightKg', day),
      note: await _readString('note', day),
    );
  }

  Future<List<BodyCareWeekPoint>> last7Days(DateTime anchorDay) async {
    final base = DateTime(anchorDay.year, anchorDay.month, anchorDay.day);
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
    final base = DateTime(anchorDay.year, anchorDay.month, anchorDay.day);
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
}
