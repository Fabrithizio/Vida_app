import 'package:flutter/material.dart';

class BalloonConnectorPainter extends CustomPainter {
  BalloonConnectorPainter({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // linha levemente curva (ficará futurista)
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo((from.dx + to.dx) / 2, from.dy, to.dx, to.dy);

    canvas.drawPath(path, p);

    // pontinho no corpo
    final dotPaint = Paint()..color = color.withValues(alpha: 0.95);
    canvas.drawCircle(from, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant BalloonConnectorPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.color != color;
  }
}
