// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/area_balloon.dart
//
// Balão/Orbe estilo game:
// - Cor baseada em SCORE 0..100 (automático), não em "ótimo/bom/ruim"
// - Score aparece como badge
// - Se score for null, fica "neutro" (cinza)
// ============================================================================

import 'package:flutter/material.dart';

class AreaBalloon extends StatelessWidget {
  const AreaBalloon({
    super.key,
    required this.title,
    required this.onTap,
    required this.icon,
    required this.subtitle,
    required this.score,
  });

  final String title;
  final String subtitle;
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
    final scoreText = score?.clamp(0, 100).toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.withValues(alpha: 0.55), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.16),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withValues(alpha: 0.14),
                  border: Border.all(color: c.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: c, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (scoreText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    scoreText,
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
