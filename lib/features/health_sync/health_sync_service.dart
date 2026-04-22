// ============================================================================
// FILE: lib/features/health_sync/health_sync_service.dart
//
// Integração Android-first via Health Connect.
//
// Objetivo desta versão:
// - manter a conexão simples
// - puxar só o básico que realmente importa para o app
// - funcionar como fonte real para preencher o módulo fitness / Areas
// - evitar lógica complexa e dependência de marca específica
//
// Dados principais:
// - sono recente
// - passos de hoje
// - minutos ativos de hoje
// - calorias ativas de hoje
//
// Dados secundários:
// - exercício dos últimos 7 dias
// - treinos dos últimos 7 dias
// ============================================================================

import 'dart:io';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartHealthSnapshot {
  const SmartHealthSnapshot({
    required this.isConnected,
    required this.platformLabel,
    this.lastSyncAt,
    this.sleepHours,
    this.exerciseMinutes7d,
    this.workoutCount7d,
    this.stepsToday,
    this.activeMinutesToday,
    this.activeCaloriesToday,
  });

  final bool isConnected;
  final String platformLabel;
  final DateTime? lastSyncAt;
  final double? sleepHours;
  final double? exerciseMinutes7d;
  final int? workoutCount7d;
  final int? stepsToday;
  final int? activeMinutesToday;
  final int? activeCaloriesToday;

  bool get hasPrimaryData =>
      sleepHours != null ||
      stepsToday != null ||
      activeMinutesToday != null ||
      activeCaloriesToday != null;

  bool get hasAnyData =>
      hasPrimaryData || exerciseMinutes7d != null || workoutCount7d != null;
}

class SmartHealthSyncResult {
  const SmartHealthSyncResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

class SmartHealthSyncService {
  final Health _health = Health();

  static String _kConnected(String uid) => '$uid:smart_health_connected';
  static String _kPlatform(String uid) => '$uid:smart_health_platform';
  static String _kLastSyncAt(String uid) => '$uid:smart_health_last_sync_at';
  static String _kSleepHours(String uid) => '$uid:smart_health_sleep_hours';
  static String _kSleepUpdatedAt(String uid) =>
      '$uid:smart_health_sleep_updated_at';
  static String _kExerciseMinutes7d(String uid) =>
      '$uid:smart_health_exercise_minutes_7d';
  static String _kWorkoutCount7d(String uid) => '$uid:smart_health_workouts_7d';
  static String _kStepsToday(String uid) => '$uid:smart_health_steps_today';
  static String _kActiveMinutesToday(String uid) =>
      '$uid:smart_health_active_minutes_today';
  static String _kActiveCaloriesToday(String uid) =>
      '$uid:smart_health_active_calories_today';

  String get _platformLabel => 'Health Connect';

  Future<SmartHealthSnapshot> readSnapshot(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final rawLastSync = (prefs.getString(_kLastSyncAt(uid)) ?? '').trim();
    final platform = (prefs.getString(_kPlatform(uid)) ?? '').trim();

    return SmartHealthSnapshot(
      isConnected: prefs.getBool(_kConnected(uid)) ?? false,
      platformLabel: platform.isEmpty ? _platformLabel : platform,
      lastSyncAt: rawLastSync.isEmpty ? null : DateTime.tryParse(rawLastSync),
      sleepHours: prefs.getDouble(_kSleepHours(uid)),
      exerciseMinutes7d: prefs.getDouble(_kExerciseMinutes7d(uid)),
      workoutCount7d: prefs.getInt(_kWorkoutCount7d(uid)),
      stepsToday: prefs.getInt(_kStepsToday(uid)),
      activeMinutesToday: prefs.getInt(_kActiveMinutesToday(uid)),
      activeCaloriesToday: prefs.getInt(_kActiveCaloriesToday(uid)),
    );
  }

  Future<SmartHealthSyncResult> sync(String uid) async {
    if (!Platform.isAndroid) {
      return const SmartHealthSyncResult(
        ok: false,
        message: 'A integração de saúde está habilitada apenas no Android.',
      );
    }

    try {
      await _health.configure();

      final readTypes = <HealthDataType>[
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.STEPS,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.WORKOUT,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];

      final granted = await _health.requestAuthorization(
        readTypes,
        permissions: List<HealthDataAccess>.filled(
          readTypes.length,
          HealthDataAccess.READ,
        ),
      );

      if (!granted) {
        return const SmartHealthSyncResult(
          ok: false,
          message:
              'A conexão foi cancelada ou as permissões não foram liberadas no Health Connect.',
        );
      }

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final sleepPoints = _health.removeDuplicates(
        await _health.getHealthDataFromTypes(
          types: const [
            HealthDataType.SLEEP_SESSION,
            HealthDataType.SLEEP_ASLEEP,
          ],
          startTime: now.subtract(const Duration(days: 2)),
          endTime: now,
        ),
      );

      final weekPoints = _health.removeDuplicates(
        await _health.getHealthDataFromTypes(
          types: const [HealthDataType.EXERCISE_TIME, HealthDataType.WORKOUT],
          startTime: now.subtract(const Duration(days: 7)),
          endTime: now,
        ),
      );

      final todayPoints = _health.removeDuplicates(
        await _health.getHealthDataFromTypes(
          types: const [
            HealthDataType.STEPS,
            HealthDataType.EXERCISE_TIME,
            HealthDataType.WORKOUT,
            HealthDataType.ACTIVE_ENERGY_BURNED,
          ],
          startTime: startOfToday,
          endTime: now,
        ),
      );

      final sleepHours = _extractLatestSleepHours(sleepPoints, now);
      final exerciseMinutes7d = _extractExerciseMinutes(weekPoints);
      final workoutCount7d = _extractWorkoutCount(weekPoints);
      final stepsToday = _extractStepsToday(todayPoints);
      final activeMinutesToday = _extractActiveMinutesToday(todayPoints);
      final activeCaloriesToday = _extractActiveCaloriesToday(todayPoints);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kConnected(uid), true);
      await prefs.setString(_kPlatform(uid), _platformLabel);
      await prefs.setString(_kLastSyncAt(uid), now.toIso8601String());

      if (sleepHours != null) {
        await prefs.setDouble(_kSleepHours(uid), sleepHours);
        await prefs.setString(_kSleepUpdatedAt(uid), now.toIso8601String());
      }
      if (exerciseMinutes7d != null) {
        await prefs.setDouble(_kExerciseMinutes7d(uid), exerciseMinutes7d);
      }
      await prefs.setInt(_kWorkoutCount7d(uid), workoutCount7d);
      if (stepsToday != null) {
        await prefs.setInt(_kStepsToday(uid), stepsToday);
      }
      if (activeMinutesToday != null) {
        await prefs.setInt(_kActiveMinutesToday(uid), activeMinutesToday);
      }
      if (activeCaloriesToday != null) {
        await prefs.setInt(_kActiveCaloriesToday(uid), activeCaloriesToday);
      }

      final parts = <String>[];
      if (sleepHours != null)
        parts.add('${sleepHours.toStringAsFixed(1)}h sono');
      if (stepsToday != null) parts.add('$stepsToday passos');
      if (activeMinutesToday != null)
        parts.add('$activeMinutesToday min ativos');
      if (activeCaloriesToday != null)
        parts.add('$activeCaloriesToday kcal ativas');
      if (parts.isEmpty) {
        parts.add('conexão pronta, mas ainda sem dados visíveis');
      }

      return SmartHealthSyncResult(
        ok: true,
        message: 'Conexão concluída. ${parts.join(' · ')}.',
      );
    } catch (e) {
      return SmartHealthSyncResult(
        ok: false,
        message:
            'Não foi possível sincronizar agora. No Android, confirme se o Health Connect está instalado, aberto e com permissões liberadas.\n\nDetalhe: $e',
      );
    }
  }

  Future<void> disconnect(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConnected(uid));
    await prefs.remove(_kPlatform(uid));
    await prefs.remove(_kLastSyncAt(uid));
    await prefs.remove(_kSleepHours(uid));
    await prefs.remove(_kSleepUpdatedAt(uid));
    await prefs.remove(_kExerciseMinutes7d(uid));
    await prefs.remove(_kWorkoutCount7d(uid));
    await prefs.remove(_kStepsToday(uid));
    await prefs.remove(_kActiveMinutesToday(uid));
    await prefs.remove(_kActiveCaloriesToday(uid));
  }

  double? _extractLatestSleepHours(List<HealthDataPoint> points, DateTime now) {
    final relevant = points
        .where(
          (p) =>
              p.type == HealthDataType.SLEEP_SESSION ||
              p.type == HealthDataType.SLEEP_ASLEEP,
        )
        .where((p) => now.difference(p.dateTo).inHours <= 36)
        .toList();

    if (relevant.isEmpty) return null;

    relevant.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    final best = relevant.reduce((current, next) {
      final currentDuration = current.dateTo
          .difference(current.dateFrom)
          .inMinutes;
      final nextDuration = next.dateTo.difference(next.dateFrom).inMinutes;
      return nextDuration > currentDuration ? next : current;
    });

    final hours = best.dateTo.difference(best.dateFrom).inMinutes / 60.0;
    if (hours <= 0) return null;
    return hours;
  }

  double? _extractExerciseMinutes(List<HealthDataPoint> points) {
    double total = 0;

    for (final point in points) {
      if (point.type == HealthDataType.EXERCISE_TIME &&
          point.value is NumericHealthValue) {
        total += (point.value as NumericHealthValue).numericValue.toDouble();
      } else if (point.type == HealthDataType.WORKOUT) {
        total += point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
      }
    }

    return total <= 0 ? null : total;
  }

  int _extractWorkoutCount(List<HealthDataPoint> points) {
    return points.where((p) => p.type == HealthDataType.WORKOUT).length;
  }

  int? _extractStepsToday(List<HealthDataPoint> points) {
    double total = 0;
    for (final point in points) {
      if (point.type == HealthDataType.STEPS &&
          point.value is NumericHealthValue) {
        total += (point.value as NumericHealthValue).numericValue.toDouble();
      }
    }
    if (total <= 0) return null;
    return total.round();
  }

  int? _extractActiveMinutesToday(List<HealthDataPoint> points) {
    double total = 0;

    for (final point in points) {
      if (point.type == HealthDataType.EXERCISE_TIME &&
          point.value is NumericHealthValue) {
        total += (point.value as NumericHealthValue).numericValue.toDouble();
      } else if (point.type == HealthDataType.WORKOUT) {
        total += point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
      }
    }

    if (total <= 0) return null;
    return total.round();
  }

  int? _extractActiveCaloriesToday(List<HealthDataPoint> points) {
    double total = 0;

    for (final point in points) {
      if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED &&
          point.value is NumericHealthValue) {
        total += (point.value as NumericHealthValue).numericValue.toDouble();
      }
    }

    if (total <= 0) return null;
    return total.round();
  }
}
