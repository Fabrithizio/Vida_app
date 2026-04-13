// ============================================================================
// FILE: lib/features/body_care/presentation/pages/body_care_page.dart
//
// Tela principal de Corpo & Saúde / Body Care.
//
// O que este arquivo faz:
// - Mostra um painel claro de corpo e rotina, com foco em constância.
// - Lê e salva dados usando o BodyCareService já existente no projeto.
// - Permite editar perfil corporal, registrar o dia e ver histórico recente.
// - Foi escrito para ser uma base estável e legível, sem depender de layouts
//   antigos que possam ter quebrado no seu projeto.
// ============================================================================

import 'package:flutter/material.dart';

import '../../body_care_service.dart';

class BodyCarePage extends StatefulWidget {
  const BodyCarePage({super.key, BodyCareService? service})
    : _service = service;

  final BodyCareService? _service;

  @override
  State<BodyCarePage> createState() => _BodyCarePageState();
}

class _BodyCarePageState extends State<BodyCarePage> {
  late final BodyCareService _service;

  bool _isLoading = true;
  DateTime _selectedDay = _dayOnly(DateTime.now());

  BodyCareProfile _profile = const BodyCareProfile();
  BodyCareEntry _entry = const BodyCareEntry();
  BodyCareOverview _overview = BodyCareOverview.empty();
  List<BodyCareWeekPoint> _week = const [];
  List<MapEntry<DateTime, BodyCareEntry>> _recent = const [];

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? BodyCareService();
    _loadAll();
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    final profile = await _service.loadProfile();
    final entry = await _service.loadDay(_selectedDay);
    final overview = await _service.loadOverview();
    final week = await _service.last7Days(_selectedDay);
    final recent = await _service.loadRecentEntries(days: 14);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _entry = entry;
      _overview = overview;
      _week = week;
      _recent = recent;
      _isLoading = false;
    });
  }

  Future<void> _changeDay(int offset) async {
    setState(
      () => _selectedDay = _dayOnly(_selectedDay.add(Duration(days: offset))),
    );
    await _loadAll();
  }

  Future<void> _saveQuickField({
    double? weight,
    String? note,
    bool clearNote = false,
  }) async {
    if (weight != null) {
      await _service.saveWeight(_selectedDay, weight);
    }
    if (note != null || clearNote) {
      await _service.saveNote(_selectedDay, clearNote ? null : note);
    }
    await _loadAll();
  }

  Future<void> _openProfileSheet() async {
    final heightController = TextEditingController(
      text: _profile.heightCm == null
          ? ''
          : _profile.heightCm!.toStringAsFixed(0),
    );
    final targetController = TextEditingController(
      text: _profile.targetWeightKg == null
          ? ''
          : _profile.targetWeightKg!.toStringAsFixed(1).replaceAll('.', ','),
    );
    String selectedGoal = _profile.goal ?? BodyCareService.goalOptions.first;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 60, 12, 12),
                padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottomInset),
                decoration: BoxDecoration(
                  color: const Color(0xFF071112),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Perfil corporal',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Altura, peso alvo e objetivo principal desta fase.',
                        style: TextStyle(color: Colors.white.withOpacity(0.70)),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Altura',
                          suffixText: 'cm',
                          prefixIcon: Icon(Icons.height_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: targetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Peso alvo',
                          suffixText: 'kg',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Objetivo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: BodyCareService.goalOptions.map((goal) {
                          return ChoiceChip(
                            label: Text(goal),
                            selected: selectedGoal == goal,
                            onSelected: (_) =>
                                setSheetState(() => selectedGoal = goal),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final height = _parseDouble(heightController.text);
                            final target = _parseDouble(targetController.text);
                            await _service.saveProfile(
                              BodyCareProfile(
                                heightCm: height <= 0 ? null : height,
                                targetWeightKg: target <= 0 ? null : target,
                                goal: selectedGoal,
                              ),
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            await _loadAll();
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Salvar perfil'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openWeightNoteSheet() async {
    final weightController = TextEditingController(
      text: _entry.weightKg == null
          ? ''
          : _entry.weightKg!.toStringAsFixed(1).replaceAll('.', ','),
    );
    final noteController = TextEditingController(text: _entry.note ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 60, 12, 12),
            padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottomInset),
            decoration: BoxDecoration(
              color: const Color(0xFF071112),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Peso e observações',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Registre o peso do dia e alguma observação importante.',
                    style: TextStyle(color: Colors.white.withOpacity(0.70)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peso do dia',
                      suffixText: 'kg',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Observação',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _saveQuickField(
                              clearNote: true,
                              weight: null,
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Limpar nota'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await _saveQuickField(
                              weight: _parseDouble(weightController.text),
                              note: noteController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                          child: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _parseDouble(String raw) {
    final normalized = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String _scoreLabel(double? value) {
    if (value == null) return '—';
    return value.toStringAsFixed(1);
  }

  String _dateLabel(DateTime day) {
    final now = _dayOnly(DateTime.now());
    final yesterday = now.subtract(const Duration(days: 1));
    if (_dayOnly(day) == now) return 'Hoje';
    if (_dayOnly(day) == yesterday) return 'Ontem';
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  String _moneylessMetric(double? value, {String suffix = ''}) {
    if (value == null) return '—';
    final decimals = suffix == 'kg' || suffix == 'cm' ? 1 : 0;
    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  Future<void> _saveScore(
    int score,
    Future<void> Function(DateTime day, int value) saver,
  ) async {
    await saver(_selectedDay, score);
    await _loadAll();
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF39205B), Color(0xFF5A2C86)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A2C86).withOpacity(0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.12),
                ),
                child: const Icon(Icons.fitness_center_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Corpo & Saúde',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _overview.goalLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openProfileSheet,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _entry.statusLabel,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _overview.insight,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Foco',
                  value: _scoreLabel(_entry.average),
                  accent: const Color(0xFF9CFF3F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Sequência',
                  value: '${_overview.currentStreak}d',
                  accent: const Color(0xFF39D0FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _changeDay(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Registro do dia',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel(_selectedDay),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _dayOnly(_selectedDay) == _dayOnly(DateTime.now())
                ? null
                : () => _changeDay(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visão rápida',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Uma leitura simples para ver como seu corpo está respondendo.',
            style: TextStyle(color: Colors.white.withOpacity(0.68)),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MetricCard(
                title: 'Peso atual',
                value: _moneylessMetric(_overview.latestWeightKg, suffix: 'kg'),
                accent: const Color(0xFF39D0FF),
              ),
              _MetricCard(
                title: 'IMC',
                value: _overview.bmi == null
                    ? _overview.bmiLabel
                    : '${_overview.bmi!.toStringAsFixed(1)} • ${_overview.bmiLabel}',
                accent: const Color(0xFFFFB020),
              ),
              _MetricCard(
                title: 'Comida média',
                value: _scoreLabel(_overview.weeklyAverageFood),
                accent: const Color(0xFF9CFF3F),
              ),
              _MetricCard(
                title: 'Treino médio',
                value: _scoreLabel(_overview.weeklyAverageTraining),
                accent: const Color(0xFF6C63FF),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoBlock(
            title: 'Faixa de referência',
            body:
                '${_overview.referenceWeightLabel}\n${_overview.referenceWeightHint}',
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required int? value,
    required List<BodyCareAnswerOption> options,
    required Future<void> Function(int score) onSave,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accent.withOpacity(0.16),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.68)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = value == option.value;
              return ChoiceChip(
                label: Text(option.shortLabel),
                selected: selected,
                onSelected: (_) => onSave(option.value),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            value == null
                ? 'Ainda sem resposta neste dia.'
                : options.firstWhere((e) => e.value == value).description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChart() {
    final maxScore = 4.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos 7 dias',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Uma leitura simples da sua constância recente.',
            style: TextStyle(color: Colors.white.withOpacity(0.68)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _week.map((point) {
                final ratio = ((point.score ?? 0) / maxScore).clamp(0.0, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          point.score == null
                              ? '—'
                              : point.score!.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: ratio,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xFF35D26F),
                                      Color(0xFF7D5CFF),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dateLabel(point.day),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.68),
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Widget _buildRecentHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Histórico recente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Os últimos dias registrados para enxergar padrão, não perfeição.',
            style: TextStyle(color: Colors.white.withOpacity(0.68)),
          ),
          const SizedBox(height: 14),
          if (_recent.isEmpty)
            const Text('Ainda não há registros suficientes.')
          else
            ..._recent.take(8).map((item) {
              final entry = item.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF111A1A),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateLabel(item.key),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          entry.statusLabel,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _TinyTag(label: 'Comida ${entry.food ?? '—'}'),
                        _TinyTag(label: 'Treino ${entry.training ?? '—'}'),
                        _TinyTag(label: 'Água ${entry.water ?? '—'}'),
                        _TinyTag(label: 'Sono ${entry.sleep ?? '—'}'),
                        if (entry.weightKg != null)
                          _TinyTag(
                            label:
                                'Peso ${entry.weightKg!.toStringAsFixed(1)}kg',
                          ),
                      ],
                    ),
                    if ((entry.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.note!.trim(),
                        style: TextStyle(color: Colors.white.withOpacity(0.68)),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Care'),
        actions: [
          IconButton(
            onPressed: _openWeightNoteSheet,
            icon: const Icon(Icons.monitor_weight_outlined),
          ),
          IconButton(
            onPressed: _openProfileSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  _buildHero(),
                  const SizedBox(height: 14),
                  _buildDaySelector(),
                  const SizedBox(height: 14),
                  _buildQuickOverview(),
                  const SizedBox(height: 14),
                  _buildQuestionCard(
                    title: 'Alimentação',
                    subtitle: 'Como seu corpo foi alimentado nesse dia.',
                    icon: Icons.restaurant_outlined,
                    accent: const Color(0xFF9CFF3F),
                    value: _entry.food,
                    options: BodyCareService.foodOptions,
                    onSave: (score) => _saveScore(score, _service.saveFood),
                  ),
                  const SizedBox(height: 12),
                  _buildQuestionCard(
                    title: 'Movimento / treino',
                    subtitle: 'O quanto você se mexeu ou treinou.',
                    icon: Icons.fitness_center_rounded,
                    accent: const Color(0xFF7D5CFF),
                    value: _entry.training,
                    options: BodyCareService.trainingOptions,
                    onSave: (score) => _saveScore(score, _service.saveTraining),
                  ),
                  const SizedBox(height: 12),
                  _buildQuestionCard(
                    title: 'Água',
                    subtitle: 'Seu nível de hidratação no dia.',
                    icon: Icons.water_drop_outlined,
                    accent: const Color(0xFF39D0FF),
                    value: _entry.water,
                    options: BodyCareService.waterOptions,
                    onSave: (score) => _saveScore(score, _service.saveWater),
                  ),
                  const SizedBox(height: 12),
                  _buildQuestionCard(
                    title: 'Sono',
                    subtitle: 'Como seu corpo descansou.',
                    icon: Icons.bedtime_outlined,
                    accent: const Color(0xFFFFB020),
                    value: _entry.sleep,
                    options: BodyCareService.sleepOptions,
                    onSave: (score) => _saveScore(score, _service.saveSleep),
                  ),
                  const SizedBox(height: 14),
                  _buildWeekChart(),
                  const SizedBox(height: 14),
                  if (_overview.quickTips.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: const Color(0xFF071112),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dicas rápidas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._overview.quickTips.map(
                            (tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.72),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  _buildRecentHistory(),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.74)),
      ),
    );
  }
}
