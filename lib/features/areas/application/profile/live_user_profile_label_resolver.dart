// ============================================================================
// FILE: lib/features/areas/application/profile/live_user_profile_label_resolver.dart
//
// O que faz:
// - Resolve o nome final do perfil vivo a partir das tags
// - Mantém a nomenclatura centralizada em um único lugar
// - Facilita trocar os nomes depois sem quebrar a lógica do engine
// ============================================================================

class LiveUserProfileResolvedLabel {
  const LiveUserProfileResolvedLabel({
    required this.id,
    required this.label,
    required this.reason,
  });

  final String id;
  final String label;
  final String reason;
}

class LiveUserProfileLabelResolver {
  const LiveUserProfileLabelResolver();

  LiveUserProfileResolvedLabel resolve(Set<String> tags) {
    if (tags.contains('stress_high') && tags.contains('financial_pressure')) {
      return const LiveUserProfileResolvedLabel(
        id: 'perfil_pressao_total',
        label: 'Sob pressão',
        reason: 'O app identificou pressão mental e financeira recentes.',
      );
    }

    if (tags.contains('growth_focus') && tags.contains('worker')) {
      return const LiveUserProfileResolvedLabel(
        id: 'perfil_execucao_crescimento',
        label: 'Em crescimento',
        reason: 'Seu uso atual mostra foco em progresso e execução.',
      );
    }

    if (tags.contains('home_overload') || tags.contains('with_children')) {
      return const LiveUserProfileResolvedLabel(
        id: 'perfil_rotina_puxada',
        label: 'Rotina puxada',
        reason: 'O app identificou uma rotina mais pesada e carregada.',
      );
    }

    if (tags.contains('support_low') || tags.contains('social_fragile')) {
      return const LiveUserProfileResolvedLabel(
        id: 'perfil_reconexao',
        label: 'Em reconexão',
        reason: 'O app percebeu sinais de apoio social mais frágil.',
      );
    }

    if (tags.contains('low_constancy') || tags.contains('chaotic')) {
      return const LiveUserProfileResolvedLabel(
        id: 'perfil_retomada',
        label: 'Retomando o eixo',
        reason: 'Seu momento atual pede retomada de base e constância.',
      );
    }

    return const LiveUserProfileResolvedLabel(
      id: 'perfil_em_adaptacao',
      label: 'Em adaptação',
      reason: 'Seu perfil continua se ajustando ao uso real do app.',
    );
  }
}
