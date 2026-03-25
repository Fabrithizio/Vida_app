// O que esse arquivo faz:
// Mostra a bolinha de status usada nas listas e detalhes das áreas.

import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_status.dart';

class AreaStatusDot extends StatelessWidget {
  const AreaStatusDot({super.key, required this.status, this.size = 14});

  final AreaStatus? status;
  final double size;

  Color _baseColor(BuildContext context) {
    final s = status;
    if (s == null) {
      return Theme.of(context).colorScheme.outlineVariant;
    }

    switch (s) {
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

  @override
  Widget build(BuildContext context) {
    final c = _baseColor(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.95),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: c.withValues(alpha: 0.25),
            blurRadius: 28,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
}
