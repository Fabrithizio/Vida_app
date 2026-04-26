// ============================================================================
// FILE: lib/features/home/presentation/tabs/profile_mutable_question_ids.dart
//
// O que faz:
// - Centraliza os ids mutáveis do onboarding que ainda podem ser editados
// - Remove ids antigos que não fazem mais parte do onboarding atual
// - Evita que ProfileTab continue esperando perguntas de legado
// ============================================================================

const List<String> profileMutableQuestionIds = <String>[
  'living_with',
  'children_count',
  'family_relationship',
  'home_routine_load',
  'study_work',
  'occupation_type',
  'work_field',
  'work_schedule_format',
  'work_demand_type',
  'stress_level',
  'emotional_state',
  'rest_capacity',
  'mental_load',
  'financial_situation',
  'income_stability',
  'financial_main_difficulty',
  'dependents_financial',
  'social_life',
  'emotional_support',
  'loneliness',
  'personal_organization',
  'home_organization',
  'consistency',
  'routine_predictability',
  'routine_main_weight',
  'focus',
  'goal',
  'app_help',
  'start_preference',
];
