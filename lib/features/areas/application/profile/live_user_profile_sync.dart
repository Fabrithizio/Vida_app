// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_sync.dart
//
// O que faz:
// - Define quando o perfil vivo deve ser recalculado
// - Evita recalcular sem necessidade o tempo todo
// - Permite sincronização leve por janela de tempo
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_service.dart';

class LiveUserProfileSync {
  LiveUserProfileSync({LiveUserProfileService? service})
    : _service = service ?? LiveUserProfileService();

  final LiveUserProfileService _service;

  static const String _lastSyncKey = 'live_profile:last_sync_at';
  static const Duration defaultSyncWindow = Duration(hours: 8);

  Future<bool> shouldSync({
    Duration window = defaultSyncWindow,
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final raw = prefs.getString('$uid:$_lastSyncKey');
    if (raw == null || raw.trim().isEmpty) return true;

    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return true;

    final current = now ?? DateTime.now();
    return current.difference(parsed) >= window;
  }

  Future<void> syncIfNeeded({
    Duration window = defaultSyncWindow,
    DateTime? now,
  }) async {
    if (!await shouldSync(window: window, now: now)) return;
    await forceSync(now: now);
  }

  Future<void> forceSync({DateTime? now}) async {
    await _service.refreshAndSave();

    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    await prefs.setString(
      '$uid:$_lastSyncKey',
      (now ?? DateTime.now()).toIso8601String(),
    );
  }
}
