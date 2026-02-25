import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_status.dart';

class AreaBalloon extends StatelessWidget {
  const AreaBalloon({
    super.key,
    required this.title,
    required this.status,
    required this.subtitle,
    required this.onTap,
    this.maxWidth = 220,
  });

  final String title;
  final AreaStatus? status;
  final String subtitle;
  final VoidCallback onTap;
  final double maxWidth;

  Color _borderColor(BuildContext context) {
    if (status == null) return Theme.of(context).colorScheme.outlineVariant;
    return switch (status!) {
      AreaStatus.otimo => Colors.green,
      AreaStatus.bom => Colors.amber,
      AreaStatus.ruim => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    final border = _borderColor(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: border.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: border.withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _borderColor(context), // usa a cor do status
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _borderColor(context), // reaproveita a mesma cor
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
