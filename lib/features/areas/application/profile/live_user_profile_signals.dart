// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_signals.dart
//
// O que faz:
// - Define a estrutura de sinais lidos do app para alimentar o perfil vivo
// - Deixa claro o que veio do onboarding e o que veio de uso real
// ============================================================================

class LiveUserProfileSignals {
  const LiveUserProfileSignals({
    required this.onboardingTags,
    required this.dynamicTags,
    required this.priorityAreas,
  });

  final Set<String> onboardingTags;
  final Set<String> dynamicTags;
  final Set<String> priorityAreas;

  Set<String> get allTags => {...onboardingTags, ...dynamicTags};
}
