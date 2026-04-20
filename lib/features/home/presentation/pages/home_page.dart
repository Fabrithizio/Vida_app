// ============================================================================
// FILE: lib/features/home/presentation/pages/home_page.dart
//
// O que faz:
// - Página principal do app com bottom navigation
// - Cria um LifeAlertsService compartilhado
// - Passa o serviço para a aba Áreas, onde o sino fica visível
// - Permite abrir rotas principais a partir da central de alertas
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/always_on/presentation/widgets/always_on_floating_shell.dart';
import 'package:vida_app/features/areas/areas_store.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/alerts/life_alerts_service.dart';
import 'package:vida_app/features/finance/presentation/pages/finance_tab.dart';
import 'package:vida_app/features/finance/presentation/stores/finance_store.dart';
import 'package:vida_app/features/home/presentation/tabs/areas_tab.dart';
import 'package:vida_app/features/home/presentation/tabs/day_tab.dart';
import 'package:vida_app/features/home/presentation/tabs/profile_tab.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/hive_timeline_repository.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';
import 'package:vida_app/features/voice/application/voice_command_router.dart';
import 'package:vida_app/features/voice/presentation/voice_hub_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final ShoppingListStore _shopping = ShoppingListStore();
  final TimelineStore _timeline = TimelineStore(repo: HiveTimelineRepository());
  final HomeTasksStore _homeTasks = HomeTasksStore();
  final FinanceStore _finance = FinanceStore();
  final AreasStore _areas = AreasStore();
  final DailyCheckinService _dailyCheckin = DailyCheckinService();

  late final LifeAlertsService _alertsService = LifeAlertsService(
    areasStore: _areas,
    dailyCheckinService: _dailyCheckin,
    timelineStore: _timeline,
  );

  late final VoiceCommandRouter _router = VoiceCommandRouter(
    shopping: _shopping,
    timeline: _timeline,
    homeTasks: _homeTasks,
    finance: _finance,
  );

  Color _iconColor(bool selected) => selected ? Colors.green : Colors.white70;

  void _openVoiceHub() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1A),
      builder: (_) => VoiceHubSheet(router: _router),
    );
  }

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  void _openFinanceFromAlwaysOn() {
    setState(() => _index = 2);
  }

  void handleAlertRoute(String route) {
    switch (route) {
      case 'day':
        _goTo(0);
        break;
      case 'areas':
      case 'body_care':
      case 'life_journey':
        _goTo(1);
        break;
      case 'finance':
        _goTo(2);
        break;
      case 'always_on':
        _goTo(0);
        break;
      case 'goals':
        _goTo(0);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: [
                DayTab(
                  shoppingStore: _shopping,
                  timelineStore: _timeline,
                  homeTasksStore: _homeTasks,
                ),
                AreasTab(
                  isActive: _index == 1,
                  alertsService: _alertsService,
                  onOpenAlertRoute: handleAlertRoute,
                ),
                FinanceTab(store: _finance),
                const ProfileTab(),
              ],
            ),
          ),
          Positioned.fill(
            child: AlwaysOnFloatingShell(
              onOpenFinanceRequested: _openFinanceFromAlwaysOn,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(color: Color(0xFF0F0F1A)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Meu Dia',
              onPressed: () => _goTo(0),
              icon: Icon(
                _index == 0
                    ? Icons.view_timeline
                    : Icons.view_timeline_outlined,
                color: _iconColor(_index == 0),
              ),
            ),
            IconButton(
              tooltip: 'Áreas',
              onPressed: () => _goTo(1),
              icon: Icon(
                _index == 1 ? Icons.favorite : Icons.favorite_border,
                color: _iconColor(_index == 1),
              ),
            ),
            GestureDetector(
              onTap: _openVoiceHub,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(100),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.black, size: 22),
              ),
            ),
            IconButton(
              tooltip: 'Finanças',
              onPressed: () => _goTo(2),
              icon: Icon(
                _index == 2
                    ? Icons.account_balance_wallet
                    : Icons.account_balance_wallet_outlined,
                color: _iconColor(_index == 2),
              ),
            ),
            IconButton(
              tooltip: 'Perfil',
              onPressed: () => _goTo(3),
              icon: Icon(
                _index == 3 ? Icons.person : Icons.person_outline,
                color: _iconColor(_index == 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
