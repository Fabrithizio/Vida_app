import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';

class AreasEnvironmentEngine {
  Future<AreaAssessment?> computedEnvironmentItem(
    String areaId,
    String itemId, {
    required Future<AreaAssessment?> Function(String areaId, String itemId)
    getAssessment,
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    if (itemId == 'organization') {
      return _computedHomeTaskCategory(
        areaId: areaId,
        itemId: itemId,
        category: HomeTaskCategory.organization,
        emptyReason:
            'Ainda não há tarefas de organização registradas para medir essa subárea.',
        reasonLabel: 'organização da casa',
        details:
            'Calculado automaticamente pelas tarefas de organização da casa, considerando o quanto já foi concluído e quão recente foi esse cuidado.',
        excellentAction: 'Ótimo. Continue mantendo a organização em dia.',
        goodAction: 'Bom nível de organização. Continue sustentando o ritmo.',
        mediumAction: 'Sua organização está mediana. Vale retomar constância.',
        poorAction: 'A organização da casa está ficando para trás.',
        criticalAction: 'Organização muito baixa. Vale recomeçar pelo básico.',
        completionWeight: 0.45,
        recencyWeight: 0.25,
        freshnessWeight: 0.30,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (itemId == 'cleaning') {
      return _computedHomeTaskCategory(
        areaId: areaId,
        itemId: itemId,
        category: HomeTaskCategory.cleaning,
        emptyReason:
            'Ainda não há tarefas de limpeza registradas para medir essa subárea.',
        reasonLabel: 'limpeza da casa',
        details:
            'Calculado automaticamente pelas tarefas de limpeza da casa, considerando tarefas concluídas, pendências e quão recente foi o cuidado com o ambiente.',
        excellentAction: 'Ótimo. Sua rotina de limpeza está muito bem cuidada.',
        goodAction: 'Bom ritmo de limpeza. Continue assim.',
        mediumAction:
            'Sua limpeza básica está mediana. Vale reforçar a constância.',
        poorAction: 'A rotina de limpeza está fraca no momento.',
        criticalAction:
            'A limpeza da casa está muito atrasada. Recomece pelo essencial.',
        completionWeight: 0.35,
        recencyWeight: 0.35,
        freshnessWeight: 0.30,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (itemId == 'home_tasks') {
      return _computedHomeTaskCategory(
        areaId: areaId,
        itemId: itemId,
        category: HomeTaskCategory.cleaning,
        emptyReason:
            'Ainda não há tarefas domésticas registradas para medir essa subárea.',
        reasonLabel: 'pendências domésticas',
        details:
            'Calculado pelas tarefas domésticas cadastradas, olhando pendências abertas, ritmo recente e itens concluídos.',
        excellentAction:
            'Suas pendências domésticas estão muito bem controladas.',
        goodAction: 'Bom controle das pendências domésticas.',
        mediumAction: 'As pendências domésticas estão medianas no momento.',
        poorAction: 'As pendências domésticas já estão acumulando.',
        criticalAction:
            'As pendências domésticas estão bem acumuladas. Vale agir logo.',
        completionWeight: 0.30,
        recencyWeight: 0.30,
        freshnessWeight: 0.40,
        onAreaUpdated: onAreaUpdated,
      );
    }

    if (itemId == 'home_maintenance') {
      return _computedHomeTaskCategory(
        areaId: areaId,
        itemId: itemId,
        category: HomeTaskCategory.maintenance,
        emptyReason:
            'Ainda não há tarefas de manutenção registradas para medir essa subárea.',
        reasonLabel: 'manutenção da casa',
        details:
            'Calculado automaticamente pelas tarefas de manutenção, considerando pendências acumuladas e a recência dos cuidados maiores com o ambiente.',
        excellentAction: 'A manutenção da casa está muito bem controlada.',
        goodAction: 'Boa situação de manutenção da casa.',
        mediumAction: 'A manutenção da casa está mediana no momento.',
        poorAction: 'A manutenção da casa está ficando para trás.',
        criticalAction:
            'A manutenção da casa está muito atrasada. Priorize os itens mais importantes.',
        completionWeight: 0.25,
        recencyWeight: 0.25,
        freshnessWeight: 0.50,
        onAreaUpdated: onAreaUpdated,
      );
    }

    return getAssessment(areaId, itemId);
  }

  Future<AreaAssessment?> _computedHomeTaskCategory({
    required String areaId,
    required String itemId,
    required HomeTaskCategory category,
    required String emptyReason,
    required String reasonLabel,
    required String details,
    required String excellentAction,
    required String goodAction,
    required String mediumAction,
    required String poorAction,
    required String criticalAction,
    required double completionWeight,
    required double recencyWeight,
    required double freshnessWeight,
    Future<void> Function(String areaId)? onAreaUpdated,
  }) async {
    final store = HomeTasksStore();
    await store.load();

    final items = store.items.where((e) => e.category == category).toList();
    if (items.isEmpty) {
      return _noDataAssessment(
        source: AreaDataSource.automatic,
        reason: emptyReason,
        action: 'Cadastre tarefas dessa categoria para ativar esta subárea.',
      );
    }

    final now = DateTime.now();
    final total = items.length;
    final done = items.where((e) => e.done).toList();
    final pending = items.where((e) => !e.done).toList();

    final completionRatio = done.length / total;

    final recentDone = done.where((e) {
      final updated = DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs);
      return now.difference(updated).inDays <= 7;
    }).length;
    final recentDoneRatio = recentDone / total;

    final lastDoneDate = done.isEmpty
        ? null
        : done
              .map((e) => DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs))
              .reduce((a, b) => a.isAfter(b) ? a : b);

    final freshnessScore = lastDoneDate == null
        ? 0
        : _scoreFromStops(
            now.difference(lastDoneDate).inDays.toDouble(),
            const [
              _ScoreStop(0, 100),
              _ScoreStop(2, 92),
              _ScoreStop(7, 75),
              _ScoreStop(14, 55),
              _ScoreStop(21, 35),
              _ScoreStop(30, 18),
              _ScoreStop(45, 0),
            ],
          );

    var score =
        ((completionRatio * completionWeight) +
            (recentDoneRatio * recencyWeight) +
            ((freshnessScore / 100.0) * freshnessWeight)) *
        100.0;

    if (pending.isNotEmpty) {
      final stalePending = pending.where((e) {
        final updated = DateTime.fromMillisecondsSinceEpoch(e.updatedAtMs);
        return now.difference(updated).inDays >= 14;
      }).length;
      score -= stalePending * 4.0;
    }

    final finalScore = score.round().clamp(0, 100);
    final status = _statusFromNumericScore(finalScore);
    final action = _actionFromStatus(
      status: status,
      excellent: excellentAction,
      good: goodAction,
      medium: mediumAction,
      poor: poorAction,
      critical: criticalAction,
    );

    if (onAreaUpdated != null) {
      await onAreaUpdated(areaId);
    }

    final reason =
        'Você concluiu ${done.length} de $total tarefas de $reasonLabel; '
        '$recentDone foram concluídas na última semana.';

    return AreaAssessment(
      status: status,
      score: finalScore,
      reason: reason,
      source: AreaDataSource.automatic,
      lastUpdatedAt: lastDoneDate ?? now,
      recommendedAction: action,
      details:
          '$details\n\nPendentes atuais: ${pending.length}. Última conclusão: ${_relativeDateLabel(lastDoneDate, now)}.',
    );
  }

  String _relativeDateLabel(DateTime? date, DateTime now) {
    if (date == null) return 'sem conclusão recente';
    final gap = now.difference(date).inDays;
    if (gap <= 0) return 'hoje';
    if (gap == 1) return 'ontem';
    return 'há $gap dias';
  }

  AreaAssessment _noDataAssessment({
    required AreaDataSource source,
    required String reason,
    required String action,
  }) {
    return AreaAssessment(
      status: AreaStatus.noData,
      score: 0,
      reason: reason,
      source: source,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: action,
    );
  }

  String _actionFromStatus({
    required AreaStatus status,
    required String excellent,
    required String good,
    required String medium,
    required String poor,
    required String critical,
  }) {
    switch (status) {
      case AreaStatus.excellent:
        return excellent;
      case AreaStatus.good:
        return good;
      case AreaStatus.medium:
        return medium;
      case AreaStatus.poor:
        return poor;
      case AreaStatus.critical:
        return critical;
      case AreaStatus.noData:
        return 'Atualize os dados dessa subárea.';
    }
  }

  AreaStatus _statusFromNumericScore(int score) {
    if (score >= 80) return AreaStatus.excellent;
    if (score >= 60) return AreaStatus.good;
    if (score >= 40) return AreaStatus.medium;
    if (score >= 20) return AreaStatus.poor;
    return AreaStatus.critical;
  }

  int _scoreFromStops(double value, List<_ScoreStop> stops) {
    if (stops.isEmpty) return 0;

    final ordered = [...stops]..sort((a, b) => a.x.compareTo(b.x));

    if (value <= ordered.first.x) {
      return ordered.first.score.clamp(0, 100);
    }

    for (var i = 1; i < ordered.length; i++) {
      final previous = ordered[i - 1];
      final current = ordered[i];

      if (value <= current.x) {
        final span = current.x - previous.x;
        if (span <= 0) return current.score.clamp(0, 100);

        final t = (value - previous.x) / span;
        final interpolated =
            previous.score + ((current.score - previous.score) * t);

        return interpolated.round().clamp(0, 100);
      }
    }

    return ordered.last.score.clamp(0, 100);
  }
}

class _ScoreStop {
  final double x;
  final int score;

  const _ScoreStop(this.x, this.score);
}
