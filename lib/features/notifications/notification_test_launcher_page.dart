import 'package:flutter/material.dart';
import 'package:vida_app/features/notifications/presentation/notification_test_page.dart';

class NotificationTestLauncherPage extends StatelessWidget {
  const NotificationTestLauncherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abrir teste')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationTestPage()),
            );
          },
          child: const Text('Abrir teste de notificações'),
        ),
      ),
    );
  }
}
