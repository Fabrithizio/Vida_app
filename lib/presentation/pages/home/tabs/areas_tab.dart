import 'package:flutter/material.dart';

class AreasTab extends StatelessWidget {
  const AreasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        _AreaTile(title: 'Saúde', icon: Icons.favorite),
        _AreaTile(title: 'Trabalho', icon: Icons.work_outline),
        _AreaTile(title: 'Relacionamentos', icon: Icons.people_outline),
        _AreaTile(title: 'Financeiro', icon: Icons.account_balance_wallet_outlined),
      ],
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: const Text('Abrir detalhes dessa área.'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
