// ============================================================================
// FILE: lib/features/home/presentation/pages/home_page.dart
//
// O que este arquivo faz:
// - Controla a navegação principal do app
// - Mantém Finanças na barra inferior
// - Adiciona o botão flutuante do Sempre Ligado sobre as abas principais
// ============================================================================
import 'package:flutter/material.dart';
import 'package:vida_app/features/always_on/presentation/widgets/always_on_floating_shell.dart';
import 'package:vida_app/features/finance/presentation/pages/finance_tab.dart';
import 'package:vida_app/features/home/presentation/tabs/areas_tab.dart';
import 'package:vida_app/features/home/presentation/tabs/day_tab.dart';
import 'package:vida_app/features/home/presentation/tabs/profile_tab.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/hive_timeline_repository.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';
import 'package:vida_app/presentation/voice/voice_hub_sheet.dart';
import 'package:vida_app/services/voice/voice_command_router.dart';

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

  late final VoiceCommandRouter _router = VoiceCommandRouter(
    shopping: _shopping,
    timeline: _timeline,
  );

  late final List<Widget> _tabs = [
    DayTab(
      shoppingStore: _shopping,
      timelineStore: _timeline,
      homeTasksStore: _homeTasks,
    ),
    const AreasTab(),
    const FinanceTab(),
    const ProfileTab(),
  ];

  Color _iconColor(bool selected) => selected ? Colors.green : Colors.white70;

  void _openVoiceHub() {
    showModalBottomSheet<void>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _tabs[_index]),
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
