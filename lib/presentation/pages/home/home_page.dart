import 'package:flutter/material.dart';

import '../../../data/local/session_storage.dart';
import '../login_page.dart';
import 'tabs/alerts_tab.dart';
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

  final _tabs = const [
    DayTab(),
    AreasTab(),
    AlertsTab(),
    ProfileTab(),
  ];

  Future<void> _logout() async {
    await SessionStorage().clear();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
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
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_timeline_outlined),
            label: 'Meu Dia',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Áreas',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
