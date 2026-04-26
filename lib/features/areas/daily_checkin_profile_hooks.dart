// ============================================================================
// FILE: lib/features/areas/daily_checkin_profile_hooks.dart
//
// O que faz:
// - Oferece hooks prontos para o DailyCheckinService ou DailyCheckinSheet
// - Depois de completar o check-in, força o refresh do perfil vivo
// - Mantém o check-in ligado ao organismo vivo do app
// ============================================================================

import 'package:vida_app/features/areas/application/profile/live_user_profile_bridge.dart';

class DailyCheckinProfileHooks {
  DailyCheckinProfileHooks({LiveUserProfileBridge? profileBridge})
    : _profileBridge = profileBridge ?? LiveUserProfileBridge();

  final LiveUserProfileBridge _profileBridge;

  Future<void> onCheckinCompleted() async {
    await _profileBridge.forceRefresh();
  }

  Future<String> currentProfileLabel() async {
    return _profileBridge.currentLabel();
  }
}
