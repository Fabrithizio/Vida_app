import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/data/repositories/areas_storage_repository.dart';

class AreasBootstrapService {
  AreasBootstrapService({AreasStorageRepository? storage})
    : _storage = storage ?? AreasStorageRepository();

  final AreasStorageRepository _storage;

  Future<void> ensureBootstrappedFromOnboarding() async {
    final box = await _storage.open();
    if (box.isNotEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    Future<void> seed(
      String areaId,
      String itemId,
      AreaStatus status, {
      String? reason,
      int? score,
      AreaDataSource source = AreaDataSource.onboarding,
    }) async {
      await box.put(
        _storage.itemKey(areaId, itemId),
        AreaAssessment(
          status: status,
          score: score,
          reason: reason,
          source: source,
          lastUpdatedAt: DateTime.now(),
        ).toMap(),
      );
      await prefs.setString(
        _storage.areaUpdatedPrefKey(uid, areaId),
        DateTime.now().toIso8601String(),
      );
    }

    final focus = (prefs.getString('$uid:focus') ?? '').trim();

    if (focus == 'Saúde') {
      await seed(
        'body_health',
        'nutrition',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
      await seed(
        'body_health',
        'movement',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Finanças') {
      await seed(
        'finance_material',
        'budget',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Produtividade') {
      await seed(
        'work_vocation',
        'routine',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Mental') {
      await seed(
        'mind_emotion',
        'mood',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    } else if (focus == 'Relacionamentos') {
      await seed(
        'relations_community',
        'friends',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
      await seed(
        'relations_community',
        'family',
        AreaStatus.good,
        reason: 'Área marcada como foco inicial no onboarding.',
        score: 70,
      );
    }
  }
}
