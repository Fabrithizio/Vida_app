// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_planning_catalog.dart
//
// Catálogo do planejamento financeiro.
//
// O que este arquivo faz:
// - Diz em qual balde cada categoria entra: essenciais, futuro ou livre.
// - Define pesos base para a distribuição automática da renda.
// - Traz atalhos para adaptar o plano ao estilo de vida do usuário.
// - Mantém categorias detalhadas disponíveis sem poluir a home.
// ============================================================================

import '../../../data/models/finance_category.dart';
import 'finance_tab_models.dart';

class FinancePlanningCategoryConfig {
  const FinancePlanningCategoryConfig({
    required this.id,
    required this.bucket,
    required this.baseWeight,
    required this.starter,
    required this.order,
  });

  final String id;
  final FinancePlanningBucketKind bucket;
  final double baseWeight;
  final bool starter;
  final int order;
}

class FinancePlanningCatalog {
  FinancePlanningCatalog._();

  static FinancePlanningCategoryConfig ofId(String id) {
    return _configs[id] ?? _fallback(id);
  }

  static FinancePlanningBucketKind bucketOf(String id) => ofId(id).bucket;

  static double baseWeightFor(String id) => ofId(id).baseWeight;

  static String bucketLabel(FinancePlanningBucketKind bucket) {
    switch (bucket) {
      case FinancePlanningBucketKind.essential:
        return 'Essenciais';
      case FinancePlanningBucketKind.future:
        return 'Investir + reserva';
      case FinancePlanningBucketKind.free:
        return 'Livre e estilo de vida';
    }
  }

  static List<String> defaultActiveIds(Iterable<FinanceCategory> categories) {
    final items = categories.where((item) => ofId(item.id).starter).toList();
    items.sort(compareCategories);
    return items.map((item) => item.id).toList();
  }

  static int compareCategories(FinanceCategory a, FinanceCategory b) {
    final aConfig = ofId(a.id);
    final bConfig = ofId(b.id);
    final bucketCompare = aConfig.bucket.index.compareTo(bConfig.bucket.index);
    if (bucketCompare != 0) return bucketCompare;
    final orderCompare = aConfig.order.compareTo(bConfig.order);
    if (orderCompare != 0) return orderCompare;
    return a.name.compareTo(b.name);
  }

  static double profileMultiplier(
    String id, {
    required bool ownHome,
    required bool mealTicket,
    required bool noCar,
    required bool freeTransit,
    required bool hasHealthPlan,
  }) {
    var multiplier = 1.0;

    if (ownHome && id == 'house_rent') multiplier = 0;

    if (mealTicket) {
      if (id == 'food_market') multiplier *= 0.45;
      if (id == 'food_butcher') multiplier *= 0.45;
      if (id == 'food_hortifruti') multiplier *= 0.45;
      if (id == 'food_bakery') multiplier *= 0.65;
      if (id == 'leisure_restaurants') multiplier *= 0.75;
      if (id == 'leisure_delivery') multiplier *= 0.70;
    }

    if (noCar) {
      if ({
        'transport_fuel',
        'transport_parking',
        'transport_maintenance',
        'transport_insurance',
        'transport_ipva',
        'transport_toll',
      }.contains(id)) {
        multiplier = 0;
      }
    }

    if (freeTransit && id == 'transport_public') multiplier = 0;

    if (hasHealthPlan) {
      if (id == 'health_plan') multiplier *= 1.10;
      if (id == 'health_consult') multiplier *= 0.55;
      if (id == 'health_medicine') multiplier *= 0.80;
      if (id == 'health_dentist') multiplier *= 0.75;
    }

    return multiplier;
  }

  static FinancePlanningCategoryConfig _fallback(String id) {
    if (id.startsWith('future_')) {
      return FinancePlanningCategoryConfig(
        id: id,
        bucket: FinancePlanningBucketKind.future,
        baseWeight: 1,
        starter: false,
        order: 999,
      );
    }

    if (id.startsWith('leisure_') ||
        id.startsWith('shopping_') ||
        id.startsWith('subscription_') ||
        id.startsWith('gaming_') ||
        id.startsWith('tech_')) {
      return FinancePlanningCategoryConfig(
        id: id,
        bucket: FinancePlanningBucketKind.free,
        baseWeight: 1,
        starter: false,
        order: 999,
      );
    }

    return FinancePlanningCategoryConfig(
      id: id,
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1,
      starter: false,
      order: 999,
    );
  }

  static const Map<String, FinancePlanningCategoryConfig> _configs = {
    'food_market': FinancePlanningCategoryConfig(
      id: 'food_market',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.55,
      starter: true,
      order: 10,
    ),
    'food_cleaning': FinancePlanningCategoryConfig(
      id: 'food_cleaning',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.85,
      starter: true,
      order: 11,
    ),
    'food_butcher': FinancePlanningCategoryConfig(
      id: 'food_butcher',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.75,
      starter: false,
      order: 12,
    ),
    'food_hortifruti': FinancePlanningCategoryConfig(
      id: 'food_hortifruti',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.70,
      starter: false,
      order: 13,
    ),
    'food_bakery': FinancePlanningCategoryConfig(
      id: 'food_bakery',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.50,
      starter: false,
      order: 14,
    ),

    'house_rent': FinancePlanningCategoryConfig(
      id: 'house_rent',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.50,
      starter: true,
      order: 20,
    ),
    'house_condo': FinancePlanningCategoryConfig(
      id: 'house_condo',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.65,
      starter: false,
      order: 21,
    ),
    'house_iptu': FinancePlanningCategoryConfig(
      id: 'house_iptu',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.35,
      starter: false,
      order: 22,
    ),
    'house_insurance': FinancePlanningCategoryConfig(
      id: 'house_insurance',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.25,
      starter: false,
      order: 23,
    ),
    'house_maintenance': FinancePlanningCategoryConfig(
      id: 'house_maintenance',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.50,
      starter: false,
      order: 24,
    ),
    'house_furniture': FinancePlanningCategoryConfig(
      id: 'house_furniture',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.35,
      starter: false,
      order: 25,
    ),

    'utility_energy': FinancePlanningCategoryConfig(
      id: 'utility_energy',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.95,
      starter: true,
      order: 30,
    ),
    'utility_water': FinancePlanningCategoryConfig(
      id: 'utility_water',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.70,
      starter: true,
      order: 31,
    ),
    'utility_gas': FinancePlanningCategoryConfig(
      id: 'utility_gas',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.45,
      starter: false,
      order: 32,
    ),
    'utility_internet': FinancePlanningCategoryConfig(
      id: 'utility_internet',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.60,
      starter: true,
      order: 33,
    ),
    'utility_phone': FinancePlanningCategoryConfig(
      id: 'utility_phone',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.45,
      starter: true,
      order: 34,
    ),

    'transport_public': FinancePlanningCategoryConfig(
      id: 'transport_public',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.70,
      starter: true,
      order: 40,
    ),
    'transport_ride': FinancePlanningCategoryConfig(
      id: 'transport_ride',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.40,
      starter: false,
      order: 41,
    ),
    'transport_fuel': FinancePlanningCategoryConfig(
      id: 'transport_fuel',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.15,
      starter: false,
      order: 42,
    ),
    'transport_parking': FinancePlanningCategoryConfig(
      id: 'transport_parking',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.35,
      starter: false,
      order: 43,
    ),
    'transport_maintenance': FinancePlanningCategoryConfig(
      id: 'transport_maintenance',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.35,
      starter: false,
      order: 44,
    ),
    'transport_insurance': FinancePlanningCategoryConfig(
      id: 'transport_insurance',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.25,
      starter: false,
      order: 45,
    ),
    'transport_ipva': FinancePlanningCategoryConfig(
      id: 'transport_ipva',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.25,
      starter: false,
      order: 46,
    ),
    'transport_toll': FinancePlanningCategoryConfig(
      id: 'transport_toll',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.20,
      starter: false,
      order: 47,
    ),

    'health_plan': FinancePlanningCategoryConfig(
      id: 'health_plan',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.95,
      starter: true,
      order: 50,
    ),
    'health_medicine': FinancePlanningCategoryConfig(
      id: 'health_medicine',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.55,
      starter: false,
      order: 51,
    ),
    'health_consult': FinancePlanningCategoryConfig(
      id: 'health_consult',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.45,
      starter: false,
      order: 52,
    ),
    'health_dentist': FinancePlanningCategoryConfig(
      id: 'health_dentist',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.25,
      starter: false,
      order: 53,
    ),
    'health_therapy': FinancePlanningCategoryConfig(
      id: 'health_therapy',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.30,
      starter: false,
      order: 54,
    ),
    'health_fitness': FinancePlanningCategoryConfig(
      id: 'health_fitness',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.40,
      starter: false,
      order: 55,
    ),
    'health_hygiene': FinancePlanningCategoryConfig(
      id: 'health_hygiene',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.45,
      starter: false,
      order: 56,
    ),

    'education_school': FinancePlanningCategoryConfig(
      id: 'education_school',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.55,
      starter: false,
      order: 60,
    ),
    'education_courses': FinancePlanningCategoryConfig(
      id: 'education_courses',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.35,
      starter: false,
      order: 61,
    ),
    'education_books': FinancePlanningCategoryConfig(
      id: 'education_books',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.20,
      starter: false,
      order: 62,
    ),

    'pet_food': FinancePlanningCategoryConfig(
      id: 'pet_food',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.45,
      starter: false,
      order: 70,
    ),
    'pet_vet': FinancePlanningCategoryConfig(
      id: 'pet_vet',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.20,
      starter: false,
      order: 71,
    ),
    'pet_care': FinancePlanningCategoryConfig(
      id: 'pet_care',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.18,
      starter: false,
      order: 72,
    ),
    'pet_medicine': FinancePlanningCategoryConfig(
      id: 'pet_medicine',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.15,
      starter: false,
      order: 73,
    ),

    'debt_credit_card': FinancePlanningCategoryConfig(
      id: 'debt_credit_card',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.85,
      starter: true,
      order: 80,
    ),
    'debt_loan': FinancePlanningCategoryConfig(
      id: 'debt_loan',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.55,
      starter: false,
      order: 81,
    ),
    'bank_fees': FinancePlanningCategoryConfig(
      id: 'bank_fees',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.10,
      starter: false,
      order: 82,
    ),
    'finance_taxes': FinancePlanningCategoryConfig(
      id: 'finance_taxes',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.25,
      starter: false,
      order: 83,
    ),
    'finance_other_insurance': FinancePlanningCategoryConfig(
      id: 'finance_other_insurance',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.20,
      starter: false,
      order: 84,
    ),
    'family_children': FinancePlanningCategoryConfig(
      id: 'family_children',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.60,
      starter: false,
      order: 85,
    ),
    'family_support': FinancePlanningCategoryConfig(
      id: 'family_support',
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.45,
      starter: false,
      order: 86,
    ),

    'future_emergency': FinancePlanningCategoryConfig(
      id: 'future_emergency',
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 1.45,
      starter: true,
      order: 100,
    ),
    'future_caixinha': FinancePlanningCategoryConfig(
      id: 'future_caixinha',
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 0.90,
      starter: true,
      order: 101,
    ),
    'future_stocks': FinancePlanningCategoryConfig(
      id: 'future_stocks',
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 0.70,
      starter: false,
      order: 102,
    ),
    'future_crypto': FinancePlanningCategoryConfig(
      id: 'future_crypto',
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 0.35,
      starter: false,
      order: 103,
    ),

    'leisure_restaurants': FinancePlanningCategoryConfig(
      id: 'leisure_restaurants',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.95,
      starter: true,
      order: 120,
    ),
    'leisure_delivery': FinancePlanningCategoryConfig(
      id: 'leisure_delivery',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.80,
      starter: true,
      order: 121,
    ),
    'shopping_clothes': FinancePlanningCategoryConfig(
      id: 'shopping_clothes',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.50,
      starter: false,
      order: 122,
    ),
    'personal_beauty': FinancePlanningCategoryConfig(
      id: 'personal_beauty',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.35,
      starter: false,
      order: 123,
    ),
    'shopping_beauty': FinancePlanningCategoryConfig(
      id: 'shopping_beauty',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.35,
      starter: false,
      order: 124,
    ),
    'shopping_laundry': FinancePlanningCategoryConfig(
      id: 'shopping_laundry',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.15,
      starter: false,
      order: 125,
    ),
    'subscription_video': FinancePlanningCategoryConfig(
      id: 'subscription_video',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.30,
      starter: true,
      order: 126,
    ),
    'subscription_music': FinancePlanningCategoryConfig(
      id: 'subscription_music',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.15,
      starter: false,
      order: 127,
    ),
    'subscription_chatgpt': FinancePlanningCategoryConfig(
      id: 'subscription_chatgpt',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.15,
      starter: false,
      order: 128,
    ),
    'subscription_games': FinancePlanningCategoryConfig(
      id: 'subscription_games',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.15,
      starter: false,
      order: 129,
    ),
    'gaming_credits': FinancePlanningCategoryConfig(
      id: 'gaming_credits',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.10,
      starter: false,
      order: 130,
    ),
    'leisure_cinema': FinancePlanningCategoryConfig(
      id: 'leisure_cinema',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.20,
      starter: false,
      order: 131,
    ),
    'leisure_travel': FinancePlanningCategoryConfig(
      id: 'leisure_travel',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.25,
      starter: false,
      order: 132,
    ),
    'leisure_hobby': FinancePlanningCategoryConfig(
      id: 'leisure_hobby',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.30,
      starter: false,
      order: 133,
    ),
    'leisure_gifts': FinancePlanningCategoryConfig(
      id: 'leisure_gifts',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.12,
      starter: false,
      order: 134,
    ),
    'software_apps': FinancePlanningCategoryConfig(
      id: 'software_apps',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.15,
      starter: false,
      order: 135,
    ),
    'tech_devices': FinancePlanningCategoryConfig(
      id: 'tech_devices',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.25,
      starter: false,
      order: 136,
    ),
    'tech_maintenance': FinancePlanningCategoryConfig(
      id: 'tech_maintenance',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.15,
      starter: false,
      order: 137,
    ),
    'shopping_hardware': FinancePlanningCategoryConfig(
      id: 'shopping_hardware',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.18,
      starter: false,
      order: 138,
    ),
    'other_expense': FinancePlanningCategoryConfig(
      id: 'other_expense',
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.10,
      starter: false,
      order: 999,
    ),
  };
}
