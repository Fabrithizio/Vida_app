import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/areas/presentation/areas_catalog.dart';

class AreasAggregationEngine {
  AreasAggregationEngine({required AreasDailyQuestionsEngine dailyQuestions})
    : _dailyQuestions = dailyQuestions;

  final AreasDailyQuestionsEngine _dailyQuestions;

  Future<String?> trendLabel(String areaId, String itemId) {
    return _dailyQuestions.trendLabelForItem(areaId, itemId);
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
