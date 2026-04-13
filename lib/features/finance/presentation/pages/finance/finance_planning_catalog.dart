// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_planning_catalog.dart
//
// Catálogo de planejamento financeiro do Vida.
//
// O que este arquivo faz:
// - Define em qual grupo cada categoria entra no Planejar.
// - Dá pesos base para a distribuição automática.
// - Marca quais categorias aparecem por padrão para não poluir a tela.
// - Aplica ajustes de estilo de vida, como casa própria, vale alimentação,
//   sem carro, passagem grátis e plano de saúde.
// ============================================================================

import '../../../data/models/finance_category.dart';
import 'finance_tab_models.dart';

class FinancePlanningCategoryMeta {
  const FinancePlanningCategoryMeta({
    required this.bucket,
    required this.baseWeight,
    required this.starter,
    required this.order,
  });

  final FinancePlanningBucketKind bucket;
  final double baseWeight;
  final bool starter;
  final int order;
}

class FinancePlanningCatalog {
  FinancePlanningCatalog._();

  static const Map<String, FinancePlanningCategoryMeta> _items = {
    'house_rent': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 2.3,
      starter: true,
      order: 10,
    ),
    'house_condo': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.9,
      starter: false,
      order: 11,
    ),
    'house_iptu': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.5,
      starter: false,
      order: 12,
    ),
    'house_insurance': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.4,
      starter: false,
      order: 13,
    ),
    'house_maintenance': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.6,
      starter: false,
      order: 14,
    ),
    'house_furniture': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.6,
      starter: false,
      order: 15,
    ),
    'utility_energy': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.0,
      starter: true,
      order: 16,
    ),
    'utility_water': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: true,
      order: 17,
    ),
    'utility_gas': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.5,
      starter: false,
      order: 18,
    ),
    'utility_internet': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: true,
      order: 19,
    ),
    'utility_phone': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.7,
      starter: false,
      order: 20,
    ),
    'food_market': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.9,
      starter: true,
      order: 30,
    ),
    'food_butcher': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: false,
      order: 31,
    ),
    'food_hortifruti': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: false,
      order: 32,
    ),
    'food_bakery': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.5,
      starter: false,
      order: 33,
    ),
    'food_cleaning': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.9,
      starter: true,
      order: 34,
    ),
    'leisure_restaurants': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 1.0,
      starter: true,
      order: 35,
    ),
    'leisure_delivery': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.9,
      starter: false,
      order: 36,
    ),
    'transport_fuel': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.2,
      starter: false,
      order: 40,
    ),
    'transport_parking': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.3,
      starter: false,
      order: 41,
    ),
    'transport_maintenance': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.6,
      starter: false,
      order: 42,
    ),
    'transport_insurance': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.4,
      starter: false,
      order: 43,
    ),
    'transport_ipva': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.3,
      starter: false,
      order: 44,
    ),
    'transport_toll': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.2,
      starter: false,
      order: 45,
    ),
    'transport_public': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.7,
      starter: true,
      order: 46,
    ),
    'transport_ride': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.5,
      starter: false,
      order: 47,
    ),
    'health_plan': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: false,
      order: 50,
    ),
    'health_medicine': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.5,
      starter: false,
      order: 51,
    ),
    'health_consult': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.4,
      starter: false,
      order: 52,
    ),
    'health_dentist': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.3,
      starter: false,
      order: 53,
    ),
    'health_therapy': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.3,
      starter: false,
      order: 54,
    ),
    'health_fitness': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.8,
      starter: false,
      order: 55,
    ),
    'health_hygiene': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.5,
      starter: false,
      order: 56,
    ),
    'education_school': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.1,
      starter: false,
      order: 60,
    ),
    'education_courses': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.7,
      starter: false,
      order: 61,
    ),
    'education_books': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.4,
      starter: false,
      order: 62,
    ),
    'software_apps': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.4,
      starter: false,
      order: 63,
    ),
    'shopping_clothes': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.8,
      starter: false,
      order: 70,
    ),
    'shopping_beauty': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.5,
      starter: false,
      order: 71,
    ),
    'shopping_laundry': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.3,
      starter: false,
      order: 72,
    ),
    'shopping_hardware': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.4,
      starter: false,
      order: 73,
    ),
    'personal_beauty': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.5,
      starter: false,
      order: 74,
    ),
    'tech_devices': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.5,
      starter: false,
      order: 80,
    ),
    'tech_maintenance': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.3,
      starter: false,
      order: 81,
    ),
    'leisure_cinema': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.4,
      starter: false,
      order: 90,
    ),
    'leisure_travel': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.7,
      starter: false,
      order: 91,
    ),
    'leisure_hobby': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.6,
      starter: false,
      order: 92,
    ),
    'leisure_gifts': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.3,
      starter: false,
      order: 93,
    ),
    'subscription_video': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.4,
      starter: true,
      order: 94,
    ),
    'subscription_music': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.3,
      starter: false,
      order: 95,
    ),
    'subscription_chatgpt': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.3,
      starter: false,
      order: 96,
    ),
    'subscription_games': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.3,
      starter: false,
      order: 97,
    ),
    'gaming_credits': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.2,
      starter: false,
      order: 98,
    ),
    'pet_food': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.7,
      starter: false,
      order: 100,
    ),
    'pet_vet': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.3,
      starter: false,
      order: 101,
    ),
    'pet_care': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.2,
      starter: false,
      order: 102,
    ),
    'pet_medicine': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.2,
      starter: false,
      order: 103,
    ),
    'debt_credit_card': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: false,
      order: 110,
    ),
    'debt_loan': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.8,
      starter: false,
      order: 111,
    ),
    'bank_fees': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.2,
      starter: false,
      order: 112,
    ),
    'finance_taxes': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.4,
      starter: false,
      order: 113,
    ),
    'finance_other_insurance': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.4,
      starter: false,
      order: 114,
    ),
    'future_emergency': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 1.4,
      starter: true,
      order: 120,
    ),
    'future_caixinha': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 1.0,
      starter: true,
      order: 121,
    ),
    'future_stocks': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 0.8,
      starter: false,
      order: 122,
    ),
    'future_crypto': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.future,
      baseWeight: 0.3,
      starter: false,
      order: 123,
    ),
    'family_children': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 1.0,
      starter: false,
      order: 130,
    ),
    'family_support': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.essential,
      baseWeight: 0.7,
      starter: false,
      order: 131,
    ),
    'other_expense': FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.4,
      starter: false,
      order: 999,
    ),
  };

  static FinancePlanningCategoryMeta metaOf(String id) {
    return _items[id] ?? _fallback(id);
  }

  static FinancePlanningBucketKind bucketOf(String id) => metaOf(id).bucket;
  static double baseWeightFor(String id) => metaOf(id).baseWeight;
  static bool starterFor(String id) => metaOf(id).starter;

  static String bucketLabel(FinancePlanningBucketKind bucket) {
    switch (bucket) {
      case FinancePlanningBucketKind.essential:
        return 'Essencial';
      case FinancePlanningBucketKind.future:
        return 'Investir + reserva';
      case FinancePlanningBucketKind.free:
        return 'Livre';
    }
  }

  static double profileMultiplier(
    String id, {
    required bool ownHome,
    required bool mealTicket,
    required bool noCar,
    required bool freeTransit,
    required bool hasHealthPlan,
  }) {
    if (ownHome && id == 'house_rent') return 0;

    if (mealTicket) {
      if ({
        'food_market',
        'food_butcher',
        'food_hortifruti',
        'food_bakery',
      }.contains(id)) {
        return 0.35;
      }
      if (id == 'leisure_restaurants' || id == 'leisure_delivery') {
        return 0.85;
      }
    }

    if (noCar &&
        {
          'transport_fuel',
          'transport_parking',
          'transport_maintenance',
          'transport_insurance',
          'transport_ipva',
          'transport_toll',
        }.contains(id)) {
      return 0;
    }

    if (freeTransit && id == 'transport_public') {
      return 0;
    }

    if (hasHealthPlan) {
      if ({'health_consult', 'health_dentist', 'health_therapy'}.contains(id)) {
        return 0.55;
      }
      if (id == 'health_medicine') {
        return 0.8;
      }
    }

    return 1;
  }

  static Set<String> defaultActiveIds(Iterable<FinanceCategory> categories) {
    final available = categories.map((item) => item.id).toSet();
    final defaults = _items.entries
        .where((entry) => entry.value.starter && available.contains(entry.key))
        .map((entry) => entry.key)
        .toSet();
    if (defaults.isNotEmpty) return defaults;
    return categories.take(8).map((item) => item.id).toSet();
  }

  static int compareCategories(FinanceCategory a, FinanceCategory b) {
    final metaA = metaOf(a.id);
    final metaB = metaOf(b.id);
    final bucketA = _bucketOrder(metaA.bucket);
    final bucketB = _bucketOrder(metaB.bucket);
    if (bucketA != bucketB) return bucketA.compareTo(bucketB);
    if (metaA.starter != metaB.starter) {
      return metaA.starter ? -1 : 1;
    }
    if (metaA.order != metaB.order) return metaA.order.compareTo(metaB.order);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _bucketOrder(FinancePlanningBucketKind bucket) {
    switch (bucket) {
      case FinancePlanningBucketKind.essential:
        return 0;
      case FinancePlanningBucketKind.future:
        return 1;
      case FinancePlanningBucketKind.free:
        return 2;
    }
  }

  static FinancePlanningCategoryMeta _fallback(String id) {
    if (id.startsWith('future_')) {
      return const FinancePlanningCategoryMeta(
        bucket: FinancePlanningBucketKind.future,
        baseWeight: 0.5,
        starter: false,
        order: 900,
      );
    }
    if (id.startsWith('house_') ||
        id.startsWith('utility_') ||
        id.startsWith('health_') ||
        id.startsWith('transport_') ||
        id.startsWith('food_') ||
        id.startsWith('family_') ||
        id.startsWith('debt_') ||
        id.startsWith('finance_')) {
      return const FinancePlanningCategoryMeta(
        bucket: FinancePlanningBucketKind.essential,
        baseWeight: 0.5,
        starter: false,
        order: 950,
      );
    }
    return const FinancePlanningCategoryMeta(
      bucket: FinancePlanningBucketKind.free,
      baseWeight: 0.5,
      starter: false,
      order: 980,
    );
  }
}
