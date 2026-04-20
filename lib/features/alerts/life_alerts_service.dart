// ============================================================================
// FILE: lib/features/alerts/life_alerts_service.dart
//
// O que este arquivo faz:
// - Junta alertas importantes do app inteiro
// - Alimenta o sininho do topo
// - Prioriza o que realmente merece atenção do usuário
// - Lê radar, corpo em dia, jornada, finanças, check-in, timeline e metas
// - Remove alertas automaticamente quando o estado real já foi resolvido
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/life_alert.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/alerts/alerts_center_repository.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

class LifeAlertsService {
  LifeAlertsService({
    required AreasStore areasStore,
    required DailyCheckinService dailyCheckinService,
    required TimelineStore timelineStore,
    AlertsCenterRepository? repository,
    BodyCareService? bodyCareService,
  }) : _areasStore = areasStore,
       _dailyCheckinService = dailyCheckinService,
       _timelineStore = timelineStore,
       _repository = repository ?? AlertsCenterRepository(),
       _bodyCareService = bodyCareService ?? BodyCareService();

  final AreasStore _areasStore;
  final DailyCheckinService _dailyCheckinService;
  final TimelineStore _timelineStore;
  final AlertsCenterRepository _repository;
  final BodyCareService _bodyCareService;

  Future<List<LifeAlert>> generate({
    required DateTime now,
    double? monthlyBudget,
    double? monthSpending,
  }) async {
    final alerts = <LifeAlert>[];
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return alerts;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    alerts.addAll(await _buildCheckupAlerts(now, prefs, uid));
    alerts.addAll(await _buildBadCheckinAlerts(now));
    alerts.addAll(await _buildStaleAreaAlerts(now));
    alerts.addAll(
      await _buildFinanceAlerts(
        now: now,
        prefs: prefs,
        uid: uid,
        monthlyBudget: monthlyBudget,
        monthSpending: monthSpending,
      ),
    );
    alerts.addAll(_buildTimelineAlerts(now));
    alerts.addAll(await _buildAlwaysOnAlerts(now, prefs, uid));
    alerts.addAll(await _buildBodyCareAlerts(now));
    alerts.addAll(await _buildGoalsAlerts(now, prefs, uid));
    alerts.addAll(await _buildLifeJourneyAlerts(now, prefs, uid));

    alerts.sort((a, b) {
      final p = LifeAlert.comparePriority(
        b.priority,
      ).compareTo(LifeAlert.comparePriority(a.priority));
      if (p != 0) return p;
      return b.createdAt.compareTo(a.createdAt);
    });

    final readIds = await _repository.loadReadIds();
    return alerts
        .map(
          (item) =>
              readIds.contains(item.id) ? item.copyWith(isRead: true) : item,
        )
        .toList();
  }

  Future<int> unreadCount({
    required DateTime now,
    double? monthlyBudget,
    double? monthSpending,
  }) async {
    final alerts = await generate(
      now: now,
      monthlyBudget: monthlyBudget,
      monthSpending: monthSpending,
    );
    return alerts.where((item) => !item.isRead).length;
  }

  Future<void> markAsRead(String id) => _repository.markAsRead(id);

  Future<void> markAllAsRead({
    required DateTime now,
    double? monthlyBudget,
    double? monthSpending,
  }) async {
    final alerts = await generate(
      now: now,
      monthlyBudget: monthlyBudget,
      monthSpending: monthSpending,
    );
    await _repository.markAllAsRead(alerts);
  }

  Future<List<LifeAlert>> _buildCheckupAlerts(
    DateTime now,
    SharedPreferences prefs,
    String uid,
  ) async {
    final alerts = <LifeAlert>[];
    final raw = (prefs.getString('$uid:last_checkup') ?? '').trim();
    if (raw.isEmpty) return alerts;

    DateTime? lastCheckup;
    try {
      lastCheckup = DateTime.parse(raw);
    } catch (_) {
      return alerts;
    }

    final months = _monthsBetween(lastCheckup, now);
    final days = now.difference(lastCheckup).inDays;

    if (months >= 12) {
      alerts.add(
        LifeAlert(
          id: 'checkup_overdue_critical',
          type: LifeAlertType.overdueCheckup,
          title: 'Check-up atrasado',
          message:
              'Já faz $days dias desde o último check-up. Vale marcar uma revisão.',
          priority: LifeAlertPriority.critical,
          createdAt: now,
          areaId: 'body_health',
          actionLabel: 'Atualizar check-up',
          routeHint: 'areas',
          metadata: const {'areaId': 'body_health', 'itemId': 'checkups'},
        ),
      );
    } else if (months >= 6) {
      alerts.add(
        LifeAlert(
          id: 'checkup_overdue_attention',
          type: LifeAlertType.overdueCheckup,
          title: 'Check-up precisa de atenção',
          message:
              'Já faz $days dias desde o último check-up. Fique atento às datas.',
          priority: LifeAlertPriority.medium,
          createdAt: now,
          areaId: 'body_health',
          actionLabel: 'Ver saúde',
          routeHint: 'areas',
          metadata: const {'areaId': 'body_health', 'itemId': 'checkups'},
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildBadCheckinAlerts(DateTime now) async {
    final alerts = <LifeAlert>[];
    var badDays = 0;

    for (var i = 0; i < 3; i++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final questions = await _dailyCheckinService.questionsForToday(now: day);

      var sum = 0;
      var count = 0;
      for (final q in questions) {
        final answer = await _dailyCheckinService.getAnswer(
          day: day,
          questionId: q.id,
        );
        if (answer == null) continue;
        sum += answer;
        count++;
      }

      if (count == 0) continue;
      final avg = sum / count;
      if (avg <= 2.2) {
        badDays++;
      }
    }

    if (badDays >= 3) {
      alerts.add(
        LifeAlert(
          id: 'bad_checkin_streak',
          type: LifeAlertType.badCheckinStreak,
          title: 'Vários dias difíceis seguidos',
          message:
              'Seu check-in mostrou sinais ruins por $badDays dias seguidos. Vale revisar suas áreas prioritárias.',
          priority: LifeAlertPriority.high,
          createdAt: now,
          actionLabel: 'Abrir check-in',
          routeHint: 'areas',
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildStaleAreaAlerts(DateTime now) async {
    final alerts = <LifeAlert>[];
    const areaIds = [
      'body_health',
      'mind_emotion',
      'finance_material',
      'work_vocation',
      'learning_intellect',
      'relations_community',
      'digital_tech',
    ];

    for (final areaId in areaIds) {
      final last = await _areasStore.getAreaLastUpdate(areaId);
      if (last == null) continue;
      final days = now.difference(last).inDays;
      if (days < 30) continue;

      alerts.add(
        LifeAlert(
          id: 'stale_$areaId',
          type: LifeAlertType.staleArea,
          title: 'Área sem atualização',
          message: 'A área "$areaId" está sem atualização há $days dias.',
          priority: days >= 60
              ? LifeAlertPriority.high
              : LifeAlertPriority.medium,
          createdAt: now,
          areaId: areaId,
          actionLabel: 'Revisar área',
          routeHint: 'areas',
          metadata: {'areaId': areaId},
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildFinanceAlerts({
    required DateTime now,
    required SharedPreferences prefs,
    required String uid,
    required double? monthlyBudget,
    required double? monthSpending,
  }) async {
    final alerts = <LifeAlert>[];

    final budget =
        monthlyBudget ??
        _readDouble(prefs, [
          '$uid:monthly_budget',
          '$uid:budget_monthly',
          '$uid:finance_monthly_budget',
        ]);

    final spending =
        monthSpending ??
        _readDouble(prefs, [
          '$uid:month_spending',
          '$uid:monthly_spending',
          '$uid:finance_month_spending',
        ]);

    if (budget == null || budget <= 0 || spending == null || spending < 0) {
      return alerts;
    }

    final ratio = spending / budget;
    if (ratio >= 1.0) {
      alerts.add(
        LifeAlert(
          id: 'budget_exceeded',
          type: LifeAlertType.budgetExceeded,
          title: 'Orçamento estourado',
          message:
              'Você já gastou ${spending.toStringAsFixed(2)} de ${budget.toStringAsFixed(2)} no mês.',
          priority: LifeAlertPriority.critical,
          createdAt: now,
          areaId: 'finance_material',
          actionLabel: 'Ver finanças',
          routeHint: 'finance',
        ),
      );
    } else if (ratio >= 0.85) {
      alerts.add(
        LifeAlert(
          id: 'budget_high_usage',
          type: LifeAlertType.highSpendingMonth,
          title: 'Gastos altos no mês',
          message:
              'Você já usou ${(ratio * 100).round()}% do orçamento mensal.',
          priority: LifeAlertPriority.high,
          createdAt: now,
          areaId: 'finance_material',
          actionLabel: 'Ver finanças',
          routeHint: 'finance',
        ),
      );
    }

    return alerts;
  }

  List<LifeAlert> _buildTimelineAlerts(DateTime now) {
    final alerts = <LifeAlert>[];

    for (final item in _timelineStore.all) {
      if (item.type != TimelineBlockType.event) continue;
      final diff = item.start.difference(now);

      if (!diff.isNegative && diff.inHours <= 24) {
        alerts.add(
          LifeAlert(
            id: 'timeline_upcoming_${item.id}',
            type: LifeAlertType.upcomingTimelineEvent,
            title: 'Evento próximo',
            message: '"${item.title}" acontece em ${_humanizeDuration(diff)}.',
            priority: diff.inHours <= 2
                ? LifeAlertPriority.high
                : LifeAlertPriority.medium,
            createdAt: now,
            relatedId: item.id,
            actionLabel: 'Abrir timeline',
            routeHint: 'day',
          ),
        );
      }

      if (diff.isNegative && diff.inHours >= -24) {
        alerts.add(
          LifeAlert(
            id: 'timeline_overdue_${item.id}',
            type: LifeAlertType.overdueTimelineEvent,
            title: 'Evento passou',
            message:
                'O evento "${item.title}" já passou. Veja se precisa remarcar ou concluir.',
            priority: LifeAlertPriority.medium,
            createdAt: now,
            relatedId: item.id,
            actionLabel: 'Ver timeline',
            routeHint: 'day',
          ),
        );
      }
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildAlwaysOnAlerts(
    DateTime now,
    SharedPreferences prefs,
    String uid,
  ) async {
    final alerts = <LifeAlert>[];
    final title = (prefs.getString('$uid:always_on_last_top_title') ?? '')
        .trim();
    final reason = (prefs.getString('$uid:always_on_last_top_reason') ?? '')
        .trim();
    final key = (prefs.getString('$uid:always_on_last_top_key') ?? '').trim();

    if (title.isEmpty || key.isEmpty) return alerts;

    final seenKey = '$uid:always_on_last_seen_key';
    final lastSeen = (prefs.getString(seenKey) ?? '').trim();

    if (lastSeen != key) {
      alerts.add(
        LifeAlert(
          id: 'always_on_$key',
          type: LifeAlertType.alwaysOnRelevant,
          title: 'Radar encontrou algo para você',
          message: reason.isEmpty ? title : '$title • $reason',
          priority: LifeAlertPriority.high,
          createdAt: now,
          actionLabel: 'Abrir radar',
          routeHint: 'always_on',
          metadata: {'title': title, 'reason': reason, 'key': key},
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildBodyCareAlerts(DateTime now) async {
    final alerts = <LifeAlert>[];
    final day = DateTime(now.year, now.month, now.day);
    final entry = await _bodyCareService.loadDay(day);

    final pending = <String>[];
    if (entry.food == null) pending.add('alimentação');
    if (entry.training == null) pending.add('treino');
    if (entry.water == null) pending.add('água');

    if (pending.isNotEmpty) {
      alerts.add(
        LifeAlert(
          id: 'bodycare_pending_${day.toIso8601String().split('T').first}',
          type: LifeAlertType.bodyCarePending,
          title: 'Corpo em dia incompleto hoje',
          message:
              'Ainda falta cuidar de: ${pending.join(', ')}. Fechar isso mantém o ritmo vivo.',
          priority: pending.length >= 2
              ? LifeAlertPriority.high
              : LifeAlertPriority.medium,
          createdAt: now,
          actionLabel: 'Abrir corpo em dia',
          routeHint: 'body_care',
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildGoalsAlerts(
    DateTime now,
    SharedPreferences prefs,
    String uid,
  ) async {
    final alerts = <LifeAlert>[];
    final rawGoals =
        prefs.getStringList('$uid:goals_index') ?? const <String>[];

    if (rawGoals.isEmpty) return alerts;

    final stalled = prefs.getInt('$uid:goals_last_progress_days') ?? 0;
    if (stalled >= 7) {
      alerts.add(
        LifeAlert(
          id: 'goals_momentum_stalled',
          type: LifeAlertType.goalMomentum,
          title: 'Suas missões perderam ritmo',
          message:
              'Já faz $stalled dias sem avanço relevante nas missões. Vale fazer uma próxima jogada pequena.',
          priority: LifeAlertPriority.medium,
          createdAt: now,
          actionLabel: 'Abrir missões',
          routeHint: 'goals',
        ),
      );
    }

    final readyCount = prefs.getInt('$uid:goals_almost_done_count') ?? 0;
    if (readyCount > 0) {
      alerts.add(
        LifeAlert(
          id: 'goals_almost_done_$readyCount',
          type: LifeAlertType.goalMomentum,
          title: 'Missões quase virando fase',
          message:
              'Você tem $readyCount missão${readyCount > 1 ? 'ões' : ''} quase concluída${readyCount > 1 ? 's' : ''}.',
          priority: LifeAlertPriority.high,
          createdAt: now,
          actionLabel: 'Finalizar missão',
          routeHint: 'goals',
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildLifeJourneyAlerts(
    DateTime now,
    SharedPreferences prefs,
    String uid,
  ) async {
    final alerts = <LifeAlert>[];
    final unlockLabel =
        (prefs.getString('$uid:life_journey_last_unlock_label') ?? '').trim();
    final unlockKey =
        (prefs.getString('$uid:life_journey_last_unlock_key') ?? '').trim();
    final seenKey =
        (prefs.getString('$uid:life_journey_last_seen_unlock') ?? '').trim();

    if (unlockLabel.isEmpty || unlockKey.isEmpty) return alerts;
    if (seenKey == unlockKey) return alerts;

    alerts.add(
      LifeAlert(
        id: 'journey_unlock_$unlockKey',
        type: LifeAlertType.lifeJourneyUnlocked,
        title: 'Novo desbloqueio na linha da vida',
        message: unlockLabel,
        priority: LifeAlertPriority.high,
        createdAt: now,
        actionLabel: 'Ver desbloqueio',
        routeHint: 'life_journey',
        metadata: {'unlockKey': unlockKey, 'unlockLabel': unlockLabel},
      ),
    );

    return alerts;
  }

  double? _readDouble(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final raw = prefs.get(key);
      if (raw is num) return raw.toDouble();
      if (raw is String) {
        final normalized = raw.replaceAll(',', '.').trim();
        final parsed = double.tryParse(normalized);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int _monthsBetween(DateTime from, DateTime to) {
    var months = (to.year - from.year) * 12 + (to.month - from.month);
    if (to.day < from.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  String _humanizeDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m == 0 ? '$h h' : '${h}h ${m}min';
    }
    return '${d.inDays} dias';
  }
}
