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
// - Lê os registros recentes de peso, alimentação, treino, água e sono já
//   salvos pelo BodyCareService.
// - Mantém o gráfico principal dos hábitos em 0-100.
// - Mostra o peso em um bloco próprio, com linha contínua entre os registros
//   e barra de proximidade da meta.
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
    required this.referenceWeightLabel,
    required this.goalLabel,
  });

  final List<BodyCareWeekPoint> week;
  final List<MapEntry<DateTime, BodyCareEntry>> recent;
  final double? targetWeightKg;
  final double? latestWeightKg;
  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;
  final String referenceWeightLabel;
  final String goalLabel;

  static const Color _green = Color(0xFF88F089);
  static const Color _cyan = Color(0xFF78B5FF);
  static const Color _purple = Color(0xFF8E82FF);
  static const Color _orange = Color(0xFFF9C66B);
  static const Color _pink = Color(0xFFFF7BC2);
  static const Color _teal = Color(0xFF63E6D8);

  @override
  Widget build(BuildContext context) {
    final currentWeight = latestWeightKg ?? _latestWeightFromRecent();
    final idealWeight = _resolveIdealWeight();
    final targetDistance = currentWeight == null || idealWeight == null
        ? null
        : currentWeight - idealWeight;
    final chartDays = _chartDays(idealWeight: idealWeight);
    final focusedDays = week.where((point) => (point.score ?? 0) >= 3).length;
    final weightBounds = _weightBounds(chartDays, idealWeight);
    final waterAverage = _averageFromRecent((entry) => entry.water);
    final sleepAverage = _averageFromRecent((entry) => entry.sleep);
    final weightAverageScore = _averageWeightCloseness(chartDays, idealWeight);

    return _SectionShell(
      title: 'Evolução do corpo',
      subtitle:
          'Hábitos ficam em uma escala e o peso em outra. Assim o gráfico não mente nem achata sua linha.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressSummary(
            currentWeight: currentWeight,
            targetWeight: idealWeight,
            targetDistance: targetDistance,
            idealSourceLabel: _idealSourceLabel(idealWeight),
          ),
          const SizedBox(height: 14),
          _DailyClosenessCard(
            currentWeight: currentWeight,
            idealWeight: idealWeight,
            focusedDays: focusedDays,
            idealSourceLabel: _idealSourceLabel(idealWeight),
            referenceWeightLabel: referenceWeightLabel,
          ),
          const SizedBox(height: 14),
          _MetricLegendBoard(days: chartDays, idealWeight: idealWeight),
          const SizedBox(height: 14),
          _HabitsLineChart(days: chartDays),
          const SizedBox(height: 14),
          _WeightLineChart(
            days: chartDays,
            weightMin: weightBounds.$1,
            weightMax: weightBounds.$2,
            idealWeight: idealWeight,
            idealSourceLabel: _idealSourceLabel(idealWeight),
          ),
          const SizedBox(height: 14),
          _HabitImpactPanel(
            weeklyAverageFood: weeklyAverageFood,
            weeklyAverageTraining: weeklyAverageTraining,
            waterAverage: waterAverage,
            sleepAverage: sleepAverage,
            weightAverageScore: weightAverageScore,
          ),
          const SizedBox(height: 12),
          _HabitFocusPanel(
            weeklyAverageFood: weeklyAverageFood,
            weeklyAverageTraining: weeklyAverageTraining,
            waterAverage: waterAverage,
            sleepAverage: sleepAverage,
            weightAverageScore: weightAverageScore,
          ),
          const SizedBox(height: 12),
          _InsightBox(
            text: _buildInsight(
              currentWeight: currentWeight,
              idealWeight: idealWeight,
              targetDistance: targetDistance,
              chartDays: chartDays,
            ),
          ),
        ],
      ),
    );
  }

  double? _latestWeightFromRecent() {
    final entries = recent.where((item) => item.value.weightKg != null).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.isEmpty ? null : entries.last.value.weightKg;
  }

  double? _resolveIdealWeight() {
    if (targetWeightKg != null && targetWeightKg! > 0) {
      return targetWeightKg;
    }
    final parsedRange = _parseReferenceRange(referenceWeightLabel);
    if (parsedRange != null) {
      return (parsedRange.$1 + parsedRange.$2) / 2;
    }
    return null;
  }

  String _idealSourceLabel(double? idealWeight) {
    if (idealWeight == null) return 'Ideal indisponível';
    if (targetWeightKg != null && targetWeightKg! > 0) return 'Meta atual';
    return 'Faixa ideal pela referência';
  }

  (double, double)? _parseReferenceRange(String rawLabel) {
    final match = RegExp(
      r'(\d+[\.,]?\d*)\s*[–-]\s*(\d+[\.,]?\d*)',
    ).firstMatch(rawLabel);
    if (match == null) return null;
    final min = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    final max = double.tryParse(match.group(2)!.replaceAll(',', '.'));
    if (min == null || max == null || min <= 0 || max <= 0 || max < min) {
      return null;
    }
    return (min, max);
  }

  List<_MetricDay> _chartDays({required double? idealWeight}) {
    final sorted = [...recent]..sort((a, b) => a.key.compareTo(b.key));
    final usable = sorted.length <= 14
        ? sorted
        : sorted.sublist(sorted.length - 14);

    return usable.map((item) {
      final entry = item.value;
      return _MetricDay(
        date: item.key,
        water: _normalizeCare(entry.water),
        food: _normalizeCare(entry.food),
        training: _normalizeCare(entry.training),
        sleep: _normalizeCare(entry.sleep),
        weightKg: entry.weightKg,
        weightCloseness: _weightCloseness(entry.weightKg, idealWeight),
        idealWeightKg: idealWeight,
        rawWeight: entry.weightKg,
      );
    }).toList();
  }

  double? _normalizeCare(int? value) {
    if (value == null) return null;
    return (value.clamp(0, 4) / 4) * 100;
  }

  double? _weightCloseness(double? current, double? ideal) {
    if (current == null || ideal == null || ideal <= 0) return null;

    // Ajuste mais humano:
    // antes, qualquer distância maior que ~12% do ideal já virava 0%.
    // Isso fazia 110 kg vs 90 kg parecer "progresso zero", o que visualmente
    // ficava duro demais. Agora usamos uma faixa maior para a barra responder
    // melhor ao mundo real.
    final maxDistance = math.max(20.0, ideal * 0.30);
    final ratio = 1 - ((current - ideal).abs() / maxDistance);
    return ratio.clamp(0.0, 1.0) * 100;
  }

  double? _averageFromRecent(int? Function(BodyCareEntry entry) selector) {
    final values = recent
        .map((item) => selector(item.value))
        .whereType<int>()
        .map((v) => (v.clamp(0, 4) / 4) * 100)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _averageWeightCloseness(List<_MetricDay> days, double? idealWeight) {
    if (idealWeight == null) return null;
    final values = days
        .map((day) => _weightCloseness(day.weightKg, idealWeight))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  (double, double) _weightBounds(List<_MetricDay> days, double? idealWeight) {
    final values = <double>[
      ...days.map((d) => d.weightKg).whereType<double>(),
      if (idealWeight != null) idealWeight,
    ];
    if (values.isEmpty) return (0, 100);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final spread = math.max(4.0, (maxValue - minValue).abs());
    final padding = math.max(1.5, spread * 0.18);
    return (minValue - padding, maxValue + padding);
  }

  String _buildInsight({
    required double? currentWeight,
    required double? idealWeight,
    required double? targetDistance,
    required List<_MetricDay> chartDays,
  }) {
    if (chartDays.isEmpty) {
      return 'Registre alguns dias para o painel mostrar sua caminhada real até o objetivo.';
    }
    if (idealWeight == null) {
      return 'Defina um peso-alvo ou preencha a altura no perfil para liberar a linha ideal do gráfico.';
    }

    final latest = chartDays.last;
    double? previousWeight;
    for (final day in chartDays.reversed.skip(1)) {
      if (day.weightKg != null) {
        previousWeight = day.weightKg;
        break;
      }
    }

    final strongHabits = [
      latest.water,
      latest.food,
      latest.training,
      latest.sleep,
    ].whereType<double>().where((v) => v >= 70).length;

    if (currentWeight == null) {
      return 'Seu gráfico já mostra hábitos. Agora registre o peso com frequência para ligar rotina e resultado.';
    }
    if (targetDistance != null && targetDistance.abs() <= 0.6) {
      return 'Você está muito perto da meta ideal. O foco agora é sustentar água, comida, treino e sono no verde.';
    }
    if (previousWeight != null) {
      final improving =
          (currentWeight > idealWeight && currentWeight < previousWeight) ||
          (currentWeight < idealWeight && currentWeight > previousWeight);
      if (improving) {
        if (strongHabits >= 3) {
          return 'O peso ficou mais perto do ideal e os hábitos acompanharam bem. Continue nesse ritmo.';
        }
        return 'O peso melhorou, mas ainda dá para blindar mais o resultado com água, comida, treino e sono mais estáveis.';
      }
    }
    if (strongHabits >= 3) {
      return 'Você ainda pode não ter chegado na meta, mas o corpo já está recebendo os sinais certos.';
    }
    return 'Hoje o painel mostra distância da linha ideal principalmente por constância. Priorize água, alimentação, treino e sono antes de cobrar pressa do peso.';
  }
}

class _MetricDay {
  const _MetricDay({
    required this.date,
    required this.water,
    required this.food,
    required this.training,
    required this.sleep,
    required this.weightKg,
    required this.weightCloseness,
    required this.idealWeightKg,
    required this.rawWeight,
  });

  final DateTime date;
  final double? water;
  final double? food;
  final double? training;
  final double? sleep;
  final double? weightKg;
  final double? weightCloseness;
  final double? idealWeightKg;
  final double? rawWeight;
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({
    required this.currentWeight,
    required this.targetWeight,
    required this.targetDistance,
    required this.idealSourceLabel,
  });

  final double? currentWeight;
  final double? targetWeight;
  final double? targetDistance;
  final String idealSourceLabel;

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
            title: idealSourceLabel,
            value: _kg(targetWeight),
            accent: BodyProgressSection._green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallResultCard(
            title: 'Distância',
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

class _DailyClosenessCard extends StatelessWidget {
  const _DailyClosenessCard({
    required this.currentWeight,
    required this.idealWeight,
    required this.focusedDays,
    required this.idealSourceLabel,
    required this.referenceWeightLabel,
  });

  final double? currentWeight;
  final double? idealWeight;
  final int focusedDays;
  final String idealSourceLabel;
  final String referenceWeightLabel;

  @override
  Widget build(BuildContext context) {
    final weightCloseness = _weightCloseness;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: BodyProgressSection._purple,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Leitura rápida da semana',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$focusedDays/7 dias fortes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: 'Peso vs ideal',
                value: _percentLabel(weightCloseness),
                tone: BodyProgressSection._cyan,
              ),
              _StatusChip(
                label: idealSourceLabel,
                value: idealWeight == null
                    ? 'pendente'
                    : '${idealWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg',
                tone: BodyProgressSection._green,
              ),
              _StatusChip(
                label: 'Faixa de ref.',
                value: referenceWeightLabel.isEmpty
                    ? '—'
                    : referenceWeightLabel,
                tone: BodyProgressSection._teal,
              ),
              _StatusChip(
                label: 'Peso atual',
                value: currentWeight == null
                    ? 'sem peso'
                    : '${currentWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg',
                tone: BodyProgressSection._orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double? get _weightCloseness {
    if (currentWeight == null || idealWeight == null || idealWeight! <= 0) {
      return null;
    }
    final maxDistance = math.max(6.0, idealWeight! * 0.12);
    final ratio = 1 - ((currentWeight! - idealWeight!).abs() / maxDistance);
    return ratio.clamp(0.0, 1.0) * 100;
  }

  static String _percentLabel(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(0)}%';
  }
}

class _MetricLegendBoard extends StatelessWidget {
  const _MetricLegendBoard({required this.days, required this.idealWeight});

  final List<_MetricDay> days;
  final double? idealWeight;

  @override
  Widget build(BuildContext context) {
    String latestValue(double? value, {String suffix = '%'}) {
      if (value == null) return '—';
      return '${value.toStringAsFixed(0)}$suffix';
    }

    final last = days.isEmpty ? null : days.last;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ChartInfoPill(
                title: 'Água',
                body: latestValue(last?.water),
                accent: BodyProgressSection._cyan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChartInfoPill(
                title: 'Comida',
                body: latestValue(last?.food),
                accent: BodyProgressSection._green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChartInfoPill(
                title: 'Treino',
                body: latestValue(last?.training),
                accent: BodyProgressSection._purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChartInfoPill(
                title: 'Sono',
                body: latestValue(last?.sleep),
                accent: BodyProgressSection._teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChartInfoPill(
                title: 'Peso',
                body: last?.rawWeight == null
                    ? '—'
                    : '${last!.rawWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg',
                accent: BodyProgressSection._orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChartInfoPill(
                title: 'Ideal',
                body: idealWeight == null
                    ? '—'
                    : '${idealWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg',
                accent: BodyProgressSection._pink,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HabitsLineChart extends StatelessWidget {
  const _HabitsLineChart({required this.days});

  final List<_MetricDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.length < 2) {
      return const _EmptyChartHint(
        text:
            'Registre pelo menos 2 dias com água, comida, treino ou sono para enxergar o padrão dos hábitos.',
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Linha de hábitos',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Aqui ficam só os hábitos do dia em escala de 0 a 100.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: const [
              _LegendDot(color: BodyProgressSection._cyan, text: 'água'),
              _LegendDot(color: BodyProgressSection._green, text: 'comida'),
              _LegendDot(color: BodyProgressSection._purple, text: 'treino'),
              _LegendDot(color: BodyProgressSection._teal, text: 'sono'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _HabitsProgressPainter(days: days),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 12, 12, 30),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days
                      .map(
                        (day) => Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(
                              '${day.date.day.toString().padLeft(2, '0')}/${day.date.month.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({
    required this.days,
    required this.weightMin,
    required this.weightMax,
    required this.idealWeight,
    required this.idealSourceLabel,
  });

  final List<_MetricDay> days;
  final double weightMin;
  final double weightMax;
  final double? idealWeight;
  final String idealSourceLabel;

  @override
  Widget build(BuildContext context) {
    final weightPoints = days.where((day) => day.weightKg != null).length;
    if (weightPoints == 0) {
      return const _EmptyChartHint(
        text:
            'Ainda não há peso registrado para montar o gráfico em kg. Salve o peso em mais de um dia para ver a evolução.',
      );
    }

    final latest = _latestWeight(days);
    final closeness = _weightCloseness(latest, idealWeight);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Peso em kg',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            weightPoints < 2
                ? 'Hoje você só tem 1 pesagem recente. O app mostra o ponto atual. Com mais dias salvos, a linha vai ficando mais viva.'
                : 'A linha do peso conecta os dias em que você realmente se pesou, sem fingir dados onde não houve registro.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: const [
              _LegendDot(color: BodyProgressSection._orange, text: 'peso'),
              _LegendDot(color: BodyProgressSection._pink, text: 'ideal'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _WeightProgressPainter(
                days: days,
                weightMin: weightMin,
                weightMax: weightMax,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(42, 12, 12, 30),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days
                      .map(
                        (day) => Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Text(
                              '${day.date.day.toString().padLeft(2, '0')}/${day.date.month.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChartInfoPill(
                  title: 'Último peso',
                  body: _latestWeightLabel(days),
                  accent: BodyProgressSection._orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChartInfoPill(
                  title: 'Meta / ideal',
                  body: idealWeight == null
                      ? '—'
                      : '${idealWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg',
                  accent: BodyProgressSection._pink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChartInfoPill(
                  title: 'TendÃªncia',
                  body: _weightTrendLabel(days, idealWeight),
                  accent: BodyProgressSection._green,
                ),
              ),
            ],
          ),
          if (idealWeight != null && latest != null) ...[
            const SizedBox(height: 12),
            _WeightGoalBar(
              latestWeight: latest,
              idealWeight: idealWeight!,
              closeness: closeness,
            ),
          ],
        ],
      ),
    );
  }

  static double? _latestWeight(List<_MetricDay> days) {
    final latest = days.lastWhere(
      (day) => day.rawWeight != null,
      orElse: () => days.last,
    );
    return latest.rawWeight;
  }

  static double? _weightCloseness(double? current, double? ideal) {
    if (current == null || ideal == null || ideal <= 0) return null;

    // Mesma lógica da leitura principal, para não existir discrepância entre
    // barra, card e painel.
    final maxDistance = math.max(20.0, ideal * 0.30);
    final ratio = 1 - ((current - ideal).abs() / maxDistance);
    return ratio.clamp(0.0, 1.0) * 100;
  }

  static String _latestWeightLabel(List<_MetricDay> days) {
    final latest = days.lastWhere(
      (day) => day.rawWeight != null,
      orElse: () => days.last,
    );
    if (latest.rawWeight == null) return '—';
    return '${latest.rawWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg';
  }

  static String _weightGraphHint(List<_MetricDay> days) {
    final latestWithWeight = days.lastWhere(
      (day) => day.rawWeight != null,
      orElse: () => days.last,
    );
    if (latestWithWeight.rawWeight == null) return 'Sem peso';
    final ideal = latestWithWeight.idealWeightKg;
    if (ideal == null) return 'sem ideal';
    final delta = latestWithWeight.rawWeight! - ideal;
    final direction = delta > 0 ? 'acima' : 'abaixo';
    return '${delta.abs().toStringAsFixed(1).replaceAll('.', ',')}kg $direction';
  }

  static String _weightTrendLabel(List<_MetricDay> days, double? idealWeight) {
    final weights = days.where((day) => day.rawWeight != null).toList();
    if (weights.length < 2) return _weightGraphHint(days);
    final first = weights.first.rawWeight!;
    final last = weights.last.rawWeight!;
    final delta = last - first;
    if (delta.abs() < 0.2) return 'estÃ¡vel';
    if (idealWeight == null) {
      return delta > 0 ? 'subiu' : 'baixou';
    }
    final firstDistance = (first - idealWeight).abs();
    final lastDistance = (last - idealWeight).abs();
    if (lastDistance < firstDistance) return 'aproximando';
    return 'afastando';
  }
}

class _WeightGoalBar extends StatelessWidget {
  const _WeightGoalBar({
    required this.latestWeight,
    required this.idealWeight,
    required this.closeness,
  });

  final double latestWeight;
  final double idealWeight;
  final double? closeness;

  @override
  Widget build(BuildContext context) {
    final distance = latestWeight - idealWeight;
    final direction = distance > 0 ? 'acima' : 'abaixo';
    final value = ((closeness ?? 0) / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Proximidade da meta',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                closeness == null ? '—' : '${closeness!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: BodyProgressSection._orange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(
                BodyProgressSection._orange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${distance.abs().toStringAsFixed(1).replaceAll('.', ',')}kg $direction do ideal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitsProgressPainter extends CustomPainter {
  const _HabitsProgressPainter({required this.days});
  final List<_MetricDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 6.0;
    const topPad = 8.0;
    const bottomPad = 30.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    for (final tick in [0, 25, 50, 75, 100]) {
      final y = topPad + chartHeight - (chartHeight * (tick / 100));
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '$tick', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - (tp.height / 2)));
    }

    final targetY = topPad + chartHeight - (chartHeight * 0.75);
    final targetPaint = Paint()
      ..color = BodyProgressSection._green.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    _drawDashedLine(
      canvas,
      Offset(leftPad, targetY),
      Offset(size.width, targetY),
      targetPaint,
    );
    final targetLabel = TextPainter(
      text: TextSpan(
        text: 'meta',
        style: labelStyle.copyWith(color: BodyProgressSection._green),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    targetLabel.paint(
      canvas,
      Offset(size.width - targetLabel.width - 4, targetY - 16),
    );

    _paintSeries(
      canvas: canvas,
      color: BodyProgressSection._cyan,
      points: _pointsForPercent(
        (day) => day.water,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      color: BodyProgressSection._green,
      points: _pointsForPercent(
        (day) => day.food,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      color: BodyProgressSection._purple,
      points: _pointsForPercent(
        (day) => day.training,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      color: BodyProgressSection._teal,
      points: _pointsForPercent(
        (day) => day.sleep,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 7.0;
    const dashGap = 5.0;
    var currentX = start.dx;
    while (currentX < end.dx) {
      final nextX = math.min(currentX + dashWidth, end.dx);
      canvas.drawLine(Offset(currentX, start.dy), Offset(nextX, end.dy), paint);
      currentX = nextX + dashGap;
    }
  }

  List<Offset?> _pointsForPercent(
    double? Function(_MetricDay day) selector,
    double chartWidth,
    double chartHeight,
    double leftPad,
    double topPad,
  ) {
    if (days.length == 1) {
      final value = selector(days.first);
      return [
        value == null
            ? null
            : Offset(
                leftPad + (chartWidth / 2),
                topPad + chartHeight - (chartHeight * (value / 100)),
              ),
      ];
    }
    final stepX = chartWidth / (days.length - 1);
    return List<Offset?>.generate(days.length, (index) {
      final value = selector(days[index]);
      if (value == null) return null;
      final x = leftPad + (stepX * index);
      final y = topPad + chartHeight - (chartHeight * (value / 100));
      return Offset(x, y);
    });
  }

  void _paintSeries({
    required Canvas canvas,
    required Color color,
    required List<Offset?> points,
  }) {
    final path = Path();
    Offset? previous;
    for (final point in points) {
      if (point == null) {
        previous = null;
        continue;
      }
      if (previous == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      previous = point;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    for (final point in points.whereType<Offset>()) {
      canvas.drawCircle(point, 3.4, Paint()..color = color);
      canvas.drawCircle(point, 1.4, Paint()..color = const Color(0xFF071112));
    }
  }

  @override
  bool shouldRepaint(covariant _HabitsProgressPainter oldDelegate) =>
      oldDelegate.days != days;
}

class _WeightProgressPainter extends CustomPainter {
  const _WeightProgressPainter({
    required this.days,
    required this.weightMin,
    required this.weightMax,
  });

  final List<_MetricDay> days;
  final double weightMin;
  final double weightMax;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 10.0;
    const topPad = 8.0;
    const bottomPad = 30.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad;
    final range = weightMax - weightMin;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    for (final factor in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = topPad + chartHeight - (chartHeight * factor);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final value = weightMin + (range * factor);
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(1).replaceAll('.', ','),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - (tp.height / 2)));
    }

    _paintSeries(
      canvas: canvas,
      color: BodyProgressSection._orange,
      points: _pointsForWeight(
        (day) => day.weightKg,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
      connectGaps: true,
    );
    _paintSeries(
      canvas: canvas,
      color: BodyProgressSection._pink,
      points: _pointsForWeight(
        (day) => day.idealWeightKg,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
      dashed: true,
      showDots: false,
      connectGaps: true,
    );
  }

  List<Offset?> _pointsForWeight(
    double? Function(_MetricDay day) selector,
    double chartWidth,
    double chartHeight,
    double leftPad,
    double topPad,
  ) {
    final range = weightMax - weightMin;
    if (range <= 0) return List<Offset?>.filled(days.length, null);
    if (days.length == 1) {
      final value = selector(days.first);
      return [
        value == null
            ? null
            : Offset(
                leftPad + (chartWidth / 2),
                topPad +
                    chartHeight -
                    (chartHeight * ((value - weightMin) / range)),
              ),
      ];
    }
    final stepX = chartWidth / (days.length - 1);
    return List<Offset?>.generate(days.length, (index) {
      final value = selector(days[index]);
      if (value == null) return null;
      final normalized = ((value - weightMin) / range).clamp(0.0, 1.0);
      final x = leftPad + (stepX * index);
      final y = topPad + chartHeight - (chartHeight * normalized);
      return Offset(x, y);
    });
  }

  void _paintSeries({
    required Canvas canvas,
    required Color color,
    required List<Offset?> points,
    bool dashed = false,
    bool showDots = true,
    bool connectGaps = false,
  }) {
    final path = Path();
    Offset? previous;
    for (final point in points) {
      if (point == null) {
        if (!connectGaps) previous = null;
        continue;
      }
      if (previous == null) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      previous = point;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 2 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (dashed) {
      for (final metric in path.computeMetrics()) {
        var distance = 0.0;
        const dash = 7.0;
        const gap = 4.0;
        while (distance < metric.length) {
          final segment = metric.extractPath(
            distance,
            math.min(distance + dash, metric.length),
          );
          canvas.drawPath(segment, paint);
          distance += dash + gap;
        }
      }
    } else {
      canvas.drawPath(path, paint);
    }

    if (!showDots) return;
    for (final point in points.whereType<Offset>()) {
      canvas.drawCircle(point, 3.8, Paint()..color = color);
      canvas.drawCircle(point, 1.5, Paint()..color = const Color(0xFF071112));
    }
  }

  @override
  bool shouldRepaint(covariant _WeightProgressPainter oldDelegate) =>
      oldDelegate.days != days ||
      oldDelegate.weightMin != weightMin ||
      oldDelegate.weightMax != weightMax;
}

class _HabitImpactPanel extends StatelessWidget {
  const _HabitImpactPanel({
    required this.weeklyAverageFood,
    required this.weeklyAverageTraining,
    required this.waterAverage,
    required this.sleepAverage,
    required this.weightAverageScore,
  });

  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;
  final double? waterAverage;
  final double? sleepAverage;
  final double? weightAverageScore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ImpactBar(
          title: 'Água',
          value: waterAverage,
          accent: BodyProgressSection._cyan,
          detail: _waterText(waterAverage),
        ),
        const SizedBox(height: 10),
        _ImpactBar(
          title: 'Alimentação',
          value: _scoreToPercent(weeklyAverageFood),
          accent: BodyProgressSection._green,
          detail: _foodText(weeklyAverageFood),
        ),
        const SizedBox(height: 10),
        _ImpactBar(
          title: 'Treino',
          value: _scoreToPercent(weeklyAverageTraining),
          accent: BodyProgressSection._purple,
          detail: _trainingText(weeklyAverageTraining),
        ),
        const SizedBox(height: 10),
        _ImpactBar(
          title: 'Sono',
          value: sleepAverage,
          accent: BodyProgressSection._teal,
          detail: _sleepText(sleepAverage),
        ),
        const SizedBox(height: 10),
        _ImpactBar(
          title: 'Peso perto do ideal',
          value: weightAverageScore,
          accent: BodyProgressSection._orange,
          detail: _weightText(weightAverageScore),
        ),
      ],
    );
  }

  static double? _scoreToPercent(double? value) {
    if (value == null) return null;
    return ((value.clamp(0.0, 4.0)) / 4) * 100;
  }

  String _waterText(double? value) {
    if (value == null) {
      return 'Sem dados suficientes de água nos registros recentes.';
    }
    if (value >= 78) {
      return 'Hidratação forte, ajudando recuperação e desempenho.';
    }
    if (value >= 58) {
      return 'Água razoável, mas ainda tem espaço para estabilizar.';
    }
    return 'Pouca água registrada; isso costuma bagunçar energia e treino.';
  }

  String _foodText(double? value) {
    if (value == null) {
      return 'Sem dados suficientes de alimentação nesta semana.';
    }
    if (value >= 3.2) return 'Boa base alimentar para acelerar resultado.';
    if (value >= 2.2) {
      return 'Alimentação mediana: dá para melhorar constância.';
    }
    return 'Alimentação baixa: pode estar travando evolução.';
  }

  String _trainingText(double? value) {
    if (value == null) return 'Sem dados suficientes de treino nesta semana.';
    if (value >= 3.2) return 'Treino forte ajudando o corpo a responder.';
    if (value >= 2.2) return 'Treino moderado: manter ritmo já ajuda.';
    return 'Pouco treino: movimento pode destravar progresso.';
  }

  String _sleepText(double? value) {
    if (value == null) return 'Sem dados suficientes de sono nesta semana.';
    if (value >= 78) {
      return 'Sono forte, ajudando recuperação e controle do dia.';
    }
    if (value >= 58) return 'Sono razoável, mas ainda pode melhorar.';
    return 'Sono fraco: isso costuma atrapalhar fome, foco e treino.';
  }

  String _weightText(double? value) {
    if (value == null) {
      return 'Sem peso suficiente para medir proximidade do ideal.';
    }
    if (value >= 80) return 'Peso muito perto da zona ideal calculada.';
    if (value >= 60) {
      return 'Peso caminhando para a zona ideal, mas ainda com folga.';
    }
    return 'Peso ainda distante da zona ideal; hábitos consistentes fazem diferença aqui.';
  }
}

class _HabitFocusPanel extends StatelessWidget {
  const _HabitFocusPanel({
    required this.weeklyAverageFood,
    required this.weeklyAverageTraining,
    required this.waterAverage,
    required this.sleepAverage,
    required this.weightAverageScore,
  });

  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;
  final double? waterAverage;
  final double? sleepAverage;
  final double? weightAverageScore;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _FocusMetric('Água', waterAverage, BodyProgressSection._cyan),
      _FocusMetric(
        'Alimentação',
        _scoreToPercent(weeklyAverageFood),
        BodyProgressSection._green,
      ),
      _FocusMetric(
        'Treino',
        _scoreToPercent(weeklyAverageTraining),
        BodyProgressSection._purple,
      ),
      _FocusMetric('Sono', sleepAverage, BodyProgressSection._teal),
      _FocusMetric('Peso', weightAverageScore, BodyProgressSection._orange),
    ].where((item) => item.value != null).toList();

    if (metrics.isEmpty) {
      return const _InsightBox(
        text:
            'Prioridade da semana: registre pelo menos dois dias para o app apontar onde ajustar primeiro.',
      );
    }

    metrics.sort((a, b) => a.value!.compareTo(b.value!));
    final weakest = metrics.first;
    final strongest = metrics.last;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: weakest.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: weakest.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.track_changes_rounded, color: weakest.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prioridade da semana',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${weakest.name} estÃ¡ mais baixo agora. Seu ponto forte recente Ã© ${strongest.name.toLowerCase()}.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double? _scoreToPercent(double? value) {
    if (value == null) return null;
    return ((value.clamp(0.0, 4.0)) / 4) * 100;
  }
}

class _FocusMetric {
  const _FocusMetric(this.name, this.value, this.color);

  final String name;
  final double? value;
  final Color color;
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
    final percent = ((value ?? 0) / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                value == null ? '—' : '${value!.toStringAsFixed(0)}%',
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
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
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

class _ChartInfoPill extends StatelessWidget {
  const _ChartInfoPill({
    required this.title,
    required this.body,
    required this.accent,
  });

  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
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
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
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
        color: const Color(0xFF08101E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
              color: Colors.white.withValues(alpha: 0.66),
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
        color: BodyProgressSection._green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: BodyProgressSection._green.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
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
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
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
            color: Colors.white.withValues(alpha: 0.66),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
