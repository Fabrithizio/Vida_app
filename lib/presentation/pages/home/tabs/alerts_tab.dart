import 'package:flutter/material.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('Cuidados'),
            subtitle: Text('Alertas importantes aparecem aqui.'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.notifications_none),
            title: Text('Lembretes'),
            subtitle: Text('Notificações e lembretes do contexto.'),
          ),
        ),
      ],
    );
  }
}
