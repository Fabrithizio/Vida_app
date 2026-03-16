// ============================================================================
// FILE: lib/presentation/pages/home/home_page.dart
//
// Home principal:
// - Corrige cores da AppBar e BottomAppBar (ícones sempre visíveis)
// - Realça o item selecionado (verde) e os outros (branco 70%)
// - Logout REAL: FirebaseAuth + GoogleSignIn (não entra sozinho ao reabrir)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:vida_app/features/finance/presentation/pages/finance_tab.dart';
import 'package:vida_app/features/shopping/shopping_list_store.dart';
import 'package:vida_app/features/timeline/hive_timeline_repository.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';
import 'package:vida_app/presentation/voice/voice_hub_sheet.dart';
import 'package:vida_app/services/voice/voice_command_router.dart';

import '../../../data/local/session_storage.dart';
import '../login_page.dart';
import 'tabs/areas_tab.dart';
import 'tabs/day_tab.dart';
import 'tabs/profile_tab.dart';

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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await SessionStorage().clear();

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _openVoiceHub() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1A),
      builder: (_) => VoiceHubSheet(router: _router),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = const ['Meu Dia', 'Áreas', 'Finanças', 'Perfil'];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Axyo — ${titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            color: Colors.white,
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openVoiceHub,
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        child: const Icon(Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0F0F1A),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: 'Meu Dia',
                onPressed: () => setState(() => _index = 0),
                icon: Icon(
                  _index == 0
                      ? Icons.view_timeline
                      : Icons.view_timeline_outlined,
                  color: _iconColor(_index == 0),
                ),
              ),
              IconButton(
                tooltip: 'Áreas',
                onPressed: () => setState(() => _index = 1),
                icon: Icon(
                  _index == 1 ? Icons.favorite : Icons.favorite_border,
                  color: _iconColor(_index == 1),
                ),
              ),
              const SizedBox(width: 56),
              IconButton(
                tooltip: 'Finanças',
                onPressed: () => setState(() => _index = 2),
                icon: Icon(
                  _index == 2
                      ? Icons.account_balance_wallet
                      : Icons.account_balance_wallet_outlined,
                  color: _iconColor(_index == 2),
                ),
              ),
              IconButton(
                tooltip: 'Perfil',
                onPressed: () => setState(() => _index = 3),
                icon: Icon(
                  _index == 3 ? Icons.person : Icons.person_outline,
                  color: _iconColor(_index == 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
