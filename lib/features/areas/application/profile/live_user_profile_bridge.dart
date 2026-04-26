// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_bridge.dart
//
// O que faz:
// - Cria uma ponte simples entre o check-in diário e o perfil vivo
// - Permite atualizar o perfil com base no uso real do app
// - Evita espalhar leitura de SharedPreferences e sync em vários lugares
//
// Como usar:
// - chame syncIfNeeded() quando a aba Áreas abrir
// - chame forceRefresh() depois de eventos importantes
// - use currentLabel() para mostrar o nome atual do perfil em qualquer tela
// ============================================================================

import 'package:vida_app/features/areas/application/profile/live_user_profile_service.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_sync.dart';

class LiveUserProfileBridge {
  LiveUserProfileBridge({
    LiveUserProfileService? service,
    LiveUserProfileSync? sync,
  }) : _service = service ?? LiveUserProfileService(),
       _sync =
           sync ??
           LiveUserProfileSync(service: service ?? LiveUserProfileService());

  final LiveUserProfileService _service;
  final LiveUserProfileSync _sync;

  Future<void> syncIfNeeded() => _sync.syncIfNeeded();

  Future<void> forceRefresh() => _sync.forceSync();

  Future<String> currentLabel({bool forceRefresh = false}) async {
    final profile = await _service.getCurrent(forceRefresh: forceRefresh);
    return profile.label.trim().isEmpty ? 'Em adaptação' : profile.label.trim();
  }

  Future<String> currentReason({bool forceRefresh = false}) async {
    final profile = await _service.getCurrent(forceRefresh: forceRefresh);
    return profile.reason.trim();
  }

  Future<Set<String>> currentTags({bool forceRefresh = false}) async {
    final profile = await _service.getCurrent(forceRefresh: forceRefresh);
    return profile.tags;
  }

  Future<Set<String>> currentPrimaryAreas({bool forceRefresh = false}) async {
    final profile = await _service.getCurrent(forceRefresh: forceRefresh);
    return profile.primaryAreaIds;
  }
}
