import 'package:flutter/material.dart';

import '../../data/local/session_storage.dart';
import 'login_page.dart';

class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = SessionStorage();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home (placeholder)'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await storage.clear();
              if (!context.mounted) return;

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Text('✅ AutoLogin funcionando!'),
        ),
      ),
    );
  }
}
