// ============================================================================
// FILE: lib/features/body_care/presentation/widgets/body_progress_widgets.dart
//
// Widgets de evolução visual da área Corpo & Saúde.
//
// Caminho no projeto:
// - lib/features/body_care/presentation/widgets/body_progress_widgets.dart
//
// Como se conecta com o app:
// - É usado por body_care_page.dart dentro de Meu Dia > Corpo & Saúde.
// - Lê os registros recentes de peso, alimentação e treino já salvos pelo
//   BodyCareService.
// - Mostra evolução até a meta sem mexer em banco de dados, cores base ou fluxo.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../body_care_service.dart';

class BodyProgressSection extends StatelessWidget {
  const BodyProgressSection({
    super.key,
    required this.week,
    required this.recent,
    required this.targetWeightKg,
    required this.latestWeightKg,
    required this.weeklyAverageFood,
    required this.weeklyAverageTraining,
  });

  final List<BodyCareWeekPoint> week;
  final List<MapEntry<DateTime, BodyCareEntry>> recent;
  final double? targetWeightKg;
  final double? latestWeightKg;
  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;

  static const Color _green = Color(0xFF9CFF3F);
  static const Color _cyan = Color(0xFF39D0FF);
  static const Color _purple = Color(0xFF7D5CFF);
  static const Color _orange = Color(0xFFFFB020);

  @override
  Widget build(BuildContext context) {
    final weightEntries = _weightEntries();
    final startWeight = weightEntries.isEmpty
        ? null
        : weightEntries.first.value.weightKg;
    final currentWeight =
        latestWeightKg ??
        (weightEntries.isEmpty ? null : weightEntries.last.value.weightKg);
    final weightDelta = startWeight == null || currentWeight == null
        ? null
        : currentWeight - startWeight;
    final targetDistance = currentWeight == null || targetWeightKg == null
        ? null
        : currentWeight - targetWeightKg!;

    return _SectionShell(
      title: 'Evolução do corpo',
      subtitle: 'Peso, meta, alimentação e treino na mesma leitura.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressSummary(
            currentWeight: currentWeight,
            targetWeight: targetWeightKg,
            weightDelta: weightDelta,
            targetDistance: targetDistance,
          ),
          const SizedBox(height: 14),
          _WeightTrendChart(
            entries: weightEntries,
            targetWeight: targetWeightKg,
          ),
          const SizedBox(height: 14),
          _HabitImpactPanel(
            weeklyAverageFood: weeklyAverageFood,
            weeklyAverageTraining: weeklyAverageTraining,
            focusedDays: week.where((point) => (point.score ?? 0) >= 3).length,
          ),
          const SizedBox(height: 12),
          _InsightBox(text: _buildInsight(weightDelta, targetDistance)),
        ],
      ),
    );
  }

  List<MapEntry<DateTime, BodyCareEntry>> _weightEntries() {
    final entries = recent.where((item) => item.value.weightKg != null).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries.length <= 14
        ? entries
        : entries.sublist(entries.length - 14);
  }

  String _buildInsight(double? weightDelta, double? targetDistance) {
    if (latestWeightKg == null) {
      return 'Registre o peso diariamente para o app mostrar sua evolução real até a meta.';
    }

    if (targetWeightKg == null) {
      return 'Defina um peso alvo no perfil corporal para o gráfico mostrar a distância até a meta.';
    }

    if (targetDistance == null) {
      return 'Continue registrando peso, comida e treino para criar uma leitura mais clara.';
    }

    final distance = targetDistance
        .abs()
        .toStringAsFixed(1)
        .replaceAll('.', ',');

    if (targetDistance.abs() <= 0.4) {
      return 'Você está praticamente na meta. Agora o foco é manter consistência.';
    }

    if (weightDelta == null) {
      return 'Você está a $distance kg da meta. Registre mais dias para ver se está aproximando.';
    }

    final movingTowardGoal =
        (latestWeightKg! > targetWeightKg! && weightDelta < 0) ||
        (latestWeightKg! < targetWeightKg! && weightDelta > 0);

    if (movingTowardGoal) {
      return 'Boa evolução: o peso está andando na direção da meta. Alimentação e treino ajudam a manter esse ritmo.';
    }

    return 'O peso ainda não está indo para a meta. Revise alimentação, treino e constância desta semana.';
  }
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.currentWeight,
    required this.targetWeight,
    required this.weightDelta,
    required this.targetDistance,
  });

  final double? currentWeight;
  final double? targetWeight;
  final double? weightDelta;
  final double? targetDistance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmallResultCard(
            title: 'Peso atual',
            value: _kg(currentWeight),
            accent: BodyProgressSection._cyan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallResultCard(
            title: 'Meta',
            value: _kg(targetWeight),
            accent: BodyProgressSection._green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallResultCard(
            title: 'Até a meta',
            value: targetDistance == null
                ? '—'
                : '${targetDistance!.abs().toStringAsFixed(1).replaceAll('.', ',')}kg',
            accent: BodyProgressSection._orange,
          ),
        ),
      ],
    );
  }

  static String _kg(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(1).replaceAll('.', ',')}kg';
  }
}

class _WeightTrendChart extends StatelessWidget {
  const _WeightTrendChart({required this.entries, required this.targetWeight});

  final List<MapEntry<DateTime, BodyCareEntry>> entries;
  final double? targetWeight;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return _EmptyChartHint(
        text:
            'Registre peso em pelo menos 2 dias para ver o gráfico de evolução.',
      );
    }

    final weights = entries.map((item) => item.value.weightKg!).toList();
    final values = targetWeight == null ? weights : [...weights, targetWeight!];
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(0.1, maxValue - minValue);

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LegendDot(color: BodyProgressSection._cyan, text: 'peso'),
              SizedBox(width: 12),
              _LegendDot(color: BodyProgressSection._green, text: 'meta'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((item) {
                final weight = item.value.weightKg!;
                final percent = ((weight - minValue) / range).clamp(0.0, 1.0);
                final targetPercent = targetWeight == null
                    ? null
                    : ((targetWeight! - minValue) / range).clamp(0.0, 1.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _WeightDayColumn(
                      day: item.key,
                      weight: weight,
                      percent: percent,
                      targetPercent: targetPercent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightDayColumn extends StatelessWidget {
  const _WeightDayColumn({
    required this.day,
    required this.weight,
    required this.percent,
    required this.targetPercent,
  });

  final DateTime day;
  final double weight;
  final double percent;
  final double? targetPercent;

  @override
  Widget build(BuildContext context) {
    final barHeight = 34 + (percent * 76);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          weight.toStringAsFixed(1).replaceAll('.', ','),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 116,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (targetPercent != null)
                Positioned(
                  bottom: 34 + (targetPercent! * 76),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: BodyProgressSection._green.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      BodyProgressSection._purple.withOpacity(0.45),
                      BodyProgressSection._cyan.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day.day.toString().padLeft(2, '0'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HabitImpactPanel extends StatelessWidget {
  const _HabitImpactPanel({
    required this.weeklyAverageFood,
    required this.weeklyAverageTraining,
    required this.focusedDays,
  });

  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;
  final int focusedDays;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ImpactBar(
          title: 'Alimentação',
          value: weeklyAverageFood,
          accent: BodyProgressSection._green,
          detail: _foodText(weeklyAverageFood),
        ),
        const SizedBox(height: 10),
        _ImpactBar(
          title: 'Treino',
          value: weeklyAverageTraining,
          accent: BodyProgressSection._purple,
          detail: _trainingText(weeklyAverageTraining),
        ),
        const SizedBox(height: 10),
        _ImpactBar(
          title: 'Dias fortes',
          value: focusedDays / 7 * 4,
          accent: BodyProgressSection._cyan,
          detail: '$focusedDays de 7 dias com bom foco corporal.',
        ),
      ],
    );
  }

  String _foodText(double? value) {
    if (value == null)
      return 'Sem dados suficientes de alimentação nesta semana.';
    if (value >= 3.2) return 'Boa base alimentar para acelerar resultado.';
    if (value >= 2.2)
      return 'Alimentação mediana: dá para melhorar constância.';
    return 'Alimentação baixa: pode estar travando evolução.';
  }

  String _trainingText(double? value) {
    if (value == null) return 'Sem dados suficientes de treino nesta semana.';
    if (value >= 3.2) return 'Treino forte ajudando o corpo a responder.';
    if (value >= 2.2) return 'Treino moderado: manter ritmo já ajuda.';
    return 'Pouco treino: movimento pode destravar progresso.';
  }
}

class _ImpactBar extends StatelessWidget {
  const _ImpactBar({
    required this.title,
    required this.value,
    required this.accent,
    required this.detail,
  });

  final String title;
  final double? value;
  final Color accent;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final percent = ((value ?? 0) / 4).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                value == null ? '—' : value!.toStringAsFixed(1),
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallResultCard extends StatelessWidget {
  const _SmallResultCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF071112),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InsightBox extends StatelessWidget {
  const _InsightBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: BodyProgressSection._green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BodyProgressSection._green.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.78),
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

class _EmptyChartHint extends StatelessWidget {
  const _EmptyChartHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.68),
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.66),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
