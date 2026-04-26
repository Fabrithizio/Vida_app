// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_refresh_button.dart
//
// O que faz:
// - Botão simples para forçar recálculo do perfil vivo
// - Útil para debug, QA e futuras telas administrativas
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_bridge.dart';

class LiveUserProfileRefreshButton extends StatefulWidget {
  const LiveUserProfileRefreshButton({super.key});

  @override
  State<LiveUserProfileRefreshButton> createState() =>
      _LiveUserProfileRefreshButtonState();
}

class _LiveUserProfileRefreshButtonState
    extends State<LiveUserProfileRefreshButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await LiveUserProfileBridge().forceRefresh();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil vivo atualizado.')),
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded),
      label: Text(_busy ? 'Atualizando...' : 'Atualizar perfil vivo'),
    );
  }
}
