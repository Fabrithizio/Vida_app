import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/areas/presentation/areas_catalog.dart';

class AreasAggregationEngine {
  AreasAggregationEngine({required AreasDailyQuestionsEngine dailyQuestions})
    : _dailyQuestions = dailyQuestions;

  final AreasDailyQuestionsEngine _dailyQuestions;

  static const Map<String, List<String>> _trendQuestions = {
    'body_health.energy': ['energy_ok', 'sleep_ok'],
    'body_health.movement': ['move'],
    'body_health.nutrition': ['nutrition_ok', 'hydration_ok'],
    'mind_emotion.mood': ['mood_ok', 'mental_recovery'],
    'mind_emotion.stress': ['stress_ok', 'mental_recovery'],
    'mind_emotion.focus': ['focus', 'study_quality'],
    'mind_emotion.mental_load': ['stress_ok', 'mental_recovery'],
    'work_vocation.routine': ['routine_ok', 'day_planning'],
    'work_vocation.consistency': ['routine_ok', 'day_planning'],
    'work_vocation.output': ['day_planning', 'focus', 'routine_ok'],
    'work_vocation.balance': ['routine_ok', 'stress_ok', 'mental_recovery'],
    'learning_intellect.study': ['study_ok', 'study_quality'],
    'learning_intellect.courses': ['study_ok', 'study_quality', 'routine_ok'],
    'learning_intellect.reading': ['study_quality', 'focus'],
    'learning_intellect.skills': ['study_quality', 'focus', 'routine_ok'],
    'learning_intellect.review_practice': [
      'study_ok',
      'study_quality',
      'focus',
    ],
    'relations_community.family': ['social_ok', 'social_presence', 'mood_ok'],
    'relations_community.friends': ['social_ok', 'social_presence', 'mood_ok'],
    'relations_community.partner': ['social_ok', 'social_presence', 'mood_ok'],
    'relations_community.social_contact': ['social_ok', 'social_presence'],
    'purpose_values.direction': ['routine_ok', 'day_planning', 'energy_ok'],
    'purpose_values.goals_review': ['routine_ok', 'move', 'study_ok'],
    'purpose_values.gratitude': [
      'mental_recovery',
      'sleep_ok',
      'mood_ok',
      'stress_ok',
    ],
    'digital_tech.distraction': ['focus', 'digital_balance'],
  };

  Future<String?> trendLabel(String areaId, String itemId) {
    final questionIds = _trendQuestions['$areaId.$itemId'];
    if (questionIds == null) return Future.value(null);
    return _dailyQuestions.trendLabelForQuestions(questionIds);
  }

  Future<AreaStatus?> overallStatus(
    String areaId,
    List<String> itemIds, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getComputedAssessment,
  }) async {
    final statuses = <AreaStatus>[];

    for (final itemId in itemIds) {
      final assessment = await getComputedAssessment(areaId, itemId);
      if (assessment == null || assessment.status == AreaStatus.noData) {
        continue;
      }
      statuses.add(assessment.status);
    }

    if (statuses.isEmpty) return null;

    if (statuses.contains(AreaStatus.critical)) return AreaStatus.critical;
    if (statuses.contains(AreaStatus.poor)) return AreaStatus.poor;
    if (statuses.contains(AreaStatus.medium)) return AreaStatus.medium;
    if (statuses.contains(AreaStatus.good)) return AreaStatus.good;
    if (statuses.contains(AreaStatus.excellent)) return AreaStatus.excellent;

    return AreaStatus.noData;
  }

  Future<int?> score(
    String areaId,
    List<String> itemIds, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getComputedAssessment,
  }) async {
    double weightedSum = 0;
    double totalWeight = 0;

    for (final itemId in itemIds) {
      final assessment = await getComputedAssessment(areaId, itemId);
      if (assessment == null || assessment.status == AreaStatus.noData) {
        continue;
      }

      final item = AreasCatalog.itemById(
        areaId,
        itemId,
        includeWomenCycle: true,
      );
      final weight = item?.weight ?? 1.0;
      final itemScore = assessment.score ?? _scoreFromStatus(assessment.status);

      weightedSum += itemScore * weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return null;
    return (weightedSum / totalWeight).round().clamp(0, 100);
  }

  int scoreFromStatus(AreaStatus status) {
    return _scoreFromStatus(status);
  }

  int _scoreFromStatus(AreaStatus status) {
    switch (status) {
      case AreaStatus.excellent:
        return 90;
      case AreaStatus.good:
        return 70;
      case AreaStatus.medium:
        return 50;
      case AreaStatus.poor:
        return 30;
      case AreaStatus.critical:
        return 10;
      case AreaStatus.noData:
        return 0;
    }
  }
}
