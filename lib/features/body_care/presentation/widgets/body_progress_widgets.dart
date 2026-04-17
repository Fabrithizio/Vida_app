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
// - Lê os registros recentes de peso, alimentação, treino e água já salvos pelo
//   BodyCareService.
// - Mantém a identidade roxa do app e troca a leitura antiga por um gráfico de
//   linhas mais explicativo, com linha ideal adaptada à meta ou à faixa de
//   referência corporal calculada pelo app.
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

  static const Color _green = Color(0xFF9CFF3F);
  static const Color _cyan = Color(0xFF39D0FF);
  static const Color _purple = Color(0xFF7D5CFF);
  static const Color _orange = Color(0xFFFFB020);
  static const Color _pink = Color(0xFFFF74C8);

  @override
  Widget build(BuildContext context) {
    final currentWeight = latestWeightKg ?? _latestWeightFromRecent();
    final idealWeight = _resolveIdealWeight();
    final targetDistance = currentWeight == null || idealWeight == null
        ? null
        : currentWeight - idealWeight;
    final chartDays = _chartDays(idealWeight: idealWeight);
    final focusedDays = week.where((point) => (point.score ?? 0) >= 3).length;

    return _SectionShell(
      title: 'Evolução do corpo',
      subtitle:
          'Agora a leitura é contínua: água, comida, treino, peso e linha ideal no mesmo painel.',
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
          ),
          const SizedBox(height: 14),
          _MultiMetricLineChart(
            days: chartDays,
            idealSourceLabel: _idealSourceLabel(idealWeight),
          ),
          const SizedBox(height: 14),
          _HabitImpactPanel(
            weeklyAverageFood: weeklyAverageFood,
            weeklyAverageTraining: weeklyAverageTraining,
            waterAverage: _averageFromRecent((entry) => entry.water),
            weightAverageScore: _averageWeightScore(chartDays),
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
    return 'Faixa IMC de referência';
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
    final usable = sorted.length <= 10
        ? sorted
        : sorted.sublist(sorted.length - 10);

    return usable.map((item) {
      final entry = item.value;
      return _MetricDay(
        date: item.key,
        water: _normalizeCare(entry.water),
        food: _normalizeCare(entry.food),
        training: _normalizeCare(entry.training),
        weight: _weightScore(entry.weightKg, idealWeight),
        ideal: _idealScore(entry: entry, idealWeight: idealWeight),
        rawWeight: entry.weightKg,
      );
    }).toList();
  }

  double? _normalizeCare(int? value) {
    if (value == null) return null;
    return (value.clamp(0, 4) / 4) * 100;
  }

  double? _weightScore(double? current, double? ideal) {
    if (current == null || ideal == null || ideal <= 0) return null;
    final maxDistance = math.max(6.0, ideal * 0.12);
    final ratio = 1 - ((current - ideal).abs() / maxDistance);
    return ratio.clamp(0.0, 1.0) * 100;
  }

  double _idealScore({
    required BodyCareEntry entry,
    required double? idealWeight,
  }) {
    final goal = goalLabel.toLowerCase();
    var base = 74.0;

    if (goal.contains('emag')) {
      base = 76.0;
    } else if (goal.contains('massa')) {
      base = 72.0;
    } else if (goal.contains('defin')) {
      base = 78.0;
    } else if (goal.contains('manter')) {
      base = 73.0;
    }

    if (idealWeight == null) {
      return base - 4;
    }

    if (entry.weightKg == null) {
      return base;
    }

    final closeToIdeal = _weightScore(entry.weightKg, idealWeight) ?? 0;
    return ((base * 0.7) + (closeToIdeal * 0.3)).clamp(60.0, 88.0);
  }

  double? _averageFromRecent(int? Function(BodyCareEntry entry) selector) {
    final values = recent
        .map((item) => selector(item.value))
        .whereType<int>()
        .map((value) => (value.clamp(0, 4) / 4) * 100)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _averageWeightScore(List<_MetricDay> days) {
    final values = days.map((day) => day.weight).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _buildInsight({
    required double? currentWeight,
    required double? idealWeight,
    required double? targetDistance,
    required List<_MetricDay> chartDays,
  }) {
    if (chartDays.isEmpty) {
      return 'Registre seus dias para o painel mostrar sua caminhada real até o objetivo. O roxo continua firme; agora falta só matéria-prima.';
    }

    if (idealWeight == null) {
      return 'Defina um peso-alvo ou preencha a altura no perfil para liberar a linha ideal do gráfico.';
    }

    final latest = chartDays.last;
    double? previousWeightPoint;
    for (final day in chartDays.reversed.skip(1)) {
      if (day.weight != null) {
        previousWeightPoint = day.weight;
        break;
      }
    }

    final water = latest.water;
    final food = latest.food;
    final training = latest.training;
    final weight = latest.weight;

    final strongHabits = [
      water,
      food,
      training,
    ].whereType<double>().where((value) => value >= 70).length;

    if (currentWeight == null) {
      return 'Seu gráfico já mostra hábitos. Agora registre o peso com frequência para ligar rotina e resultado.';
    }

    if (targetDistance != null && targetDistance.abs() <= 0.6) {
      return 'Você está muito perto da meta ideal. O foco agora é sustentar água, comida e treino no verde para não devolver resultado.';
    }

    if (weight != null &&
        previousWeightPoint != null &&
        weight > previousWeightPoint) {
      if (strongHabits >= 2) {
        return 'O peso ficou mais perto do ideal e os hábitos acompanharam. Esse é o tipo de semana que convence até a balança a colaborar.';
      }
      return 'O peso melhorou, mas ainda dá para blindar mais o resultado com água, comida e treino mais estáveis.';
    }

    if (strongHabits >= 2) {
      return 'Você ainda pode não ter chegado na meta, mas o corpo já está recebendo os sinais certos. Continue empilhando dias bons.';
    }

    return 'Hoje o painel mostra distância da linha ideal principalmente por constância. Priorize água, alimentação e treino antes de cobrar pressa do peso.';
  }
}

class _MetricDay {
  const _MetricDay({
    required this.date,
    required this.water,
    required this.food,
    required this.training,
    required this.weight,
    required this.ideal,
    required this.rawWeight,
  });

  final DateTime date;
  final double? water;
  final double? food;
  final double? training;
  final double? weight;
  final double ideal;
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
  });

  final double? currentWeight;
  final double? idealWeight;
  final int focusedDays;
  final String idealSourceLabel;

  @override
  Widget build(BuildContext context) {
    final weightCloseness = _weightCloseness;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  color: Colors.white.withOpacity(0.72),
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

class _MultiMetricLineChart extends StatelessWidget {
  const _MultiMetricLineChart({
    required this.days,
    required this.idealSourceLabel,
  });

  final List<_MetricDay> days;
  final String idealSourceLabel;

  @override
  Widget build(BuildContext context) {
    if (days.length < 2) {
      return const _EmptyChartHint(
        text:
            'Registre pelo menos 2 dias com dados de água, comida, treino ou peso para enxergar a evolução contínua.',
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linha de cuidados x ideal',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Cada linha mostra o quanto o dia ficou perto do que ajuda seu objetivo. A linha ideal usa ${idealSourceLabel.toLowerCase()}.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
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
              _LegendDot(color: BodyProgressSection._cyan, text: 'água'),
              _LegendDot(color: BodyProgressSection._green, text: 'comida'),
              _LegendDot(color: BodyProgressSection._purple, text: 'treino'),
              _LegendDot(color: BodyProgressSection._orange, text: 'peso'),
              _LegendDot(color: BodyProgressSection._pink, text: 'ideal'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 230,
            child: CustomPaint(
              painter: _CareProgressPainter(days: days),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 12, 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: days.map((day) {
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (day.rawWeight != null)
                                Text(
                                  day.rawWeight!
                                      .toStringAsFixed(1)
                                      .replaceAll('.', ','),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.52),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              else
                                const SizedBox(height: 12),
                              const SizedBox(height: 132),
                              Text(
                                '${day.date.day.toString().padLeft(2, '0')}/${day.date.month.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.58),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ChartInfoPill(
                  title: 'Melhor dia',
                  body: _bestDayLabel(days),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChartInfoPill(
                  title: 'Peso no gráfico',
                  body: _weightGraphHint(days),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _bestDayLabel(List<_MetricDay> days) {
    double score(_MetricDay day) {
      final values = [
        day.water,
        day.food,
        day.training,
        day.weight,
      ].whereType<double>().toList();
      if (values.isEmpty) return 0;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final ranked = [...days]..sort((a, b) => score(b).compareTo(score(a)));
    final best = ranked.first;
    return '${best.date.day.toString().padLeft(2, '0')}/${best.date.month.toString().padLeft(2, '0')} com média ${score(best).toStringAsFixed(0)}%';
  }

  static String _weightGraphHint(List<_MetricDay> days) {
    final latest = days.lastWhere(
      (day) => day.rawWeight != null,
      orElse: () => days.last,
    );
    if (latest.rawWeight == null) return 'Sem peso recente no gráfico.';
    return 'Último peso: ${latest.rawWeight!.toStringAsFixed(1).replaceAll('.', ',')}kg';
  }
}

class _CareProgressPainter extends CustomPainter {
  const _CareProgressPainter({required this.days});

  final List<_MetricDay> days;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 4.0;
    const topPad = 6.0;
    const bottomPad = 28.0;
    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: Colors.white.withOpacity(0.55),
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

    _paintSeries(
      canvas: canvas,
      size: size,
      color: BodyProgressSection._cyan,
      points: _pointsFor(
        (day) => day.water,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      size: size,
      color: BodyProgressSection._green,
      points: _pointsFor(
        (day) => day.food,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      size: size,
      color: BodyProgressSection._purple,
      points: _pointsFor(
        (day) => day.training,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      size: size,
      color: BodyProgressSection._orange,
      points: _pointsFor(
        (day) => day.weight,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
    );
    _paintSeries(
      canvas: canvas,
      size: size,
      color: BodyProgressSection._pink,
      points: _pointsFor(
        (day) => day.ideal,
        chartWidth,
        chartHeight,
        leftPad,
        topPad,
      ),
      dashed: true,
      showDots: false,
    );
  }

  List<Offset?> _pointsFor(
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
    required Size size,
    required Color color,
    required List<Offset?> points,
    bool dashed = false,
    bool showDots = true,
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
      ..strokeWidth = dashed ? 2 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (dashed) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    if (!showDots) return;

    for (final point in points.whereType<Offset>()) {
      canvas.drawCircle(point, 3.4, Paint()..color = color);
      canvas.drawCircle(point, 1.4, Paint()..color = const Color(0xFF071112));
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
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
  }

  @override
  bool shouldRepaint(covariant _CareProgressPainter oldDelegate) {
    return oldDelegate.days != days;
  }
}

class _HabitImpactPanel extends StatelessWidget {
  const _HabitImpactPanel({
    required this.weeklyAverageFood,
    required this.weeklyAverageTraining,
    required this.waterAverage,
    required this.weightAverageScore,
  });

  final double? weeklyAverageFood;
  final double? weeklyAverageTraining;
  final double? waterAverage;
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
    if (value == null)
      return 'Sem dados suficientes de água nos registros recentes.';
    if (value >= 78)
      return 'Hidratação forte, ajudando recuperação e desempenho.';
    if (value >= 58)
      return 'Água razoável, mas ainda tem espaço para estabilizar.';
    return 'Pouca água registrada; isso costuma bagunçar energia e treino.';
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

  String _weightText(double? value) {
    if (value == null)
      return 'Sem peso suficiente para medir proximidade do ideal.';
    if (value >= 80) return 'Peso muito perto da zona ideal calculada.';
    if (value >= 60)
      return 'Peso caminhando para a zona ideal, mas ainda com folga.';
    return 'Peso ainda distante da zona ideal; hábitos consistentes fazem diferença aqui.';
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
    final percent = ((value ?? 0) / 100).clamp(0.0, 1.0);
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
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(accent),
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

class _ChartInfoPill extends StatelessWidget {
  const _ChartInfoPill({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
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
        color: tone.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
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
