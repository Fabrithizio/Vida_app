// ============================================================================
// FILE: lib/features/areas/areas_store.dart
//
// O que faz:
// - Salva avaliações das áreas por usuário no Hive
// - Calcula itens dinamicamente com base em SharedPreferences
// - Conecta a área "Finanças & Material" ao módulo real de Finanças
// - Usa respostas do check-in diário para alimentar áreas do painel
// - Liga Ambiente & Casa às tarefas reais da casa
// - Liga Hábitos & Constância a sinais reais de rotina, constância e recuperação
//
// Nesta versão:
// - income     -> vem das entradas reais do mês atual no módulo Finanças
// - spending   -> vem das saídas reais do mês atual no módulo Finanças
//                  e usa apoio do check-in diário quando necessário
// - budget     -> usa gasto real + orçamento manual
// - debts      -> manual por enquanto
// - savings    -> manual por enquanto
// - goals_fin  -> manual por enquanto
// - energy, sleep, movement, nutrition e hydration
//   -> passam a vir do check-in diário
// - mood, stress e focus
//   -> passam a vir do check-in diário
// - organization e cleaning
//   -> passam a vir automaticamente das tarefas reais da casa
// - direction, goals_review e gratitude
//   -> passam a vir automaticamente de rotina, constância, recuperação e base do ambiente
//
// Atualizações desta revisão:
// - remove duplicações do sistema antigo de daily check-in
// - mantém o cálculo novo com histórico escalonado
// - corrige helpers internos para o modelo atual do DailyCheckinService
// - preserva o layout e a estrutura geral do app
//
// Correção importante:
// - _spendingAssessmentFromDailyCheckin agora é async (retorna Future)
//   e o fallback é resolvido dentro de _computedFinanceItem (async),
//   evitando o erro de tipo Future<AreaAssessment?> vs AreaAssessment?.
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
import 'package:vida_app/features/areas/application/scoring/areas_purpose_engine.dart';
import 'package:vida_app/features/areas/data/repositories/areas_storage_repository.dart';
import 'package:vida_app/features/areas/daily_checkin_service.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/finance/data/repositories/hive_finance_repository.dart';

class AreasStore {
  AreasStore({
    FinanceRepository? financeRepository,
    AreasStorageRepository? storage,
    AreasBootstrapService? bootstrap,
    AreasDailyQuestionsEngine? dailyQuestions,
    AreasAggregationEngine? aggregation,
    AreasBodyHealthEngine? bodyHealth,
    AreasDeviceUsageEngine? deviceUsage,
    AreasEnvironmentEngine? environment,
    AreasPurposeEngine? purpose,
    AreasFinanceEngine? financeEngine,
  }) : this._internal(
         financeRepository: financeRepository ?? HiveFinanceRepository(),
         storage: storage ?? AreasStorageRepository(),
         bootstrap: bootstrap,
         dailyQuestions:
             dailyQuestions ??
             AreasDailyQuestionsEngine(
               dailyCheckinService: DailyCheckinService(),
             ),
         aggregation: aggregation,
         bodyHealth: bodyHealth,
         deviceUsage: deviceUsage ?? AreasDeviceUsageEngine(),
         environment: environment ?? AreasEnvironmentEngine(),
         purpose: purpose,
         financeEngine: financeEngine,
       );

  AreasStore._internal({
    required FinanceRepository financeRepository,
    required AreasStorageRepository storage,
    AreasBootstrapService? bootstrap,
    required AreasDailyQuestionsEngine dailyQuestions,
    AreasAggregationEngine? aggregation,
    AreasBodyHealthEngine? bodyHealth,
    required AreasDeviceUsageEngine deviceUsage,
    required AreasEnvironmentEngine environment,
    AreasPurposeEngine? purpose,
    AreasFinanceEngine? financeEngine,
  }) : _storage = storage,
       _bootstrap = bootstrap ?? AreasBootstrapService(storage: storage),
       _dailyQuestions = dailyQuestions,
       _aggregation =
           aggregation ??
           AreasAggregationEngine(dailyQuestions: dailyQuestions),
       _bodyHealth =
           bodyHealth ?? AreasBodyHealthEngine(dailyQuestions: dailyQuestions),
       _deviceUsage = deviceUsage,
       _environment = environment,
       _purpose =
           purpose ??
           AreasPurposeEngine(
             dailyQuestions: dailyQuestions,
             environment: environment,
           ),
       _financeEngine =
           financeEngine ??
           AreasFinanceEngine(
             financeRepository: financeRepository,
             dailyQuestions: dailyQuestions,
           );

  final AreasStorageRepository _storage;
  final AreasBootstrapService _bootstrap;
  final AreasDailyQuestionsEngine _dailyQuestions;
  final AreasAggregationEngine _aggregation;
  final AreasBodyHealthEngine _bodyHealth;
  final AreasDeviceUsageEngine _deviceUsage;
  final AreasEnvironmentEngine _environment;
  final AreasPurposeEngine _purpose;
  final AreasFinanceEngine _financeEngine;

  Future<void> ensureBootstrappedFromOnboarding() {
    return _bootstrap.ensureBootstrappedFromOnboarding();
  }

  Future<AreaAssessment?> getComputedAssessment(
    String areaId,
    String itemId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return getAssessment(areaId, itemId);
    }

    if (areaId == 'body_health' && itemId == 'movement') {
      final movementAssessment = await _bodyHealth.computedMovement(
        onAreaUpdated: markAreaUpdated,
      );
      if (movementAssessment != null) {
        return movementAssessment;
      }
    }

    final dailyAssessment = await _dailyQuestions.computedDailyQuestionItem(
      areaId,
      itemId,
      onAreaUpdated: markAreaUpdated,
    );
    if (dailyAssessment != null) {
      return dailyAssessment;
    }

    if (areaId == 'body_health' && itemId == 'checkups') {
      return _bodyHealth.computedCheckups(
        user.uid,
        getAssessment: getAssessment,
      );
    }

    if (areaId == 'body_health' && itemId == 'sleep') {
      return _bodyHealth.computedSleep(onAreaUpdated: markAreaUpdated);
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
      final assessment = await _financeEngine.computedFinanceItem(
        user.uid,
        itemId,
        onAreaUpdated: markAreaUpdated,
      );
      return assessment ?? getAssessment('finance_material', itemId);
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

  Future<String?> trendLabel(String areaId, String itemId) {
    return _aggregation.trendLabel(areaId, itemId);
  }

  Future<AreaStatus?> overallStatus(String areaId, List<String> itemIds) {
    return _aggregation.overallStatus(
      areaId,
      itemIds,
      getComputedAssessment: getComputedAssessment,
    );
  }

  Future<int?> score(String areaId, List<String> itemIds) {
    return _aggregation.score(
      areaId,
      itemIds,
      getComputedAssessment: getComputedAssessment,
    );
  }

  Future<AreaAssessment?> _computedWomenCycle(String uid) async {
    return getAssessment('body_health', 'women_cycle');
  }
}
