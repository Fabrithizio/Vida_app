import 'package:flutter/material.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Perfil (mock)'),
            subtitle: Text('Preferências, metas e dados do usuário.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Segurança'),
            subtitle: Text('Trocar senha, biometria (depois).'),
          ),
        ),
      ],
    );
  }
}
