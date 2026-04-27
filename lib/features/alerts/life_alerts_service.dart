// ============================================================================
// FILE: lib/features/alerts/life_alerts_service.dart
//
// O que este arquivo faz:
// - Junta alertas importantes do app inteiro
// - Alimenta o sininho do topo
// - Prioriza o que realmente merece atenção do usuário
// - Lê radar, corpo em dia, jornada, finanças, check-in, timeline e metas
// - Remove alertas automaticamente quando o estado real já foi resolvido
// - Agora integra saúde desconectada / sem sync recente e aniversário
//
// Ajustes importantes desta versão:
// - leitura contextual por readKey
// - novos alertas: check-in pendente, saúde desconectada/stale, aniversário
// - ids/contextos mais inteligentes para o alerta poder voltar quando fizer
//   sentido de novo
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/life_alert.dart';
import 'package:vida_app/data/models/timeline_block.dart';
import 'package:vida_app/features/alerts/alerts_center_repository.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';
import 'package:vida_app/features/goals/goals_alerts_bridge.dart';
import 'package:vida_app/features/health_sync/health_sync_service.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

class LifeAlertsService {
  LifeAlertsService({
    required AreasStore areasStore,
    required DailyCheckinService dailyCheckinService,
    required TimelineStore timelineStore,
    AlertsCenterRepository? repository,
    BodyCareService? bodyCareService,
    GoalsAlertsBridge? goalsAlertsBridge,
    SmartHealthSyncService? smartHealthService,
  }) : _areasStore = areasStore,
       _dailyCheckinService = dailyCheckinService,
       _timelineStore = timelineStore,
       _repository = repository ?? AlertsCenterRepository(),
       _bodyCareService = bodyCareService ?? BodyCareService(),
       _goalsAlertsBridge = goalsAlertsBridge ?? GoalsAlertsBridge(),
       _smartHealthService = smartHealthService ?? SmartHealthSyncService();

  final AreasStore _areasStore;
  final DailyCheckinService _dailyCheckinService;
  final TimelineStore _timelineStore;
  final AlertsCenterRepository _repository;
  final BodyCareService _bodyCareService;
  final GoalsAlertsBridge _goalsAlertsBridge;
  final SmartHealthSyncService _smartHealthService;

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

    alerts.addAll(await _buildBirthdayAlerts(now, prefs, uid));
    alerts.addAll(await _buildDailyCheckinPendingAlerts(now));
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
    alerts.addAll(await _buildGoalsAlerts(now));
    alerts.addAll(await _buildHealthAlerts(now, uid));
    alerts.addAll(await _buildLifeJourneyAlerts(now, prefs, uid));

    alerts.sort((a, b) {
      final p = LifeAlert.comparePriority(
        b.priority,
      ).compareTo(LifeAlert.comparePriority(a.priority));
      if (p != 0) return p;
      return b.createdAt.compareTo(a.createdAt);
    });

    final readKeys = await _repository.loadReadKeys();
    return alerts
        .map(
          (item) => readKeys.contains(item.effectiveReadKey)
              ? item.copyWith(isRead: true)
              : item,
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

  Future<void> markAsRead(String key) => _repository.markAsReadKey(key);

  Future<void> markAlertAsRead(LifeAlert alert) =>
      _repository.markAsReadAlert(alert);

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

  Future<List<LifeAlert>> _buildBirthdayAlerts(
    DateTime now,
    SharedPreferences prefs,
    String uid,
  ) async {
    final alerts = <LifeAlert>[];
    final birthRaw =
        (prefs.getString('birth_date_$uid') ??
                prefs.getString('$uid:birthDate') ??
                prefs.getString('$uid:birthdate') ??
                prefs.getString('$uid:dateOfBirth') ??
                prefs.getString('$uid:dob') ??
                '')
            .trim();

    if (birthRaw.isEmpty) return alerts;
    final birthDate = DateTime.tryParse(birthRaw);
    if (birthDate == null) return alerts;

    if (birthDate.day != now.day || birthDate.month != now.month) {
      return alerts;
    }

    final age = _ageAt(birthDate, now);
    final contextKey =
        'birthday_${now.year}_${birthDate.day}_${birthDate.month}';

    alerts.add(
      LifeAlert(
        id: contextKey,
        readKey: contextKey,
        type: LifeAlertType.birthdayCelebration,
        title: 'Hoje é seu dia 🎉',
        message:
            'Parabéns${age > 0 ? ' pelos $age anos' : ''}! A Linha da Vida e o resto do app podem ter coisas novas para você hoje.',
        priority: LifeAlertPriority.high,
        createdAt: now,
        actionLabel: 'Abrir Linha da Vida',
        routeHint: 'life_journey',
        metadata: {
          'year': now.year.toString(),
          'birthdayDay': birthDate.day.toString(),
          'birthdayMonth': birthDate.month.toString(),
          'age': age.toString(),
        },
      ),
    );

    return alerts;
  }

  Future<List<LifeAlert>> _buildDailyCheckinPendingAlerts(DateTime now) async {
    final alerts = <LifeAlert>[];
    final day = DateTime(now.year, now.month, now.day);
    final canUse = await _dailyCheckinService.canUseAreas(day);
    if (canUse) return alerts;

    final key =
        'daily_checkin_pending_${day.toIso8601String().split('T').first}';
    alerts.add(
      LifeAlert(
        id: key,
        readKey: key,
        type: LifeAlertType.dailyCheckinPending,
        title: 'Check-in do dia pendente',
        message:
            'Seu check-in de hoje ainda não foi fechado. Responder isso ajuda o app a ler melhor seu momento atual.',
        priority: LifeAlertPriority.high,
        createdAt: now,
        actionLabel: 'Abrir check-in',
        routeHint: 'areas',
      ),
    );

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
    final iso = raw.split('T').first;

    if (months >= 12) {
      final key = 'checkup_overdue_critical_$iso';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
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
      final key = 'checkup_overdue_attention_$iso';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
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
      final key =
          'bad_checkin_streak_${DateTime(now.year, now.month, now.day).toIso8601String().split('T').first}_$badDays';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
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

      final bucket = days >= 90
          ? '90'
          : days >= 60
          ? '60'
          : '30';
      final lastIso = last.toIso8601String().split('T').first;

      alerts.add(
        LifeAlert(
          id: 'stale_${areaId}_${bucket}_$lastIso',
          readKey: 'stale_${areaId}_${bucket}_$lastIso',
          type: LifeAlertType.staleArea,
          title: 'Área sem atualização',
          message:
              'A área "${_areaLabel(areaId)}" está sem atualização há $days dias.',
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
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    if (ratio >= 1.0) {
      final key =
          'budget_exceeded_${monthKey}_${spending.toStringAsFixed(0)}_${budget.toStringAsFixed(0)}';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
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
      final key = 'budget_high_usage_${monthKey}_${(ratio * 100).round()}';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
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
      final startKey = item.start.toIso8601String();

      if (!diff.isNegative && diff.inHours <= 24) {
        final key = 'timeline_upcoming_${item.id}_$startKey';
        alerts.add(
          LifeAlert(
            id: key,
            readKey: key,
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
        final key = 'timeline_overdue_${item.id}_$startKey';
        alerts.add(
          LifeAlert(
            id: key,
            readKey: key,
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
          readKey: 'always_on_$key',
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
      final key =
          'bodycare_pending_${day.toIso8601String().split('T').first}_${pending.join('_')}';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
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

  Future<List<LifeAlert>> _buildGoalsAlerts(DateTime now) async {
    return _goalsAlertsBridge.build(now);
  }

  Future<List<LifeAlert>> _buildHealthAlerts(DateTime now, String uid) async {
    final alerts = <LifeAlert>[];
    final snapshot = await _smartHealthService.readSnapshot(uid);

    if (!snapshot.isConnected) {
      final key = 'health_sync_disconnected';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
          type: LifeAlertType.healthSyncDisconnected,
          title: 'Saúde automática desconectada',
          message:
              'O app ainda não está recebendo dados do Health Connect. Conectar isso pode deixar Corpo & Saúde mais preciso.',
          priority: LifeAlertPriority.medium,
          createdAt: now,
          actionLabel: 'Abrir conexão de saúde',
          routeHint: 'smart_health',
        ),
      );
      return alerts;
    }

    final lastSyncAt = snapshot.lastSyncAt;
    if (lastSyncAt == null) {
      final key = 'health_sync_stale_never';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
          type: LifeAlertType.healthSyncStale,
          title: 'Saúde conectada, mas sem sync útil',
          message:
              'A conexão de saúde existe, mas o app ainda não conseguiu registrar uma sincronização válida.',
          priority: LifeAlertPriority.medium,
          createdAt: now,
          actionLabel: 'Sincronizar saúde',
          routeHint: 'smart_health',
        ),
      );
      return alerts;
    }

    final days = now.difference(lastSyncAt).inDays;
    if (days >= 4) {
      final bucket = days >= 10 ? '10+' : '4+';
      final lastSyncIso = lastSyncAt.toIso8601String().split('T').first;
      final key = 'health_sync_stale_${bucket}_$lastSyncIso';
      alerts.add(
        LifeAlert(
          id: key,
          readKey: key,
          type: LifeAlertType.healthSyncStale,
          title: 'Saúde sem sincronizar há alguns dias',
          message:
              'Sua última sync de saúde foi há $days dias. Atualizar isso pode melhorar a leitura do corpo.',
          priority: days >= 10
              ? LifeAlertPriority.high
              : LifeAlertPriority.medium,
          createdAt: now,
          actionLabel: 'Sincronizar saúde',
          routeHint: 'smart_health',
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
        readKey: 'journey_unlock_$unlockKey',
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

  int _ageAt(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    final birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day);
    if (DateTime(now.year, now.month, now.day).isBefore(birthdayThisYear)) {
      age--;
    }
    return age < 0 ? 0 : age;
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

  String _areaLabel(String areaId) {
    switch (areaId) {
      case 'body_health':
        return 'Corpo & Saúde';
      case 'mind_emotion':
        return 'Mente & Emoções';
      case 'finance_material':
        return 'Finanças & Material';
      case 'work_vocation':
        return 'Trabalho & Vocação';
      case 'learning_intellect':
        return 'Aprendizado & Intelecto';
      case 'relations_community':
        return 'Relações & Comunidade';
      case 'digital_tech':
        return 'Digital & Tecnologia';
      default:
        return areaId;
    }
  }
}
