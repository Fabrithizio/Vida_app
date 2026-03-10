// lib/presentation/pages/home/tabs/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:vida_app/features/goals/presentation/pages/goals_hub_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final versionText = _info == null
        ? '...'
        : '${_info!.version}+${_info!.buildNumber}';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Perfil (mock)'),
            subtitle: Text('Preferências, metas e dados do usuário.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_tree),
            title: const Text('Metas'),
            subtitle: const Text('Criar, ver e acompanhar suas árvores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GoalsHubPage()));
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão do app'),
            subtitle: Text(versionText),
          ),
        ),
      ],
    );
  }
}
