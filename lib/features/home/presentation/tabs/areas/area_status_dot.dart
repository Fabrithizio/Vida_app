import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_status.dart';

class AreaStatusDot extends StatelessWidget {
  const AreaStatusDot({super.key, required this.status, this.size = 14});

  final AreaStatus? status;
  final double size;

  Color _baseColor(BuildContext context) {
    if (status == null) return Theme.of(context).colorScheme.outlineVariant;
    return switch (status!) {
      AreaStatus.otimo => Colors.green,
      AreaStatus.bom => Colors.amber,
      AreaStatus.ruim => Colors.red,
    };
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
