// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas_tab_controller.dart
//
// O que faz:
// - Tira da UI parte da carga operacional da aba Áreas
// - Centraliza bootstrap, sync de perfil vivo e refresh dos dados automáticos
// - Ajuda a reduzir o efeito "polvo elegante" da areas_tab.dart
// ============================================================================

import 'package:vida_app/features/areas/application/bootstrap/areas_bootstrap_service.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_bridge.dart';
import 'package:vida_app/features/device/device_usage_service.dart';

class AreasTabController {
  AreasTabController({
    AreasBootstrapService? bootstrap,
    LiveUserProfileBridge? profileBridge,
    DeviceUsageService? deviceUsage,
  }) : _bootstrap = bootstrap ?? AreasBootstrapService(),
       _profileBridge = profileBridge ?? LiveUserProfileBridge(),
       _deviceUsage = deviceUsage ?? DeviceUsageService();

  final AreasBootstrapService _bootstrap;
  final LiveUserProfileBridge _profileBridge;
  final DeviceUsageService _deviceUsage;

  Future<void> prepareAreas() async {
    await _bootstrap.ensureBootstrappedFromOnboarding();
    try {
      await _deviceUsage.refreshAndPersistDigitalBuckets();
    } catch (_) {}
    await _profileBridge.syncIfNeeded();
  }

  Future<void> refreshProfileAfterImportantChange() async {
    await _profileBridge.forceRefresh();
  }

  Future<String> currentProfileLabel() {
    return _profileBridge.currentLabel();
  }
}
