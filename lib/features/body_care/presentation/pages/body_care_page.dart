// ============================================================================
// FILE: lib/features/body_care/presentation/pages/body_care_page.dart
//
// O que este arquivo faz:
// - Mostra o módulo "Corpo em dia" com cara mais de app fitness
// - Mantém o foco principal no registro do dia e na evolução
// - Traz IMC, referência corporal, meta, sequência e resumo semanal
// - Usa tema roxo em toda a área, sem perder os dados usados no Meu Dia
// ============================================================================

import 'package:flutter/material.dart';

import '../../body_care_service.dart';

class BodyCarePage extends StatefulWidget {
  const BodyCarePage({super.key});

  @override
  State<BodyCarePage> createState() => _BodyCarePageState();
}

class _BodyCarePageState extends State<BodyCarePage> {
  final BodyCareService _service = BodyCareService();

  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _targetWeightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _waistCtrl = TextEditingController();
  final TextEditingController _stepsCtrl = TextEditingController();
  final TextEditingController _minutesCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  DateTime _day = DateTime.now();
  BodyCareEntry _entry = const BodyCareEntry();
  BodyCareProfile _profile = const BodyCareProfile();
  BodyCareOverview _overview = BodyCareOverview.empty();
  List<BodyCareWeekPoint> _week = const [];
  List<MapEntry<DateTime, BodyCareEntry>> _recent = const [];
  String _goal = BodyCareService.goalOptions.first;
  bool _loading = true;
  bool _saving = false;

  static const Color _purple = Color(0xFFA855F7);
  static const Color _purple2 = Color(0xFF9333EA);
  static const Color _purple3 = Color(0xFF7E22CE);
  static const Color _purpleSoft = Color(0xFFC084FC);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    _stepsCtrl.dispose();
    _minutesCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final profile = await _service.loadProfile();
    final entry = await _service.loadDay(_day);
    final overview = await _service.loadOverview();
    final week = await _service.last7Days(_day);
    final recent = await _service.loadRecentEntries(days: 14);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _entry = entry;
      _overview = overview;
      _week = week;
      _recent = recent;
      _goal = profile.goal ?? BodyCareService.goalOptions.first;
      _heightCtrl.text = _fmt(profile.heightCm);
      _targetWeightCtrl.text = _fmt(profile.targetWeightKg);
      _weightCtrl.text = _fmt(entry.weightKg);
      _waistCtrl.text = _fmt(entry.waistCm);
      _stepsCtrl.text = entry.steps?.toString() ?? '';
      _minutesCtrl.text = entry.activeMinutes?.toString() ?? '';
      _noteCtrl.text = entry.note ?? '';
      _loading = false;
    });
  }

  String _fmt(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  double? _parseDouble(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  int? _parseInt(TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);

    final profile = BodyCareProfile(
      heightCm: _parseDouble(_heightCtrl),
      targetWeightKg: _parseDouble(_targetWeightCtrl),
      goal: _goal,
    );

    final entry = BodyCareEntry(
      food: _entry.food,
      training: _entry.training,
      water: _entry.water,
      sleep: _entry.sleep,
      steps: _parseInt(_stepsCtrl),
      activeMinutes: _parseInt(_minutesCtrl),
      weightKg: _parseDouble(_weightCtrl),
      waistCm: _parseDouble(_waistCtrl),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    await _service.saveProfile(profile);
    await _service.saveDay(_day, entry);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _entry = entry;
      _saving = false;
    });

    await _loadAll();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Corpo em dia atualizado.')));
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _loading = true;
    });
    await _loadAll();
  }

  void _setFood(int value) {
    setState(() => _entry = _entry.copyWith(food: value));
  }

  void _setTraining(int value) {
    setState(() => _entry = _entry.copyWith(training: value));
  }

  void _setWater(int value) {
    setState(() => _entry = _entry.copyWith(water: value));
  }

  void _setSleep(int value) {
    setState(() => _entry = _entry.copyWith(sleep: value));
  }

  String _dayLabel(DateTime d) {
    const week = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    const months = [
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
    return '${week[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
  }

  Color _scoreColor(double? score) {
    if (score == null) return Colors.white24;
    if (score >= 3.6) return const Color(0xFFC084FC);
    if (score >= 2.6) return const Color(0xFFA855F7);
    if (score >= 1.6) return const Color(0xFF9333EA);
    if (score >= 0.6) return const Color(0xFF7E22CE);
    return const Color(0xFF581C87);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Corpo em dia'),
        actions: [
          IconButton(
            tooltip: 'Escolher dia',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
              children: [
                _heroCard(),
                const SizedBox(height: 16),
                _metricsGrid(),
                const SizedBox(height: 16),
                _weekCard(),
                const SizedBox(height: 16),
                _sectionTitle(
                  'Foco do dia',
                  'Registre o que mais move seu resultado.',
                ),
                const SizedBox(height: 10),
                _questionCard(
                  title: 'Comida',
                  subtitle: 'Como você alimentou seu corpo nesse dia?',
                  icon: Icons.restaurant_rounded,
                  selected: _entry.food,
                  options: BodyCareService.foodOptions,
                  onSelect: _setFood,
                ),
                const SizedBox(height: 14),
                _questionCard(
                  title: 'Treino & movimento',
                  subtitle: 'Seu corpo trabalhou ou ficou parado?',
                  icon: Icons.fitness_center_rounded,
                  selected: _entry.training,
                  options: BodyCareService.trainingOptions,
                  onSelect: _setTraining,
                ),
                const SizedBox(height: 16),
                _sectionTitle(
                  'Base corporal',
                  'O básico bem feito costuma ser o que mais muda o jogo.',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _choiceCard(
                        title: 'Água',
                        selected: _entry.water,
                        options: BodyCareService.waterOptions,
                        onSelect: _setWater,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _choiceCard(
                        title: 'Sono',
                        selected: _entry.sleep,
                        options: BodyCareService.sleepOptions,
                        onSelect: _setSleep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle(
                  'Medições & meta',
                  'Aqui entram as métricas para acompanhar evolução sem perder o foco do dia.',
                ),
                const SizedBox(height: 10),
                _formCard(),
                const SizedBox(height: 16),
                _tipsCard(),
                const SizedBox(height: 16),
                _historyCard(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Salvando...' : 'Salvar registro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF24103B), Color(0xFF12081F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _purple.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFC084FC), Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Corpo em dia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dayLabel(_day),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _entry.statusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _overview.insight,
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
                child: _miniStat(
                  title: 'Sequência',
                  value: '${_overview.currentStreak}d',
                  subtitle: 'dias focados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniStat(
                  title: 'Meta',
                  value: _profile.goal ?? 'Livre',
                  subtitle: _overview.goalLabel,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat({
    required String title,
    required String value,
    required String subtitle,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
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
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 15 : 22,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid() {
    final bmi = _overview.bmi?.toStringAsFixed(1) ?? '--';
    final weight = _overview.latestWeightKg?.toStringAsFixed(1) ?? '--';
    final delta = _overview.weightDeltaKg == null
        ? 'sem variação'
        : _overview.weightDeltaKg! == 0
        ? 'estável'
        : _overview.weightDeltaKg! > 0
        ? '+${_overview.weightDeltaKg!.toStringAsFixed(1)}kg'
        : '${_overview.weightDeltaKg!.toStringAsFixed(1)}kg';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: 'IMC',
                value: bmi,
                subtitle: _overview.bmiLabel,
                icon: Icons.monitor_weight_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: 'Peso atual',
                value: weight == '--' ? '--' : '$weight kg',
                subtitle: delta,
                icon: Icons.scale_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: 'Referência',
                value: _overview.referenceWeightLabel,
                subtitle: _overview.referenceWeightHint,
                icon: Icons.straighten_rounded,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                title: 'Semana',
                value: '${_overview.weeklyFocusedDays}/7',
                subtitle: 'dias bons nesta semana',
                icon: Icons.local_fire_department_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _purpleSoft, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 23,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
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
          const SizedBox(height: 6),
          Text(
            'O Meu Dia continua lendo comida e treino daqui.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < _week.length; i++) ...[
                Expanded(child: _weekPoint(_week[i])),
                if (i != _week.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekPoint(BodyCareWeekPoint point) {
    final letters = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final color = _scoreColor(point.score);
    return Column(
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          alignment: Alignment.center,
          child: Text(
            point.score == null ? '--' : point.score!.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          letters[point.day.weekday - 1],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.70),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
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
      ],
    );
  }

  Widget _questionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required int? selected,
    required List<BodyCareAnswerOption> options,
    required ValueChanged<int> onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.28)),
        gradient: const LinearGradient(
          colors: [Color(0xFF24103B), Color(0xFF0D0817)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple.withValues(alpha: 0.18),
                  border: Border.all(color: _purple.withValues(alpha: 0.32)),
                ),
                child: Icon(icon, color: _purpleSoft),
              ),
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
                        color: Colors.white.withValues(alpha: 0.70),
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
          for (int i = 0; i < options.length; i++) ...[
            InkWell(
              onTap: () => onSelect(options[i].value),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected == options[i].value
                        ? _purpleSoft
                        : Colors.white12,
                    width: selected == options[i].value ? 2 : 1,
                  ),
                  color: selected == options[i].value
                      ? _purple.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.03),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      options[i].label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      options[i].description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != options.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _choiceCard({
    required String title,
    required int? selected,
    required List<BodyCareAnswerOption> options,
    required ValueChanged<int> onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
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
                  selectedColor: _purple.withValues(alpha: 0.28),
                  backgroundColor: Colors.white.withValues(alpha: 0.03),
                  side: BorderSide(
                    color: selected == option.value
                        ? _purpleSoft
                        : Colors.white12,
                  ),
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

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _heightCtrl,
                  label: 'Altura',
                  suffix: 'cm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _targetWeightCtrl,
                  label: 'Peso alvo',
                  suffix: 'kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: BodyCareService.goalOptions.contains(_goal)
                ? _goal
                : BodyCareService.goalOptions.first,
            dropdownColor: const Color(0xFF130A20),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Objetivo corporal'),
            items: BodyCareService.goalOptions
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _goal = value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _weightCtrl,
                  label: 'Peso do dia',
                  suffix: 'kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _waistCtrl,
                  label: 'Cintura',
                  suffix: 'cm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(controller: _stepsCtrl, label: 'Passos'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _minutesCtrl,
                  label: 'Minutos ativos',
                  suffix: 'min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Observação rápida'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  Widget _tipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dicas rápidas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < _overview.quickTips.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _purpleSoft,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _overview.quickTips[i],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            if (i != _overview.quickTips.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _historyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _purple.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico recente',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (_recent.isEmpty)
            Text(
              'Ainda não há registros suficientes para mostrar evolução.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (int i = 0; i < _recent.length && i < 6; i++) ...[
              _historyTile(_recent[i]),
              if (i != 5 && i != _recent.length - 1)
                const Divider(color: Colors.white12, height: 18),
            ],
        ],
      ),
    );
  }

  Widget _historyTile(MapEntry<DateTime, BodyCareEntry> item) {
    final entry = item.value;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _scoreColor(entry.average).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _scoreColor(entry.average).withValues(alpha: 0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            item.key.day.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayLabel(item.key),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Comida ${entry.food ?? '-'} · Treino ${entry.training ?? '-'} · Peso ${entry.weightKg?.toStringAsFixed(1) ?? '--'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          entry.average == null ? '--' : entry.average!.toStringAsFixed(1),
          style: TextStyle(
            color: _purpleSoft,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
