// ============================================================================
// FILE: lib/features/home/presentation/tabs/profile_mutable_summary_formatter.dart
//
// O que faz:
// - Formata as respostas mutáveis do onboarding para exibição no ProfileTab
// - Evita a UI repetir lógica de limpeza/rotulagem
// ============================================================================

class ProfileMutableSummaryFormatter {
  const ProfileMutableSummaryFormatter();

  String formatLabel(String rawId) {
    final label = rawId
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
    return label.trim();
  }

  String formatValue(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '—' : text;
  }
}
