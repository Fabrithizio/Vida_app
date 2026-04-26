// ============================================================================
// FILE: lib/features/areas/daily_checkin_service_integration_notes.dart
//
// O que faz:
// - Lista exatamente o que mudar no daily_checkin_service.dart atual
// - Evita sobrescrever o pool enorme de perguntas sem necessidade
//
// Mudanças objetivas:
// 1) adicionar imports:
//    import 'package:vida_app/features/areas/application/profile/live_user_profile_bridge.dart';
//    import 'package:vida_app/features/areas/daily_checkin_profile_hooks.dart';
//
// 2) adicionar campos no DailyCheckinService:
//    final LiveUserProfileBridge _profileBridge;
//    final DailyCheckinProfileHooks _profileHooks;
//
// 3) trocar o construtor por:
//    DailyCheckinService({
//      LiveUserProfileBridge? profileBridge,
//      DailyCheckinProfileHooks? profileHooks,
//    }) : _profileBridge = profileBridge ?? LiveUserProfileBridge(),
//         _profileHooks = profileHooks ?? DailyCheckinProfileHooks();
//
// 4) trocar currentProfileLabel por:
//    Future<String> currentProfileLabel({required DateTime now}) async {
//      final bridgeLabel = await _profileBridge.currentLabel();
//      final box = await _open();
//      await box.put(_profileCacheKey(now), bridgeLabel);
//      return bridgeLabel;
//    }
//
// 5) em tryCompleteIfAllAnswered, depois de salvar completed:
//    await _profileHooks.onCheckinCompleted();
// ============================================================================

class DailyCheckinServiceIntegrationNotes {}
