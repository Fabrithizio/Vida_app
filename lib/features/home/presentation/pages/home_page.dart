// ============================================================================
// FILE: lib/presentation/pages/home/home_page.dart
//
// Navegação sem swipe + botão de voz integrado:
// - Sem PageView
// - Sem FAB gigante
// - Botão de voz central menor e estilizado
// - Navegação apenas por BottomBar
// ============================================================================

import 'package:flutter/material.dart';

import '../../../shopping/shopping_list_store.dart';
import '../../../timeline/hive_timeline_repository.dart';
import '../../../timeline/timeline_store.dart';
import '../../../../services/voice/voice_command_router.dart';
import '../../../../presentation/voice/voice_hub_sheet.dart';

import '../tabs/areas_tab.dart';
import '../tabs/day_tab.dart';
import '../tabs/profile_tab.dart';
import '../../../finance/presentation/pages/finance_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final ShoppingListStore _shopping = ShoppingListStore();
  final TimelineStore _timeline = TimelineStore(repo: HiveTimelineRepository());

  late final VoiceCommandRouter _router = VoiceCommandRouter(
    shopping: _shopping,
    timeline: _timeline,
  );

  late final List<Widget> _tabs = [
    DayTab(shoppingStore: _shopping, timelineStore: _timeline),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ✅ Sem swipe
      body: _tabs[_index],

      // ✅ Nova BottomBar com botão de voz integrado
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

            // 🎤 BOTÃO DE VOZ (central, menor e estilizado)
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
                      color: Colors.green.withValues(alpha: 0.4),
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
