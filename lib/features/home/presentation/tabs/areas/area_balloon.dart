// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/area_balloon.dart
//
// Card pequeno (sem texto) + ícone grande:
// - Sem nome
// - Caixa menor (compacta) com glass + shine lento (~9s)
// - Ícone NÃO diminui (fica dominante)
// ============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';

class AreaBalloon extends StatefulWidget {
  const AreaBalloon({
    super.key,
    required this.icon,
    required this.score,
    required this.onTap,
  });

  final IconData icon;
  final int? score;
  final VoidCallback onTap;

  @override
  State<AreaBalloon> createState() => _AreaBalloonState();
}

class _AreaBalloonState extends State<AreaBalloon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color _colorFromScore() {
    final s = widget.score;
    if (s == null) return Colors.white24;
    if (s >= 70) return Colors.green;
    if (s >= 40) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final ring = _colorFromScore();

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shineX = -1.2 + (_c.value * 2.4);

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F1A).withValues(alpha: 0.42),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),

                  // Shine sutil
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(shineX * 240, 0),
                      child: Transform.rotate(
                        angle: -0.65,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.04),
                                Colors.white.withValues(alpha: 0.10),
                                Colors.white.withValues(alpha: 0.04),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Ícone dominante
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F0F1A).withValues(alpha: 0.50),
                        border: Border.all(
                          color: ring.withValues(alpha: 0.62),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ring.withValues(alpha: 0.16),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 28, // ✅ ícone grande
                        color: ring == Colors.white24
                            ? Colors.white70
                            : ring.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
