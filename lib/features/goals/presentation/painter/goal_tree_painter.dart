// lib/features/goals/presentation/painter/goal_tree_painter.dart
import 'package:flutter/material.dart';
import '../../data/models/goal_tree_models.dart';

class GoalTreePainter extends CustomPainter {
  GoalTreePainter({
    required this.nodes,
    required this.statuses,
    required this.nodeRadius,
  });

  final List<GoalNodeModel> nodes;
  final Map<String, GoalNodeStatus> statuses;
  final double nodeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.1),
        radius: 1.1,
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
      ).createShader(Offset(size.width / 2, size.height / 2) & size);

    canvas.drawRect(Offset.zero & size, vignette);

    _paintEdges(canvas);
    _paintNodes(canvas);
  }

  void _paintEdges(Canvas canvas) {
    final byId = {for (final n in nodes) n.id: n};

    for (final node in nodes) {
      for (final parentId in node.parents) {
        final parent = byId[parentId];
        if (parent == null) continue;

        final parentStatus = statuses[parentId] ?? GoalNodeStatus.locked;
        final nodeStatus = statuses[node.id] ?? GoalNodeStatus.locked;

        final isActivePath =
            parentStatus == GoalNodeStatus.completed &&
            (nodeStatus == GoalNodeStatus.available ||
                nodeStatus == GoalNodeStatus.completed);

        final isCompletedPath =
            parentStatus == GoalNodeStatus.completed &&
            nodeStatus == GoalNodeStatus.completed;

        final p1 = parent.position;
        final p2 = node.position;

        final base = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.10);

        canvas.drawLine(p1, p2, base);

        if (isActivePath) {
          final glow = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round
            ..color = Colors.amber.withValues(alpha: 0.10);

          canvas.drawLine(p1, p2, glow);

          final active = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = Colors.amber.withValues(
              alpha: isCompletedPath ? 0.9 : 0.55,
            );

          canvas.drawLine(p1, p2, active);
        }
      }
    }
  }

  void _paintNodes(Canvas canvas) {
    for (final node in nodes) {
      final status = statuses[node.id] ?? GoalNodeStatus.locked;
      final c = node.position;

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      final fillPaint = Paint()..style = PaintingStyle.fill;

      switch (status) {
        case GoalNodeStatus.locked:
          fillPaint.color = Colors.white.withValues(alpha: 0.06);
          ringPaint.color = Colors.white.withValues(alpha: 0.10);
          break;
        case GoalNodeStatus.available:
          fillPaint.shader = RadialGradient(
            radius: 1.1,
            colors: [
              Colors.indigo.withValues(alpha: 0.85),
              Colors.indigo.withValues(alpha: 0.25),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: nodeRadius));
          ringPaint.color = Colors.indigoAccent.withValues(alpha: 0.95);
          break;
        case GoalNodeStatus.completed:
          fillPaint.shader = RadialGradient(
            radius: 1.1,
            colors: [
              Colors.amber.withValues(alpha: 0.95),
              Colors.deepOrange.withValues(alpha: 0.25),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: nodeRadius));
          ringPaint.color = Colors.amber.withValues(alpha: 0.98);
          break;
      }

      if (status != GoalNodeStatus.locked) {
        final glowColor = status == GoalNodeStatus.completed
            ? Colors.amber
            : Colors.indigoAccent;
        final glow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..color = glowColor.withValues(alpha: 0.12);

        canvas.drawCircle(c, nodeRadius + 8, glow);
      }

      canvas.drawCircle(c, nodeRadius, fillPaint);
      canvas.drawCircle(c, nodeRadius, ringPaint);

      final iconText = status == GoalNodeStatus.completed
          ? '✓'
          : status == GoalNodeStatus.available
          ? '★'
          : '•';

      final tp = TextPainter(
        text: TextSpan(
          text: iconText,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: status == GoalNodeStatus.locked
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(
                    alpha: status == GoalNodeStatus.completed ? 0.95 : 0.85,
                  ),
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.black.withValues(alpha: 0.45),
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));

      final label = TextPainter(
        text: TextSpan(
          text: node.title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(
              alpha: status == GoalNodeStatus.locked ? 0.22 : 0.70,
            ),
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);

      label.paint(canvas, c + Offset(-label.width / 2, nodeRadius + 10));
    }
  }

  @override
  bool shouldRepaint(covariant GoalTreePainter oldDelegate) {
    return oldDelegate.statuses != statuses ||
        oldDelegate.nodes != nodes ||
        oldDelegate.nodeRadius != nodeRadius;
  }
}
