// ============================================================================
// FILE: lib/features/body_care/presentation/pages/body_care_page.dart
//
// Tela principal de Corpo & Saúde / Body Care.
//
// O que este arquivo faz:
// - Mostra um painel vivo do módulo fitness dentro do Meu Dia
// - Mantém os registros de alimentação, treino, água e sono já existentes
// - Adiciona leitura visual de continuidade para dar ânimo ao usuário
// - Exibe um guia alimentar simples, sem radicalismo, com cara do app
// - Traz tabelas rápidas de refeições e calorias aproximadas por item
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../body_care_service.dart';
import '../widgets/body_progress_widgets.dart';

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
  BodyCareNutritionGuide _nutrition = BodyCareNutritionGuide.fallback();
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
    final nutrition = await _service.loadNutritionGuide();
    final week = await _service.last7Days(_selectedDay);
    final recent = await _service.loadRecentEntries(days: 14);

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _entry = entry;
      _overview = overview;
      _nutrition = nutrition;
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

  String _metricLabel(double? value, {String suffix = ''}) {
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

  Color _heroAccent() {
    final score = _entry.average ?? _overview.weeklyAverageTraining ?? 0;
    if (score >= 3.6) return const Color(0xFF9CFF3F);
    if (score >= 2.6) return const Color(0xFF39D0FF);
    if (score >= 1.6) return const Color(0xFFFFB020);
    return const Color(0xFF7D5CFF);
  }

  Widget _buildHero() {
    final accent = _heroAccent();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF39205B), accent.withOpacity(0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.20),
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
                  title: 'Foco do dia',
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

  double _weekStartScore() {
    for (final point in _week) {
      if (point.score != null) return point.score!;
    }
    return 0;
  }

  double _weekEndScore() {
    for (final point in _week.reversed) {
      if (point.score != null) return point.score!;
    }
    return 0;
  }

  String _momentumMessage() {
    if (_week.isEmpty)
      return 'Comece registrando seus dias para ver sua linha subir.';
    final diff = _weekEndScore() - _weekStartScore();
    if (diff >= 0.7) {
      return 'Boa! Sua semana está subindo. Continue empilhando dias úteis.';
    }
    if (diff >= 0.1) {
      return 'Você está melhorando aos poucos. O segredo agora é não quebrar o ritmo.';
    }
    if (diff > -0.4) {
      return 'A semana oscilou, mas ainda dá para fechar bem os próximos dias.';
    }
    return 'Seu gráfico caiu um pouco. Volte para o básico: água, comida, sono e algum movimento.';
  }

  Widget _buildMomentumSection() {
    final best = _week
        .map((e) => e.score ?? 0)
        .fold<double>(0.0, (a, b) => math.max(a, b));
    final focusedDays = _week.where((e) => (e.score ?? 0) >= 3).length;

    return _SectionCard(
      title: 'Ritmo da semana',
      subtitle: 'Uma linha mais viva para mostrar se você está engrenando.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyProgressSection(
            week: _week,
            recent: _recent,
            targetWeightKg: _profile.targetWeightKg,
            latestWeightKg: _overview.latestWeightKg,
            weeklyAverageFood: _overview.weeklyAverageFood,
            weeklyAverageTraining: _overview.weeklyAverageTraining,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Melhor nota',
                  value: best <= 0 ? '—' : best.toStringAsFixed(1),
                  accent: const Color(0xFF9CFF3F),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Dias fortes',
                  value: '$focusedDays/7',
                  accent: const Color(0xFF39D0FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(title: 'Continua assim', body: _momentumMessage()),
        ],
      ),
    );
  }

  Widget _buildQuickOverview() {
    return _SectionCard(
      title: 'Visão rápida',
      subtitle: 'Uma leitura simples para ver como seu corpo está respondendo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                value: _metricLabel(_overview.latestWeightKg, suffix: 'kg'),
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
    return _SectionCard(
      title: title,
      subtitle: subtitle,
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
                child: Text(
                  value == null
                      ? 'Ainda sem resposta neste dia.'
                      : options.firstWhere((e) => e.value == value).description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    height: 1.3,
                  ),
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
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    return _SectionCard(
      title: _nutrition.title,
      subtitle: 'Leitura rápida de combustível, hidratação e treino.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoMetricCard(
                  title: 'Energia',
                  body: _nutrition.energyLabel,
                  accent: const Color(0xFF9CFF3F),
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoMetricCard(
                  title: 'Água',
                  body: _nutrition.hydrationLabel,
                  accent: const Color(0xFF39D0FF),
                  icon: Icons.water_drop_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoMetricCard(
            title: 'Movimento',
            body: _nutrition.activityLabel,
            accent: const Color(0xFF6C63FF),
            icon: Icons.directions_run_rounded,
          ),
          const SizedBox(height: 12),
          _InfoBlock(title: 'Energia do dia', body: _nutrition.energyHint),
          const SizedBox(height: 10),
          _InfoBlock(title: 'Hidratação', body: _nutrition.hydrationHint),
          const SizedBox(height: 10),
          _InfoBlock(title: 'Treino e foco', body: _nutrition.activityHint),
        ],
      ),
    );
  }

  Widget _buildPlateSection() {
    return _SectionCard(
      title: _nutrition.plateTitle,
      subtitle: 'Um desenho simples para ajudar a manter o foco nas refeições.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.05),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: const [
                Expanded(flex: 50, child: ColoredBox(color: Color(0xFF35D26F))),
                Expanded(flex: 25, child: ColoredBox(color: Color(0xFF7D5CFF))),
                Expanded(flex: 25, child: ColoredBox(color: Color(0xFFFFB020))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendDot(
                color: Color(0xFF35D26F),
                text: '50% vegetais e frutas',
              ),
              _LegendDot(color: Color(0xFF7D5CFF), text: '25% proteína'),
              _LegendDot(color: Color(0xFFFFB020), text: '25% carboidrato'),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(title: 'Como montar', body: _nutrition.plateHint),
          const SizedBox(height: 10),
          ..._nutrition.mainTips.map(
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
                      color: Color(0xFF9CFF3F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.74),
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
    );
  }

  Widget _buildMealSuggestions() {
    return _SectionCard(
      title: 'Refeições base',
      subtitle: 'Modelos simples com calorias aproximadas por conjunto.',
      child: Column(
        children: _nutrition.meals.map((meal) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meal.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _KcalPill(value: '${meal.totalCalories} kcal'),
                  ],
                ),
                const SizedBox(height: 12),
                ...meal.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          item.portion,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.66),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${item.calories} kcal',
                          style: const TextStyle(
                            color: Color(0xFF39D0FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFoodTable() {
    return _SectionCard(
      title: 'Tabela rápida de alimentos',
      subtitle: 'Valores aproximados por item para ajudar noção e organização.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 72,
          columnSpacing: 18,
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          dataTextStyle: TextStyle(
            color: Colors.white.withOpacity(0.80),
            height: 1.25,
          ),
          columns: const [
            DataColumn(label: Text('Grupo')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Porção')),
            DataColumn(label: Text('Kcal')),
          ],
          rows: _nutrition.foodTable.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.group)),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.item,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.60),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(item.portion)),
                DataCell(
                  Text(
                    '${item.calories}',
                    style: const TextStyle(
                      color: Color(0xFF9CFF3F),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCareTips() {
    return _SectionCard(
      title: 'Cuidados para seguir firme',
      subtitle:
          'Pontos simples para comida, treino e recuperação não saírem do eixo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alimentação',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ..._nutrition.foodCareTips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TipRow(icon: Icons.restaurant_outlined, text: tip),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Treino e foco',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ..._nutrition.trainingCareTips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TipRow(icon: Icons.fitness_center_rounded, text: tip),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistory() {
    return _SectionCard(
      title: 'Histórico recente',
      subtitle:
          'Os últimos dias registrados para enxergar padrão, não perfeição.',
      child: Column(
        children: [
          if (_recent.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ainda não há registros suficientes.'),
            )
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
        title: const Text('Corpo & Saúde'),
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
                  _buildMomentumSection(),
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
                  _buildNutritionSummary(),
                  const SizedBox(height: 14),
                  _buildPlateSection(),
                  const SizedBox(height: 14),
                  _buildMealSuggestions(),
                  const SizedBox(height: 14),
                  _buildFoodTable(),
                  const SizedBox(height: 14),
                  _buildCareTips(),
                  if (_overview.quickTips.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Dicas rápidas',
                      subtitle:
                          'Pequenas correções que ajudam muito no módulo.',
                      child: Column(
                        children: _overview.quickTips.map((tip) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TipRow(
                              icon: Icons.check_circle_outline_rounded,
                              text: tip,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildRecentHistory(),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF071112),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.68)),
          ),
          const SizedBox(height: 14),
          child,
        ],
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

class _InfoMetricCard extends StatelessWidget {
  const _InfoMetricCard({
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String body;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withOpacity(0.16),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.72))),
      ],
    );
  }
}

class _KcalPill extends StatelessWidget {
  const _KcalPill({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF39D0FF).withOpacity(0.14),
        border: Border.all(color: const Color(0xFF39D0FF).withOpacity(0.25)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF39D0FF),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 16, color: const Color(0xFF9CFF3F)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              height: 1.3,
            ),
          ),
        ),
      ],
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

class _MomentumChart extends StatelessWidget {
  const _MomentumChart({required this.points});

  final List<BodyCareWeekPoint> points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _MomentumPainter(points: points),
                child: Container(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: points.map((point) {
                final day = point.day.day.toString().padLeft(2, '0');
                return Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.58),
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentumPainter extends CustomPainter {
  const _MomentumPainter({required this.points});

  final List<BodyCareWeekPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;

    final usable = points.map((e) => e.score ?? 0).toList();
    final stepX = points.length == 1
        ? size.width
        : size.width / (points.length - 1);

    final linePath = Path();
    final fillPath = Path();

    Offset pointAt(int index) {
      final score = usable[index].clamp(0.0, 4.0);
      final ratio = score / 4.0;
      final x = stepX * index;
      final y = size.height - (size.height * ratio);
      return Offset(x, y);
    }

    final start = pointAt(0);
    linePath.moveTo(start.dx, start.dy);
    fillPath.moveTo(start.dx, size.height);
    fillPath.lineTo(start.dx, start.dy);

    for (var i = 1; i < points.length; i++) {
      final p = pointAt(i);
      linePath.lineTo(p.dx, p.dy);
      fillPath.lineTo(p.dx, p.dy);
    }

    final end = pointAt(points.length - 1);
    fillPath.lineTo(end.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x5535D26F), Color(0x117D5CFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF35D26F), Color(0xFF7D5CFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      final value = usable[i];
      final dotPaint = Paint()
        ..color = value >= 3
            ? const Color(0xFF9CFF3F)
            : const Color(0xFF39D0FF);
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..color = dotPaint.color.withOpacity(0.16)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
