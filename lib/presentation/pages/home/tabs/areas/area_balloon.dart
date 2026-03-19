// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/area_balloon.dart
//
// Orbe de área (icone grande + anel/glow por score):
// - Sem score numérico
// - Sem nome grande (no máximo tooltip futuro; por enquanto nenhum texto)
// ============================================================================

import 'package:flutter/material.dart';

class AreaBalloon extends StatelessWidget {
  const AreaBalloon({
    super.key,
    required this.icon,
    required this.score,
    required this.onTap,
  });

  final IconData icon;
  final int? score;
  final VoidCallback onTap;

  Color _colorFromScore() {
    final s = score;
    if (s == null) return Colors.white24;
    if (s >= 70) return Colors.green;
    if (s >= 40) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final c = _colorFromScore();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0F0F1A),
            border: Border.all(color: c.withValues(alpha: 0.75), width: 2),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.22),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: c, size: 30),
          ),
        ),
      ),
    );
  }
}