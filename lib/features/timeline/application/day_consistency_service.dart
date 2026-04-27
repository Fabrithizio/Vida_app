// ============================================================================
// FILE: lib/features/timeline/application/day_consistency_service.dart
//
// O que faz:
// - Calcula constância diária usando sinais reais do app
// - Junta Timeline, Corpo & Saúde e check-in diário
// - Calcula score do dia, streak, melhor streak, proteções e calendário
// - Agora também persiste um snapshot para o Areas ler sem depender da UI
//
// Regras desta versão:
// - corpo em dia forte = +2
// - treino do dia = +2
// - blocos concluídos importantes = até +2
// - check-in diário concluído = +1
// - streak conta quando o dia fica "bom" ou "forte"
// - a cada 15 dias seguidos sem falhar, ganha 1 proteção
// - máximo de 2 proteções
// ============================================================================

import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

enum DayConsistencyLevel { empty, light, good, strong }

class DayConsistencyEntry {
  const DayConsistencyEntry({
    required this.day,
    required this.score,
    required this.level,
    required this.countsForStreak,
    required this.bodyPoints,
    required this.trainingPoints,
    required this.timelinePoints,
    required this.checkinPoints,
  });

  final DateTime day;
  final int score;
  final DayConsistencyLevel level;
  final bool countsForStreak;
  final int bodyPoints;
  final int trainingPoints;
  final int timelinePoints;
  final int checkinPoints;
}

class DayConsistencySummary {
  const DayConsistencySummary({
    required this.currentStreak,
    required this.bestStreak,
    required this.availableProtections,
    required this.strongDays14,
    required this.goodDays14,
    required this.activeDays14,
    required this.goodRate14,
    required this.goodRate30,
    required this.entries,
  });

  final int currentStreak;
  final int bestStreak;
  final int availableProtections;
  final int strongDays14;
  final int goodDays14;
  final int activeDays14;
  final double goodRate14;
  final double goodRate30;
  final List<DayConsistencyEntry> entries;
}

class DayConsistencySnapshot {
  const DayConsistencySnapshot({
    required this.currentStreak,
    required this.bestStreak,
    required this.availableProtections,
    required this.strongDays14,
    required this.goodDays14,
    required this.activeDays14,
    required this.goodRate14,
    required this.goodRate30,
    required this.updatedAt,
  });

  final int currentStreak;
  final int bestStreak;
  final int availableProtections;
  final int strongDays14;
  final int goodDays14;
  final int activeDays14;
  final double goodRate14;
  final double goodRate30;
  final DateTime updatedAt;
}

class DayConsistencyService {
  DayConsistencyService({
    required TimelineStore timelineStore,
    BodyCareService? bodyCare,
    DailyCheckinService? dailyCheckinService,
  }) : _timelineStore = timelineStore,
       _bodyCare = bodyCare ?? BodyCareService(),
       _dailyCheckin = dailyCheckinService ?? DailyCheckinService();

  final TimelineStore _timelineStore;
  final BodyCareService _bodyCare;
  final DailyCheckinService _dailyCheckin;

  static const String _currentStreakKey = 'day_consistency:current_streak';
  static const String _bestStreakKey = 'day_consistency:best_streak';
  static const String _protectionsKey = 'day_consistency:protections';
  static const String _strong14Key = 'day_consistency:strong_14';
  static const String _good14Key = 'day_consistency:good_14';
  static const String _active14Key = 'day_consistency:active_14';
  static const String _goodRate14Key = 'day_consistency:good_rate_14';
  static const String _goodRate30Key = 'day_consistency:good_rate_30';
  static const String _updatedAtKey = 'day_consistency:updated_at';

  String _uidOrAnon() {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim() ?? 'anon';
    return uid.isEmpty ? 'anon' : uid;
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<DayConsistencyEntry> entryForDay(DateTime day) async {
    final target = _dayOnly(day);
    final body = await _bodyCare.loadDay(target);
    final blocks = _timelineStore.itemsForDay(target);
    final isCheckinDone = await _dailyCheckin.isCompleted(target);

    final bodyPoints = _bodyPoints(body);
    final trainingPoints = _trainingPoints(body);
    final timelinePoints = _timelinePoints(blocks);
    final checkinPoints = isCheckinDone ? 1 : 0;

    final score = bodyPoints + trainingPoints + timelinePoints + checkinPoints;
    final level = _levelFromScore(score);

    return DayConsistencyEntry(
      day: target,
      score: score,
      level: level,
      countsForStreak:
          level == DayConsistencyLevel.good ||
          level == DayConsistencyLevel.strong,
      bodyPoints: bodyPoints,
      trainingPoints: trainingPoints,
      timelinePoints: timelinePoints,
      checkinPoints: checkinPoints,
    );
  }

  Future<List<DayConsistencyEntry>> range({
    required DateTime endDayInclusive,
    int days = 60,
  }) async {
    final end = _dayOnly(endDayInclusive);
    final out = <DayConsistencyEntry>[];

    for (var i = days - 1; i >= 0; i--) {
      final day = end.subtract(Duration(days: i));
      out.add(await entryForDay(day));
    }

    return out;
  }

  Future<DayConsistencySummary> summary({
    DateTime? anchorDay,
    int lookbackDays = 90,
  }) async {
    final now = _dayOnly(anchorDay ?? DateTime.now());
    final entries = await range(endDayInclusive: now, days: lookbackDays);

    int bestStreak = 0;
    int running = 0;
    int protections = 0;
    int perfectRunSinceLastProtection = 0;

    for (final entry in entries) {
      final qualifies = entry.countsForStreak;
      if (qualifies) {
        running += 1;
        perfectRunSinceLastProtection += 1;
        if (perfectRunSinceLastProtection >= 15) {
          protections = math.min(2, protections + 1);
          perfectRunSinceLastProtection = 0;
        }
      } else {
        if (protections > 0) {
          protections -= 1;
        } else {
          running = 0;
          perfectRunSinceLastProtection = 0;
        }
      }
      if (running > bestStreak) bestStreak = running;
    }

    int currentStreak = 0;
    int currentProtections = 0;
    int currentPerfectRun = 0;

    for (final entry in entries.reversed) {
      final qualifies = entry.countsForStreak;
      if (qualifies) {
        currentStreak += 1;
        currentPerfectRun += 1;
        if (currentPerfectRun >= 15) {
          currentProtections = math.min(2, currentProtections + 1);
          currentPerfectRun = 0;
        }
      } else {
        if (currentProtections > 0) {
          currentProtections -= 1;
        } else {
          break;
        }
      }
    }

    final last14 = entries.length <= 14
        ? entries
        : entries.sublist(entries.length - 14);
    final last30 = entries.length <= 30
        ? entries
        : entries.sublist(entries.length - 30);

    final strongDays14 = last14
        .where((e) => e.level == DayConsistencyLevel.strong)
        .length;
    final goodDays14 = last14.where((e) => e.countsForStreak).length;
    final activeDays14 = last14
        .where((e) => e.level != DayConsistencyLevel.empty)
        .length;

    double rate(List<DayConsistencyEntry> list) {
      if (list.isEmpty) return 0;
      final good = list.where((e) => e.countsForStreak).length;
      return good / list.length;
    }

    return DayConsistencySummary(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      availableProtections: currentProtections,
      strongDays14: strongDays14,
      goodDays14: goodDays14,
      activeDays14: activeDays14,
      goodRate14: rate(last14),
      goodRate30: rate(last30),
      entries: entries,
    );
  }

  Future<DayConsistencySummary> summaryAndPersist({
    DateTime? anchorDay,
    int lookbackDays = 90,
  }) async {
    final result = await summary(
      anchorDay: anchorDay,
      lookbackDays: lookbackDays,
    );
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidOrAnon();

    await prefs.setInt('$uid:$_currentStreakKey', result.currentStreak);
    await prefs.setInt('$uid:$_bestStreakKey', result.bestStreak);
    await prefs.setInt('$uid:$_protectionsKey', result.availableProtections);
    await prefs.setInt('$uid:$_strong14Key', result.strongDays14);
    await prefs.setInt('$uid:$_good14Key', result.goodDays14);
    await prefs.setInt('$uid:$_active14Key', result.activeDays14);
    await prefs.setDouble('$uid:$_goodRate14Key', result.goodRate14);
    await prefs.setDouble('$uid:$_goodRate30Key', result.goodRate30);
    await prefs.setString(
      '$uid:$_updatedAtKey',
      DateTime.now().toIso8601String(),
    );

    return result;
  }

  Future<DayConsistencySnapshot?> readSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidOrAnon();

    final updatedAtRaw = (prefs.getString('$uid:$_updatedAtKey') ?? '').trim();
    if (updatedAtRaw.isEmpty) return null;

    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (updatedAt == null) return null;

    return DayConsistencySnapshot(
      currentStreak: prefs.getInt('$uid:$_currentStreakKey') ?? 0,
      bestStreak: prefs.getInt('$uid:$_bestStreakKey') ?? 0,
      availableProtections: prefs.getInt('$uid:$_protectionsKey') ?? 0,
      strongDays14: prefs.getInt('$uid:$_strong14Key') ?? 0,
      goodDays14: prefs.getInt('$uid:$_good14Key') ?? 0,
      activeDays14: prefs.getInt('$uid:$_active14Key') ?? 0,
      goodRate14: prefs.getDouble('$uid:$_goodRate14Key') ?? 0,
      goodRate30: prefs.getDouble('$uid:$_goodRate30Key') ?? 0,
      updatedAt: updatedAt,
    );
  }

  int _bodyPoints(BodyCareEntry body) {
    final score = _bodyCare.focusScore(body);
    if (score >= 3) return 2;
    if (score >= 2) return 1;
    return 0;
  }

  int _trainingPoints(BodyCareEntry body) {
    final training = body.training ?? 0;
    final activeMinutes = body.activeMinutes ?? 0;

    if (training >= 3 || activeMinutes >= 40) return 2;
    if (training >= 2 || activeMinutes >= 20) return 1;
    return 0;
  }

  int _timelinePoints(List<TimelineBlock> blocks) {
    if (blocks.isEmpty) return 0;

    final doneImportant = blocks.where((block) {
      if (!block.isDone) return false;
      switch (block.type) {
        case TimelineBlockType.event:
        case TimelineBlockType.goal:
        case TimelineBlockType.study:
        case TimelineBlockType.workout:
        case TimelineBlockType.health:
          return true;
        case TimelineBlockType.note:
        case TimelineBlockType.social:
        case TimelineBlockType.rest:
          return false;
      }
    }).length;

    final doneSupport = blocks.where((block) {
      if (!block.isDone) return false;
      switch (block.type) {
        case TimelineBlockType.social:
        case TimelineBlockType.rest:
          return true;
        case TimelineBlockType.event:
        case TimelineBlockType.goal:
        case TimelineBlockType.note:
        case TimelineBlockType.study:
        case TimelineBlockType.workout:
        case TimelineBlockType.health:
          return false;
      }
    }).length;

    if (doneImportant >= 2) return 2;
    if (doneImportant >= 1 || doneSupport >= 2) return 1;
    return 0;
  }

  DayConsistencyLevel _levelFromScore(int score) {
    if (score <= 0) return DayConsistencyLevel.empty;
    if (score <= 2) return DayConsistencyLevel.light;
    if (score <= 4) return DayConsistencyLevel.good;
    return DayConsistencyLevel.strong;
  }
}
