// ============================================================================
// FILE: lib/features/body_care/presentation/pages/body_care_page.dart
//
// O que faz:
// - Abre o módulo corporal do app
// - Permite registrar alimentação, treino, água e sono por dia
// - Mostra status do dia e visão curta da semana
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/body_care/body_care_service.dart';

class BodyCarePage extends StatefulWidget {
  const BodyCarePage({super.key});

  @override
  State<BodyCarePage> createState() => _BodyCarePageState();
}

class _BodyCarePageState extends State<BodyCarePage> {
  final BodyCareService _service = BodyCareService();
  DateTime _day = DateTime.now().subtract(const Duration(days: 1));
  BodyCareDayRecord? _record;
  List<BodyCareWeekPoint> _week = const [];
  int _streak = 0;
  bool _loading = true;
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final record = await _service.loadDay(_day);
    final week = await _service.last7Days(_day);
    final streak = await _service.dedicatedStreak(_day);
    if (!mounted) return;
    _weightCtrl.text = record.weightKg?.toStringAsFixed(1) ?? '';
    _noteCtrl.text = record.note ?? '';
    setState(() {
      _record = record;
      _week = week;
      _streak = streak;
      _loading = false;
    });
  }

  Future<void> _saveFood(int value) async {
    await _service.saveFood(_day, value);
    await _load();
  }

  Future<void> _saveTraining(int value) async {
    await _service.saveTraining(_day, value);
    await _load();
  }

  Future<void> _saveWater(int value) async {
    await _service.saveWater(_day, value);
    await _load();
  }

  Future<void> _saveSleep(int value) async {
    await _service.saveSleep(_day, value);
    await _load();
  }

  Future<void> _saveWeight() async {
    final raw = _weightCtrl.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    await _service.saveWeight(_day, value);
    await _load();
  }

  Future<void> _saveNote() async {
    await _service.saveNote(_day, _noteCtrl.text);
    await _load();
  }

  Future<void> _setDay(DateTime day) async {
    setState(() {
      _day = DateTime(day.year, day.month, day.day);
      _loading = true;
    });
    await _load();
  }

  String _dateLabel() {
    const months = [
      '',
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    return '${_day.day.toString().padLeft(2, '0')} de ${months[_day.month]}';
  }

  Color _scoreColor(double? score) {
    if (score == null) return const Color(0xFF94A3B8);
    if (score >= 3.6) return const Color(0xFF22C55E);
    if (score >= 2.6) return const Color(0xFFF59E0B);
    if (score >= 1.6) return const Color(0xFFFB923C);
    if (score >= 0.6) return const Color(0xFFEF4444);
    return const Color(0xFFB91C1C);
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final score = record?.average;
    final accent = _scoreColor(score);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Botar o shape'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.28),
                        const Color(0xFF0F1324),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: accent.withValues(alpha: 0.32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TopPill(
                            icon: Icons.fitness_center_rounded,
                            text: 'Corpo em foco',
                            color: accent,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () =>
                                _setDay(_day.subtract(const Duration(days: 1))),
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _dateLabel(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          IconButton(
                            onPressed: _day.isBefore(DateTime.now())
                                ? () =>
                                      _setDay(_day.add(const Duration(days: 1)))
                                : null,
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: _day.isBefore(DateTime.now())
                                  ? Colors.white70
                                  : Colors.white24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        record?.statusLabel ?? 'Sem registro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Registre como foi seu cuidado corporal nesse dia. Aqui fica sua linha de consistência real.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryMiniCard(
                              title: 'Score do dia',
                              value: score == null
                                  ? '--'
                                  : score.toStringAsFixed(1),
                              accent: accent,
                              icon: Icons.insights_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryMiniCard(
                              title: 'Sequência',
                              value: '$_streak',
                              accent: const Color(0xFF48A7FF),
                              icon: Icons.local_fire_department_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _WeekStrip(points: _week, scoreColor: _scoreColor),
                const SizedBox(height: 16),
                _QuestionCard(
                  title: 'Comida',
                  subtitle: 'Você ficou na linha ou chutou o balde?',
                  icon: Icons.restaurant_rounded,
                  accent: const Color(0xFFFFC145),
                  selected: record?.food,
                  options: BodyCareService.foodOptions,
                  onSelect: _saveFood,
                ),
                const SizedBox(height: 14),
                _QuestionCard(
                  title: 'Treino & movimento',
                  subtitle: 'Seu corpo trabalhou ou ficou parado?',
                  icon: Icons.directions_run_rounded,
                  accent: const Color(0xFF00D68F),
                  selected: record?.training,
                  options: BodyCareService.trainingOptions,
                  onSelect: _saveTraining,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _QuickChoiceCard(
                        title: 'Água',
                        icon: Icons.water_drop_rounded,
                        accent: const Color(0xFF48A7FF),
                        selected: record?.water,
                        options: BodyCareService.waterOptions,
                        onSelect: _saveWater,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickChoiceCard(
                        title: 'Sono',
                        icon: Icons.hotel_rounded,
                        accent: const Color(0xFF8B7CFF),
                        selected: record?.sleep,
                        options: BodyCareService.sleepOptions,
                        onSelect: _saveSleep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Peso e observação',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Peso do dia (opcional)',
                          suffixText: 'kg',
                        ),
                        onSubmitted: (_) => _saveWeight(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Observação rápida',
                        ),
                        onSubmitted: (_) => _saveNote(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saveWeight,
                              icon: const Icon(Icons.monitor_weight_rounded),
                              label: const Text('Salvar peso'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveNote,
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Salvar nota'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.points, required this.scoreColor});

  final List<BodyCareWeekPoint> points;
  final Color Function(double?) scoreColor;

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'S';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'Q';
      case DateTime.thursday:
        return 'Q';
      case DateTime.friday:
        return 'S';
      case DateTime.saturday:
        return 'S';
      default:
        return 'D';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos 7 dias',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final point in points) ...[
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: scoreColor(
                            point.score,
                          ).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: scoreColor(
                              point.score,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          point.score == null
                              ? '--'
                              : point.score!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _weekdayShort(point.day.weekday),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (point != points.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final int? selected;
  final List<BodyCareAnswerOption> options;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), const Color(0xFF0D1223)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final option in options) ...[
            InkWell(
              onTap: () => onSelect(option.value),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected == option.value ? accent : Colors.white12,
                    width: selected == option.value ? 2 : 1,
                  ),
                  color: selected == option.value
                      ? accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (option != options.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _QuickChoiceCard extends StatelessWidget {
  const _QuickChoiceCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final int? selected;
  final List<BodyCareAnswerOption> options;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option.shortLabel),
                  selected: selected == option.value,
                  onSelected: (_) => onSelect(option.value),
                  selectedColor: accent.withValues(alpha: 0.28),
                  labelStyle: TextStyle(
                    color: selected == option.value
                        ? Colors.white
                        : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
