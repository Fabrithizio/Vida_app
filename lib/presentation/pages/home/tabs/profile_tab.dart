import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    final versionText = _info == null ? '...' : '${_info!.version}+${_info!.buildNumber}';

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
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão do app'),
            subtitle: Text(versionText),
          ),
        ),
      ],
    );
  }
}
