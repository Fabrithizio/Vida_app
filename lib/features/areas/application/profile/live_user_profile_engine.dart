// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_engine.dart
//
// O que faz:
// - Constrói um perfil vivo a partir do onboarding + sinais reais do app
// - Evita deixar o perfil preso só no check-in diário
// - Deixa o sistema pronto para o app agir como organismo vivo
//
// Ajustes desta versão:
// - lê sinais de apps úteis por categoria
// - usa esses sinais com peso leve/moderado no perfil vivo
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/finance/data/repositories/finance_repository.dart';
import 'package:vida_app/features/health_sync/health_sync_service.dart';
import 'package:vida_app/features/home_tasks/home_tasks_store.dart';

class LiveUserProfileSnapshot {
  const LiveUserProfileSnapshot({
    required this.id,
    required this.label,
    required this.reason,
    required this.tags,
    required this.primaryAreaIds,
  });

  final String id;
  final String label;
  final String reason;
  final Set<String> tags;
  final Set<String> primaryAreaIds;
}

class LiveUserProfileEngine {
  LiveUserProfileEngine({
    FinanceRepository? financeRepository,
    SmartHealthSyncService? smartHealth,
    HomeTasksStore? homeTasksStore,
  }) : _financeRepository = financeRepository,
       _smartHealth = smartHealth ?? SmartHealthSyncService(),
       _homeTasksStore = homeTasksStore ?? HomeTasksStore();

  final FinanceRepository? _financeRepository;
  final SmartHealthSyncService _smartHealth;
  final HomeTasksStore _homeTasksStore;

  Future<LiveUserProfileSnapshot> compute() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const LiveUserProfileSnapshot(
        id: 'perfil_em_adaptacao',
        label: 'Em adaptação',
        reason: 'Perfil ainda sem contexto suficiente.',
        tags: {'transition'},
        primaryAreaIds: {'mind_emotion', 'purpose_values'},
      );
    }

    final prefs = await SharedPreferences.getInstance();
    String read(String key) => (prefs.getString('$uid:$key') ?? '').trim();
    int readInt(String key) => prefs.getInt('$uid:$key') ?? 0;

    final tags = <String>{};
    final primaryAreas = <String>{};

    final studyWork = read('study_work');
    final livingWith = read('living_with');
    final children = read('children_count');
    final financial = read('financial_situation');
    final support = read('emotional_support');
    final loneliness = read('loneliness');
    final stress = read('stress_level');
    final consistency = read('consistency');
    final predictability = read('routine_predictability');
    final focus = read('focus');
    final goal = read('goal');

    if (studyWork.contains('Trabalho')) tags.add('worker');
    if (studyWork.contains('Estudo')) tags.add('student');
    if (livingWith.contains('sozinho')) tags.add('solo');
    if (livingWith.contains('Parceiro')) tags.add('with_partner');
    if (livingWith.contains('Família')) tags.add('with_family');
    if (children.startsWith('Sim')) tags.add('with_children');

    if (financial.contains('difícil') || financial.contains('Desorganizada')) {
      tags.add('financial_pressure');
      primaryAreas.add('finance_material');
    }

    if (support.contains('Quase não') || support == 'Não') {
      tags.add('support_low');
      primaryAreas.add('relations_community');
    }

    if (loneliness.contains('sozinho')) {
      tags.add('social_fragile');
      primaryAreas.add('relations_community');
    }

    if (stress.contains('Alto') || stress.contains('Muito alto')) {
      tags.add('stress_high');
      primaryAreas.add('mind_emotion');
    }

    if (consistency.contains('Pouco') || consistency == 'Não') {
      tags.add('low_constancy');
      primaryAreas.add('purpose_values');
    }

    if (predictability.contains('imprevisível') ||
        predictability.contains('bagunçada') ||
        predictability.contains('corrida')) {
      tags.add('chaotic');
      primaryAreas.add('work_vocation');
    }

    if (focus == 'Trabalho/estudos' || goal.contains('Evoluir')) {
      tags.add('growth_focus');
      primaryAreas.add('learning_intellect');
    }

    final health = await _smartHealth.readSnapshot(uid);
    if (health.isConnected && health.hasAnyData) {
      if ((health.sleepHours ?? 0) < 6.0) {
        tags.add('sleep_low');
        primaryAreas.add('body_health');
        primaryAreas.add('mind_emotion');
      }
      if ((health.stepsToday ?? 0) >= 7000 ||
          (health.exerciseMinutes7d ?? 0) >= 120) {
        tags.add('physically_active');
      }
    }

    try {
      await _homeTasksStore.load();
      if (_homeTasksStore.pendingCount >= 8) {
        tags.add('home_overload');
        primaryAreas.add('environment_home');
        primaryAreas.add('mind_emotion');
      }
    } catch (_) {}

    final studyMinutes = readInt('app_usage_study_minutes');
    final financeMinutes = readInt('app_usage_finance_minutes');
    final focusMinutes = readInt('app_usage_focus_minutes');
    final meditationMinutes = readInt('app_usage_meditation_minutes');
    final fitnessMinutes = readInt('app_usage_fitness_minutes');

    if (studyMinutes >= 8) {
      tags.add('study_apps_active');
      primaryAreas.add('learning_intellect');
      primaryAreas.add('purpose_values');
    }

    if (financeMinutes >= 4) {
      tags.add('finance_apps_active');
      primaryAreas.add('finance_material');
    }

    if (focusMinutes >= 6) {
      tags.add('focus_apps_active');
      primaryAreas.add('work_vocation');
      primaryAreas.add('learning_intellect');
    }

    if (meditationMinutes >= 5) {
      tags.add('mind_care_active');
      primaryAreas.add('mind_emotion');
    }

    if (fitnessMinutes >= 8) {
      tags.add('fitness_apps_active');
      primaryAreas.add('body_health');
    }

    final financeRepository = _financeRepository;
    if (financeRepository != null) {
      try {
        final all = await financeRepository.loadAll();
        double income = 0;
        double outcome = 0;
        for (final tx in all) {
          if (tx.isIncome) {
            income += tx.amount;
          } else {
            outcome += tx.amount;
          }
        }
        if (income > 0 && outcome <= income * 0.65) {
          tags.add('financial_stable');
        }
        if (income > 0 && outcome > income) {
          tags.add('financial_pressure');
          primaryAreas.add('finance_material');
        }
      } catch (_) {}
    }

    if (primaryAreas.isEmpty) {
      primaryAreas.addAll({'mind_emotion', 'purpose_values'});
    }

    if (tags.contains('stress_high') && tags.contains('financial_pressure')) {
      return LiveUserProfileSnapshot(
        id: 'perfil_pressao_total',
        label: 'Sob pressão',
        reason: 'O app identificou pressão mental e financeira recentes.',
        tags: tags,
        primaryAreaIds: primaryAreas,
      );
    }

    if ((tags.contains('growth_focus') && tags.contains('worker')) ||
        tags.contains('study_apps_active') ||
        tags.contains('focus_apps_active')) {
      return LiveUserProfileSnapshot(
        id: 'perfil_execucao_crescimento',
        label: 'Em crescimento',
        reason: 'Seu uso atual mostra foco em progresso, estudo ou execução.',
        tags: tags,
        primaryAreaIds: primaryAreas,
      );
    }

    if (tags.contains('home_overload') || tags.contains('with_children')) {
      return LiveUserProfileSnapshot(
        id: 'perfil_rotina_puxada',
        label: 'Rotina puxada',
        reason: 'O app identificou uma rotina mais pesada e carregada.',
        tags: tags,
        primaryAreaIds: primaryAreas,
      );
    }

    if (tags.contains('support_low') || tags.contains('social_fragile')) {
      return LiveUserProfileSnapshot(
        id: 'perfil_reconexao',
        label: 'Em reconexão',
        reason: 'O app percebeu sinais de apoio social mais frágil.',
        tags: tags,
        primaryAreaIds: primaryAreas,
      );
    }

    if (tags.contains('low_constancy') || tags.contains('chaotic')) {
      return LiveUserProfileSnapshot(
        id: 'perfil_retomada',
        label: 'Retomando o eixo',
        reason: 'Seu momento atual pede retomada de base e constância.',
        tags: tags,
        primaryAreaIds: primaryAreas,
      );
    }

    return LiveUserProfileSnapshot(
      id: 'perfil_em_adaptacao',
      label: 'Em adaptação',
      reason: 'Seu perfil continua se ajustando ao uso real do app.',
      tags: tags,
      primaryAreaIds: primaryAreas,
    );
  }
}
