import 'package:flutter/material.dart';

enum AreaStatus { excellent, good, attention, critical, noData }

extension AreaStatusUi on AreaStatus {
  String get label {
    switch (this) {
      case AreaStatus.excellent:
        return 'Ótimo';
      case AreaStatus.good:
        return 'Bom';
      case AreaStatus.attention:
        return 'Atenção';
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
      case AreaStatus.attention:
        return const Color(0xFFFB923C);
      case AreaStatus.critical:
        return const Color(0xFFEF4444);
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
      case AreaStatus.attention:
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
      case AreaStatus.attention:
        return 2;
      case AreaStatus.critical:
        return 3;
      case AreaStatus.noData:
        return 4;
    }
  }

  bool get needsAttention =>
      this == AreaStatus.attention || this == AreaStatus.critical;
}

extension AreaStatusLegacyCompat on AreaStatus {
  static AreaStatus fromLegacyName(String raw) {
    switch (raw.trim()) {
      case 'otimo':
      case 'excellent':
        return AreaStatus.excellent;
      case 'bom':
      case 'good':
        return AreaStatus.good;
      case 'ruim':
      case 'critical':
        return AreaStatus.critical;
      case 'attention':
        return AreaStatus.attention;
      case 'noData':
        return AreaStatus.noData;
      default:
        return AreaStatus.noData;
    }
  }

  String get storageName {
    switch (this) {
      case AreaStatus.excellent:
        return 'excellent';
      case AreaStatus.good:
        return 'good';
      case AreaStatus.attention:
        return 'attention';
      case AreaStatus.critical:
        return 'critical';
      case AreaStatus.noData:
        return 'noData';
    }
  }
}
