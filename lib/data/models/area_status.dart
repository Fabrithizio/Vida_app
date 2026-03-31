// ============================================================================
// FILE: lib/data/models/area_status.dart
//
// O que faz:
// - Define os estados visuais e lógicos das subáreas e áreas
// - Fornece rótulo, cor, ícone, severidade e nome de storage
//
// Nesta versão:
// - remove compatibilidade legada
// - padroniza os 5 níveis reais do sistema novo:
//   crítico, ruim, médio, bom, ótimo
// - mantém a identidade visual geral do app
// ============================================================================

import 'package:flutter/material.dart';

enum AreaStatus { excellent, good, medium, poor, critical, noData }

extension AreaStatusUi on AreaStatus {
  String get label {
    switch (this) {
      case AreaStatus.excellent:
        return 'Ótimo';
      case AreaStatus.good:
        return 'Bom';
      case AreaStatus.medium:
        return 'Médio';
      case AreaStatus.poor:
        return 'Ruim';
      case AreaStatus.critical:
        return 'Crítico';
      case AreaStatus.noData:
        return 'Sem dados';
    }
  }

  Color get color {
    switch (this) {
      case AreaStatus.excellent:
        return const Color(0xFF22C55E);
      case AreaStatus.good:
        return const Color(0xFFF59E0B);
      case AreaStatus.medium:
        return const Color(0xFFFB923C);
      case AreaStatus.poor:
        return const Color(0xFFEF4444);
      case AreaStatus.critical:
        return const Color(0xFFB91C1C);
      case AreaStatus.noData:
        return const Color(0xFF94A3B8);
    }
  }

  IconData get icon {
    switch (this) {
      case AreaStatus.excellent:
        return Icons.check_circle_rounded;
      case AreaStatus.good:
        return Icons.thumb_up_alt_rounded;
      case AreaStatus.medium:
        return Icons.remove_circle_outline_rounded;
      case AreaStatus.poor:
        return Icons.error_outline_rounded;
      case AreaStatus.critical:
        return Icons.warning_amber_rounded;
      case AreaStatus.noData:
        return Icons.help_outline_rounded;
    }
  }

  int get severity {
    switch (this) {
      case AreaStatus.excellent:
        return 0;
      case AreaStatus.good:
        return 1;
      case AreaStatus.medium:
        return 2;
      case AreaStatus.poor:
        return 3;
      case AreaStatus.critical:
        return 4;
      case AreaStatus.noData:
        return 5;
    }
  }

  bool get needsAttention =>
      this == AreaStatus.medium ||
      this == AreaStatus.poor ||
      this == AreaStatus.critical;

  String get storageName {
    switch (this) {
      case AreaStatus.excellent:
        return 'excellent';
      case AreaStatus.good:
        return 'good';
      case AreaStatus.medium:
        return 'medium';
      case AreaStatus.poor:
        return 'poor';
      case AreaStatus.critical:
        return 'critical';
      case AreaStatus.noData:
        return 'noData';
    }
  }

  static AreaStatus fromStorageName(String raw) {
    switch (raw.trim()) {
      case 'excellent':
        return AreaStatus.excellent;
      case 'good':
        return AreaStatus.good;
      case 'medium':
        return AreaStatus.medium;
      case 'poor':
        return AreaStatus.poor;
      case 'critical':
        return AreaStatus.critical;
      case 'noData':
        return AreaStatus.noData;
      default:
        return AreaStatus.noData;
    }
  }
}
