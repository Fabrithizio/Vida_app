// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_keys.dart
//
// O que faz:
// - Centraliza as chaves usadas para salvar o perfil vivo
// - Evita string solta espalhada entre service, sync e bridge
// ============================================================================

class LiveUserProfileKeys {
  LiveUserProfileKeys._();

  static const String label = 'live_profile:label';
  static const String id = 'live_profile:id';
  static const String reason = 'live_profile:reason';
  static const String tags = 'live_profile:tags';
  static const String areas = 'live_profile:areas';
  static const String updatedAt = 'live_profile:updated_at';
  static const String lastSyncAt = 'live_profile:last_sync_at';
}
