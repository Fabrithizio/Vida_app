// ============================================================================
// FILE: lib/features/alerts/presentation/pages/alerts_center_page.dart
//
// O que este arquivo faz:
// - Exibe a central de alertas do app inteiro
// - Mostra o que merece atenção agora
// - Permite marcar tudo como lido
// - Deixa o sininho realmente útil e conectado com o resto do app
//
// Ajustes desta versão:
// - usa a leitura contextual por readKey
// - novos ícones para aniversário, check-in diário e saúde
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/data/models/life_alert.dart';
import 'package:vida_app/features/alerts/life_alerts_service.dart';

class AlertsCenterPage extends StatefulWidget {
  const AlertsCenterPage({
    super.key,
    required this.service,
    this.onOpenRoute,
    this.monthlyBudget,
    this.monthSpending,
  });

  final LifeAlertsService service;
  final ValueChanged<String>? onOpenRoute;
  final double? monthlyBudget;
  final double? monthSpending;

  @override
  State<AlertsCenterPage> createState() => _AlertsCenterPageState();
}

class _AlertsCenterPageState extends State<AlertsCenterPage> {
  bool _loading = true;
  List<LifeAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final alerts = await widget.service.generate(
      now: DateTime.now(),
      monthlyBudget: widget.monthlyBudget,
      monthSpending: widget.monthSpending,
    );
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  Future<void> _openAlert(LifeAlert alert) async {
    if (!alert.isRead) {
      await widget.service.markAlertAsRead(alert);
    }

    if (!mounted) return;

    Navigator.of(context).pop<LifeAlert>(alert);
  }

  Future<void> _markAllAsRead() async {
    await widget.service.markAllAsRead(
      now: DateTime.now(),
      monthlyBudget: widget.monthlyBudget,
      monthSpending: widget.monthSpending,
    );
    await _reload();
  }

  Color _priorityColor(LifeAlertPriority value) {
    switch (value) {
      case LifeAlertPriority.low:
        return const Color(0xFF94A3B8);
      case LifeAlertPriority.medium:
        return const Color(0xFFF59E0B);
      case LifeAlertPriority.high:
        return const Color(0xFF8B5CF6);
      case LifeAlertPriority.critical:
        return const Color(0xFFEF4444);
    }
  }

  IconData _iconForType(LifeAlertType value) {
    switch (value) {
      case LifeAlertType.overdueCheckup:
        return Icons.health_and_safety_rounded;
      case LifeAlertType.staleArea:
        return Icons.favorite_rounded;
      case LifeAlertType.badCheckinStreak:
      case LifeAlertType.dailyCheckinPending:
        return Icons.monitor_heart_rounded;
      case LifeAlertType.budgetExceeded:
      case LifeAlertType.highSpendingMonth:
        return Icons.account_balance_wallet_rounded;
      case LifeAlertType.upcomingTimelineEvent:
      case LifeAlertType.overdueTimelineEvent:
        return Icons.view_timeline_rounded;
      case LifeAlertType.alwaysOnRelevant:
        return Icons.radar_rounded;
      case LifeAlertType.bodyCarePending:
        return Icons.fitness_center_rounded;
      case LifeAlertType.goalMomentum:
        return Icons.flag_rounded;
      case LifeAlertType.lifeJourneyUnlocked:
      case LifeAlertType.genericUnlock:
        return Icons.auto_awesome_rounded;
      case LifeAlertType.birthdayCelebration:
        return Icons.celebration_rounded;
      case LifeAlertType.healthSyncDisconnected:
      case LifeAlertType.healthSyncStale:
        return Icons.watch_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _alerts.where((item) => !item.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Central de alertas'),
        actions: [
          if (_alerts.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Marcar tudo'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B1530), Color(0xFF0F1320)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tudo que merece sua atenção',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          unread == 0
                              ? 'No momento, não existe nada realmente urgente te chamando.'
                              : 'Você tem $unread alerta${unread > 1 ? 's' : ''} novo${unread > 1 ? 's' : ''} no app.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_alerts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10182B),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.notifications_off_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tudo limpo por enquanto',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._alerts.map((alert) {
                      final color = _priorityColor(alert.priority);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _openAlert(alert),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10182B),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: alert.isRead
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : color.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _iconForType(alert.type),
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              alert.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (!alert.isRead)
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        alert.message,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.76,
                                          ),
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if ((alert.actionLabel ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          alert.actionLabel!,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
