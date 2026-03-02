import 'package:flutter/material.dart';
import 'package:vida_app/features/timeline/hive_timeline_repository.dart';
import 'package:vida_app/features/timeline/timeline_store.dart';

import '../../../data/local/session_storage.dart';
import '../login_page.dart';
import 'tabs/alerts_tab.dart';
import 'tabs/areas_tab.dart';
import 'tabs/day_tab.dart';
import 'tabs/profile_tab.dart';

import 'package:vida_app/features/shopping/shopping_list_store.dart';
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

  late final VoiceCommandRouter _router = VoiceCommandRouter(
    shopping: _shopping,
    timeline: _timeline,
  );

  late final List<Widget> _tabs = [
    DayTab(shoppingStore: _shopping, timelineStore: _timeline),
    const AreasTab(),
    const AlertsTab(),
    const ProfileTab(),
  ];

  Future<void> _logout() async {
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
      builder: (_) => VoiceHubSheet(router: _router),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = const ['Meu Dia', 'Áreas', 'Alertas', 'Perfil'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Vida — ${titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),

      floatingActionButton: FloatingActionButton.large(
        onPressed: _openVoiceHub,
        child: const Icon(Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
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
                ),
              ),
              IconButton(
                tooltip: 'Áreas',
                onPressed: () => setState(() => _index = 1),
                icon: Icon(
                  _index == 1 ? Icons.favorite : Icons.favorite_border,
                ),
              ),
              const SizedBox(width: 56), // espaço do botão central
              IconButton(
                tooltip: 'Alertas',
                onPressed: () => setState(() => _index = 2),
                icon: Icon(
                  _index == 2 ? Icons.notifications : Icons.notifications_none,
                ),
              ),
              IconButton(
                tooltip: 'Perfil',
                onPressed: () => setState(() => _index = 3),
                icon: Icon(_index == 3 ? Icons.person : Icons.person_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
