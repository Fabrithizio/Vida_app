// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// O que faz:
// - Salva avaliações das áreas por usuário no Hive
// - Calcula itens dinamicamente com base em SharedPreferences
// - Liga Saúde ao módulo Corpo & Saúde e ao Health Connect
// - Usa o sistema de perguntas adaptativas para alimentar o Areas
//
// Consolidação desta versão:
// - cria UMA instância compartilhada de AreasDailyQuestionsEngine
// - injeta essa mesma instância em aggregation/body/mind/purpose/finance
// - evita duplicação silenciosa de engine no construtor
// - mantém a fachada do módulo estável e mais previsível
//
// Ajuste desta revisão:
// - saveFinanceSnapshot agora também salva o gasto mensal consolidado
// - isso liga melhor Finanças com Areas e com alertas de orçamento
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/area_assessment.dart';
import 'package:vida_app/data/models/area_data_source.dart';
import 'package:vida_app/data/models/area_status.dart';
import 'package:vida_app/features/areas/application/bootstrap/areas_bootstrap_service.dart';
import 'package:vida_app/features/areas/application/scoring/areas_aggregation_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_body_health_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_daily_questions_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_device_usage_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_environment_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_finance_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_mind_emotion_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_purpose_engine.dart';
import 'package:vida_app/features/areas/application/scoring/areas_learning_consistency_engine.dart';
import 'package:vida_app/features/areas/data/repositories/areas_storage_repository.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/finance/data/repositories/hive_finance_repository.dart';

class AreasStore {
  AreasStore({
    FinanceRepository? financeRepository,
    AreasStorageRepository? storage,
    AreasBootstrapService? bootstrap,
    DailyCheckinService? dailyCheckinService,
    AreasDailyQuestionsEngine? dailyQuestions,
    AreasAggregationEngine? aggregation,
    AreasBodyHealthEngine? bodyHealth,
    AreasMindEmotionEngine? mindEmotion,
    AreasDeviceUsageEngine? deviceUsage,
    AreasEnvironmentEngine? environment,
    AreasPurposeEngine? purpose,
    AreasFinanceEngine? financeEngine,
  }) : this._internal(
         financeRepository: financeRepository ?? HiveFinanceRepository(),
         storage: storage ?? AreasStorageRepository(),
         bootstrap: bootstrap,
         dailyCheckinService: dailyCheckinService ?? DailyCheckinService(),
         dailyQuestions: dailyQuestions,
         aggregation: aggregation,
         bodyHealth: bodyHealth,
         mindEmotion: mindEmotion,
         deviceUsage: deviceUsage ?? AreasDeviceUsageEngine(),
         environment: environment ?? AreasEnvironmentEngine(),
         purpose: purpose,
         financeEngine: financeEngine,
       );

  AreasStore._internal({
    required FinanceRepository financeRepository,
    required AreasStorageRepository storage,
    AreasBootstrapService? bootstrap,
    required DailyCheckinService dailyCheckinService,
    AreasDailyQuestionsEngine? dailyQuestions,
    AreasAggregationEngine? aggregation,
    AreasBodyHealthEngine? bodyHealth,
    AreasMindEmotionEngine? mindEmotion,
    required AreasDeviceUsageEngine deviceUsage,
    required AreasEnvironmentEngine environment,
    AreasPurposeEngine? purpose,
    AreasFinanceEngine? financeEngine,
    AreasLearningConsistencyEngine? learningConsistency,
  }) : _storage = storage,
       _bootstrap = bootstrap ?? AreasBootstrapService(storage: storage),
       _dailyCheckinService = dailyCheckinService,
       _dailyQuestions =
           dailyQuestions ??
           AreasDailyQuestionsEngine(dailyCheckinService: dailyCheckinService),
       _deviceUsage = deviceUsage,
       _environment = environment,
       _aggregation =
           aggregation ??
           AreasAggregationEngine(
             dailyQuestions:
                 dailyQuestions ??
                 AreasDailyQuestionsEngine(
                   dailyCheckinService: dailyCheckinService,
                 ),
           ),
       _bodyHealth =
           bodyHealth ??
           AreasBodyHealthEngine(
             dailyQuestions:
                 dailyQuestions ??
                 AreasDailyQuestionsEngine(
                   dailyCheckinService: dailyCheckinService,
                 ),
           ),
       _mindEmotion =
           mindEmotion ??
           AreasMindEmotionEngine(
             dailyQuestions:
                 dailyQuestions ??
                 AreasDailyQuestionsEngine(
                   dailyCheckinService: dailyCheckinService,
                 ),
           ),
       _purpose =
           purpose ??
           AreasPurposeEngine(
             dailyQuestions:
                 dailyQuestions ??
                 AreasDailyQuestionsEngine(
                   dailyCheckinService: dailyCheckinService,
                 ),
             environment: environment,
           ),
       _financeEngine =
           financeEngine ??
           AreasFinanceEngine(
             financeRepository: financeRepository,
             dailyQuestions:
                 dailyQuestions ??
                 AreasDailyQuestionsEngine(
                   dailyCheckinService: dailyCheckinService,
                 ),
           ),
       _learningConsistency = learningConsistency ?? AreasLearningConsistencyEngine();

  factory AreasStore.consolidated({
    FinanceRepository? financeRepository,
    AreasStorageRepository? storage,
    AreasBootstrapService? bootstrap,
    DailyCheckinService? dailyCheckinService,
    AreasDeviceUsageEngine? deviceUsage,
    AreasEnvironmentEngine? environment,
  }) {
    final resolvedFinanceRepository =
        financeRepository ?? HiveFinanceRepository();
    final resolvedStorage = storage ?? AreasStorageRepository();
    final resolvedDailyCheckin = dailyCheckinService ?? DailyCheckinService();
    final resolvedEnvironment = environment ?? AreasEnvironmentEngine();
    final resolvedDailyQuestions = AreasDailyQuestionsEngine(
      dailyCheckinService: resolvedDailyCheckin,
    );

    return AreasStore._internal(
      financeRepository: resolvedFinanceRepository,
      storage: resolvedStorage,
      bootstrap: bootstrap,
      dailyCheckinService: resolvedDailyCheckin,
      dailyQuestions: resolvedDailyQuestions,
      aggregation: AreasAggregationEngine(
        dailyQuestions: resolvedDailyQuestions,
      ),
      bodyHealth: AreasBodyHealthEngine(dailyQuestions: resolvedDailyQuestions),
      mindEmotion: AreasMindEmotionEngine(
        dailyQuestions: resolvedDailyQuestions,
      ),
      deviceUsage: deviceUsage ?? AreasDeviceUsageEngine(),
      environment: resolvedEnvironment,
      purpose: AreasPurposeEngine(
        dailyQuestions: resolvedDailyQuestions,
        environment: resolvedEnvironment,
      ),
      financeEngine: AreasFinanceEngine(
        financeRepository: resolvedFinanceRepository,
        dailyQuestions: resolvedDailyQuestions,
      ),
    );
  }

  final AreasStorageRepository _storage;
  final AreasBootstrapService _bootstrap;
  final DailyCheckinService _dailyCheckinService;
  final AreasDailyQuestionsEngine _dailyQuestions;
  final AreasAggregationEngine _aggregation;
  final AreasBodyHealthEngine _bodyHealth;
  final AreasMindEmotionEngine _mindEmotion;
  final AreasDeviceUsageEngine _deviceUsage;
  final AreasEnvironmentEngine _environment;
  final AreasPurposeEngine _purpose;
  final AreasFinanceEngine _financeEngine;
  final AreasLearningConsistencyEngine _learningConsistency;

  Future<void> ensureBootstrappedFromOnboarding() =>
      _bootstrap.ensureBootstrappedFromOnboarding();

  DailyCheckinService get dailyCheckinService => _dailyCheckinService;

  Future<AreaAssessment?> getComputedAssessment(
    String areaId,
    String itemId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return getAssessment(areaId, itemId);

    if (areaId == 'body_health' && itemId == 'energy') {
      final a = await _bodyHealth.computedEnergy(
        onAreaUpdated: markAreaUpdated,
      );
      if (a != null) return a;
    }

    if (areaId == 'body_health' && itemId == 'movement') {
      final a = await _bodyHealth.computedMovement(
        onAreaUpdated: markAreaUpdated,
      );
      if (a != null) return a;
    }

    if (areaId == 'body_health' && itemId == 'sleep') {
      final a = await _bodyHealth.computedSleep(onAreaUpdated: markAreaUpdated);
      if (a != null) return a;
    }

    if (areaId == 'body_health' && itemId == 'nutrition') {
      final a = await _bodyHealth.computedNutrition(
        onAreaUpdated: markAreaUpdated,
      );
      if (a != null) return a;
    }

    if (areaId == 'body_health' && itemId == 'hydration') {
      final a = await _bodyHealth.computedHydration(
        onAreaUpdated: markAreaUpdated,
      );
      if (a != null) return a;
    }

    if (areaId == 'body_health' && itemId == 'imc') {
      final a = await _bodyHealth.computedImc(onAreaUpdated: markAreaUpdated);
      if (a != null) return a;
    }

    if (areaId == 'mind_emotion') {
      final a = await _mindEmotion.computedItem(
        itemId,
        getComputedAssessment: getComputedAssessment,
        onAreaUpdated: markAreaUpdated,
      );
      if (a != null) return a;
    }

    final dailyAssessment = await _dailyQuestions.computedDailyQuestionItem(
      areaId,
      itemId,
      onAreaUpdated: markAreaUpdated,
    );
    if (dailyAssessment != null) return dailyAssessment;

    if (areaId == 'body_health' && itemId == 'checkups') {
      return _bodyHealth.computedCheckups(
        user.uid,
        getAssessment: getAssessment,
      );
    }

    if (areaId == 'digital_tech' && itemId == 'screen_time') {
      return _deviceUsage.computedScreenTime(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'social_media') {
      return _deviceUsage.computedSocialMedia(user.uid);
    }

    if (areaId == 'digital_tech' && itemId == 'night_use') {
      return _deviceUsage.computedNightUse(user.uid);
    }

    if (areaId == 'learning_intellect' && itemId == 'consistency') {
      return _learningConsistency.computedConsistency(
        onAreaUpdated: markAreaUpdated,
      );
    }

    if (areaId == 'body_health' && itemId == 'women_cycle') {
      return _computedWomenCycle(user.uid);
    }

    if (areaId == 'purpose_values') {
      return _purpose.computedPurposeValuesItem(
        itemId,
        getAssessment: getAssessment,
        onAreaUpdated: markAreaUpdated,
      );
    }

    if (areaId == 'environment_home') {
      return _environment.computedEnvironmentItem(
        'environment_home',
        itemId,
        getAssessment: getAssessment,
        onAreaUpdated: markAreaUpdated,
      );
    }

    if (areaId == 'finance_material') {
      final a = await _financeEngine.computedFinanceItem(
        user.uid,
        itemId,
        onAreaUpdated: markAreaUpdated,
      );
      return a ?? getAssessment('finance_material', itemId);
    }

    return getAssessment(areaId, itemId);
  }

  Future<void> updateLastCheckupDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final iso = _bodyHealth.toIsoDate(date);

    await prefs.setString('${user.uid}:last_checkup', iso);
    await prefs.setString(
      _storage.areaUpdatedPrefKey(user.uid, 'body_health'),
      DateTime.now().toIso8601String(),
    );

    final computed = await _bodyHealth.computedCheckups(
      user.uid,
      getAssessment: getAssessment,
    );

    if (computed != null) {
      final box = await _storage.open();
      await box.put(
        _storage.itemKey('body_health', 'checkups'),
        computed.toMap(),
      );
    }
  }

  Future<void> saveFinanceSnapshot({
    double? monthlyBudget,
    double? totalDebts,
    double? emergencyReserve,
    double? goalsProgress,
    double? monthSpending,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    Future<void> setNum(String key, double? value) async {
      if (value == null) return;
      await prefs.setDouble(key, value);
    }

    await setNum('$uid:monthly_budget', monthlyBudget);
    await setNum('$uid:total_debts', totalDebts);
    await setNum('$uid:emergency_reserve', emergencyReserve);
    await setNum('$uid:finance_goals_progress', goalsProgress);
    await setNum('$uid:month_spending', monthSpending);
    await setNum('$uid:finance_month_spending', monthSpending);

    await prefs.setString(
      '$uid:finance_updated_at',
      DateTime.now().toIso8601String(),
    );
    await prefs.setString(
      _storage.areaUpdatedPrefKey(uid, 'finance_material'),
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getAreaLastUpdate(String areaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final raw =
        (prefs.getString(_storage.areaUpdatedPrefKey(user.uid, areaId)) ?? '')
            .trim();

    if (raw.isEmpty) return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> markAreaUpdated(String areaId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storage.areaUpdatedPrefKey(user.uid, areaId),
      DateTime.now().toIso8601String(),
    );
  }

  Future<AreaAssessment?> getAssessment(String areaId, String itemId) async {
    final box = await _storage.open();
    final raw = box.get(_storage.itemKey(areaId, itemId));
    if (raw is! Map) return null;
    return AreaAssessment.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> setAssessment(
    String areaId,
    String itemId, {
    required AreaStatus status,
    String? reason,
    int? score,
    AreaDataSource source = AreaDataSource.manual,
    String? recommendedAction,
    String? details,
  }) async {
    final box = await _storage.open();
    final value = AreaAssessment(
      status: status,
      score: score ?? _aggregation.scoreFromStatus(status),
      reason: reason,
      source: source,
      lastUpdatedAt: DateTime.now(),
      recommendedAction: recommendedAction,
      details: details,
    ).toMap();

    await box.put(_storage.itemKey(areaId, itemId), value);
    await markAreaUpdated(areaId);
  }

  Future<void> clearAssessment(String areaId, String itemId) async {
    final box = await _storage.open();
    await box.delete(_storage.itemKey(areaId, itemId));
  }

  Future<String?> trendLabel(String areaId, String itemId) =>
      _aggregation.trendLabel(areaId, itemId);

  Future<AreaStatus?> overallStatus(String areaId, List<String> itemIds) =>
      _aggregation.overallStatus(
        areaId,
        itemIds,
        getComputedAssessment: getComputedAssessment,
      );

  Future<int?> score(String areaId, List<String> itemIds) => _aggregation.score(
    areaId,
    itemIds,
    getComputedAssessment: getComputedAssessment,
  );

  Future<AreaAssessment?> _computedWomenCycle(String uid) =>
      getAssessment('body_health', 'women_cycle');
}
