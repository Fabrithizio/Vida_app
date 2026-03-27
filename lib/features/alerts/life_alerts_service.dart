import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/life_alert.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

class LifeAlertsService {
  LifeAlertsService({
    required AreasStore areasStore,
    required DailyCheckinService dailyCheckinService,
    required TimelineStore timelineStore,
  }) : _areasStore = areasStore,
       _dailyCheckinService = dailyCheckinService,
       _timelineStore = timelineStore;

  final AreasStore _areasStore;
  final DailyCheckinService _dailyCheckinService;
  final TimelineStore _timelineStore;

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

    alerts.sort((a, b) {
      final priorityCompare = LifeAlert.comparePriority(
        b.priority,
      ).compareTo(LifeAlert.comparePriority(a.priority));

      if (priorityCompare != 0) return priorityCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    return alerts;
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
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildBadCheckinAlerts(DateTime now) async {
    final alerts = <LifeAlert>[];

    int badDays = 0;

    for (var i = 0; i < 3; i++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));

      final questions = await _dailyCheckinService.questionsForToday(now: day);

      int sum = 0;
      int count = 0;

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
        ),
      );
    }

    return alerts;
  }

  Future<List<LifeAlert>> _buildStaleAreaAlerts(DateTime now) async {
    final alerts = <LifeAlert>[];

    const areaIds = <String>[
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
          ),
        );
      }
    }

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
    if (d.inMinutes < 60) {
      return '${d.inMinutes} min';
    }
    if (d.inHours < 24) {
      final hours = d.inHours;
      final minutes = d.inMinutes % 60;
      if (minutes == 0) return '$hours h';
      return '${hours}h ${minutes}min';
    }
    return '${d.inDays} dias';
  }
}
