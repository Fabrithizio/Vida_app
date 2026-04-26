// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_snapshot_card.dart
//
// O que faz:
// - Widget pronto para mostrar o perfil vivo atual em qualquer parte do app
// - Usa o cache do perfil vivo e pode ser encaixado depois no jogo, dashboard
//   ou perfil do usuário sem mexer na lógica central
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_service.dart';

class LiveUserProfileSnapshotCard extends StatelessWidget {
  const LiveUserProfileSnapshotCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LiveUserProfileService();

    return FutureBuilder(
      future: service.getCurrent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Carregando perfil vivo...',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final profile = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.reason,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }
}
