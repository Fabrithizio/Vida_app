// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_service.dart
//
// O que faz:
// - Calcula o perfil vivo atual
// - Persiste o resultado em SharedPreferences
// - Deixa um ponto central para o resto do app ler o perfil sem recalcular
//   toda hora no escuro
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/areas/application/profile/live_user_profile_engine.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/health_sync/health_sync_service.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';

class LiveUserProfileService {
  LiveUserProfileService({
    FinanceRepository? financeRepository,
    SmartHealthSyncService? smartHealth,
    HomeTasksStore? homeTasksStore,
    LiveUserProfileEngine? engine,
  }) : _engine =
           engine ??
           LiveUserProfileEngine(
             financeRepository: financeRepository,
             smartHealth: smartHealth,
             homeTasksStore: homeTasksStore,
           );

  final LiveUserProfileEngine _engine;

  static const String _labelKey = 'live_profile:label';
  static const String _idKey = 'live_profile:id';
  static const String _reasonKey = 'live_profile:reason';
  static const String _tagsKey = 'live_profile:tags';
  static const String _areasKey = 'live_profile:areas';
  static const String _updatedAtKey = 'live_profile:updated_at';

  Future<LiveUserProfileSnapshot> refreshAndSave() async {
    final snapshot = await _engine.compute();
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';

    await prefs.setString('$uid:$_labelKey', snapshot.label);
    await prefs.setString('$uid:$_idKey', snapshot.id);
    await prefs.setString('$uid:$_reasonKey', snapshot.reason);
    await prefs.setStringList('$uid:$_tagsKey', snapshot.tags.toList());
    await prefs.setStringList(
      '$uid:$_areasKey',
      snapshot.primaryAreaIds.toList(),
    );
    await prefs.setString(
      '$uid:$_updatedAtKey',
      DateTime.now().toIso8601String(),
    );

    return snapshot;
  }

  Future<LiveUserProfileSnapshot?> readCached() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';

    final id = (prefs.getString('$uid:$_idKey') ?? '').trim();
    final label = (prefs.getString('$uid:$_labelKey') ?? '').trim();
    final reason = (prefs.getString('$uid:$_reasonKey') ?? '').trim();
    final tags = prefs.getStringList('$uid:$_tagsKey') ?? const <String>[];
    final areas = prefs.getStringList('$uid:$_areasKey') ?? const <String>[];

    if (id.isEmpty || label.isEmpty) return null;

    return LiveUserProfileSnapshot(
      id: id,
      label: label,
      reason: reason.isEmpty ? 'Perfil salvo em cache.' : reason,
      tags: tags.toSet(),
      primaryAreaIds: areas.toSet(),
    );
  }

  Future<LiveUserProfileSnapshot> getCurrent({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await readCached();
      if (cached != null) return cached;
    }
    return refreshAndSave();
  }
}
