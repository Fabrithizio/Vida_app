// ============================================================================
// FILE: lib/features/body_care/presentation/pages/body_care_page.dart
//
// Tela principal de Corpo & Saúde / Body Care.
//
// Ajuste desta versão:
// - reorganiza o módulo fitness em abas, no estilo do módulo de Finanças
// - mantém todas as seções já existentes, sem apagar informação
// - separa o conteúdo em Visão / Registro / Nutrição / Smartwatch / Histórico
// - mantém a integração com Health Connect / smartwatch
// ============================================================================

import 'package:flutter/material.dart';

import '../../../health_sync/health_sync_service.dart';
import '../../../health_sync/presentation/pages/smart_health_page.dart';
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
  bool _savingWeight = false;
  DateTime _selectedDay = _dayOnly(DateTime.now());
  int _selectedModuleTab = 0;

  final TextEditingController _weightController = TextEditingController();

  BodyCareProfile _profile = const BodyCareProfile();
  BodyCareEntry _entry = const BodyCareEntry();
  BodyCareOverview _overview = BodyCareOverview.empty();
  BodyCareNutritionGuide _nutrition = BodyCareNutritionGuide.fallback();
  List<BodyCareWeekPoint> _week = const [];
  List<MapEntry<DateTime, BodyCareEntry>> _recent = const [];
  SmartHealthSnapshot _smartwatchSnapshot = const SmartHealthSnapshot(
    isConnected: false,
    platformLabel: 'Health Connect',
  );

  static const List<_ModuleTabItem> _moduleTabs = [
    _ModuleTabItem(label: 'Visão', icon: Icons.visibility_outlined),
    _ModuleTabItem(label: 'Registro', icon: Icons.edit_note_rounded),
    _ModuleTabItem(label: 'Nutrição', icon: Icons.restaurant_menu_rounded),
    _ModuleTabItem(label: 'Smartwatch', icon: Icons.watch_rounded),
    _ModuleTabItem(label: 'Histórico', icon: Icons.history_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? BodyCareService();
    _loadAll();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    await _service.applySmartwatchSnapshotToToday(day: _selectedDay);

    final profile = await _service.loadProfile();
    final entry = await _service.loadDay(_selectedDay);
    final overview = await _service.loadOverview();
    final nutrition = await _service.loadNutritionGuide();
    final week = await _service.last7Days(_selectedDay);
    final recent = await _service.loadRecentEntries(days: 21);
    final smartwatchSnapshot = await _service.loadSmartwatchSnapshot();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _entry = entry;
      _overview = overview;
      _nutrition = nutrition;
      _week = week;
      _recent = recent;
      _smartwatchSnapshot = smartwatchSnapshot;
      _weightController.text = entry.weightKg == null
          ? ''
          : entry.weightKg!.toStringAsFixed(1).replaceAll('.', ',');
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

  Future<void> _saveInlineWeight() async {
    setState(() => _savingWeight = true);
    final value = _parseDouble(_weightController.text);
    await _service.saveWeight(_selectedDay, value <= 0 ? null : value);
    if (!mounted) return;
    setState(() => _savingWeight = false);
    await _loadAll();
  }

  Future<void> _openSmartHealthPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SmartHealthPage()));
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
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 60, 12, 12),
                padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottomInset),
                decoration: BoxDecoration(
                  color: const Color(0xFF08101E),
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
              color: const Color(0xFF08101E),
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
                    'Observações do dia',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use isso para notar retenção, treino forte, sono ruim ou qualquer detalhe importante.',
                    style: TextStyle(color: Colors.white.withOpacity(0.70)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: noteController,
                    maxLines: 5,
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
                            await _saveQuickField(clearNote: true);
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
    return '${value.toStringAsFixed(decimals).replaceAll('.', ',')}$suffix';
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
    if (score >= 3.6) return const Color(0xFF7A6BFF);
    if (score >= 2.6) return const Color(0xFF4AA3FF);
    if (score >= 1.6) return const Color(0xFF6E79FF);
    return const Color(0xFF5A50D8);
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
          colors: [const Color(0xFF2A2268), const Color(0xFF244A94), accent],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5F79FF).withOpacity(0.22),
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
                        color: Colors.white.withOpacity(0.76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openProfileSheet,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _entry.statusLabel,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
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
                  accent: const Color(0xFFD2E0FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Sequência',
                  value: '${_overview.currentStreak}d',
                  accent: const Color(0xFFB7FFEE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF050A13),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_moduleTabs.length, (index) {
            final item = _moduleTabs[index];
            final selected = _selectedModuleTab == index;
            return Padding(
              padding: EdgeInsets.only(
                right: index == _moduleTabs.length - 1 ? 0 : 8,
              ),
              child: _ModuleTabChip(
                label: item.label,
                icon: item.icon,
                selected: selected,
                onTap: () => setState(() => _selectedModuleTab = index),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF08101E),
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

  Widget _buildWeightSection() {
    return _SectionCard(
      title: 'Peso do dia',
      subtitle:
          'Deixe o peso visível como água e treino. Assim ele entra de forma clara nos gráficos, junto da faixa ideal calculada.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso de hoje',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _savingWeight ? null : _saveInlineWeight,
                  icon: _savingWeight
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF111A2A),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF74A6FF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O melhor horário para se pesar é pela manhã, logo após acordar, em jejum e após ir ao banheiro. Assim a pesagem fica mais precisa e acompanha melhor a evolução.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.76),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Faixa ideal',
                  value: _overview.referenceWeightLabel,
                  accent: const Color(0xFF88F089),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Objetivo atual',
                  value: _overview.goalLabel,
                  accent: const Color(0xFF8E82FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoBlock(
            title: 'Como essa faixa é calculada',
            body: _overview.referenceWeightHint,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Último peso',
                  value: _metricLabel(_overview.latestWeightKg, suffix: 'kg'),
                  accent: const Color(0xFF78B5FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Variação',
                  value: _overview.weightDeltaKg == null
                      ? '—'
                      : '${_overview.weightDeltaKg! > 0 ? '+' : ''}${_overview.weightDeltaKg!.toStringAsFixed(1).replaceAll('.', ',')}kg',
                  accent: const Color(0xFF9EC2FF),
                ),
              ),
            ],
          ),
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
                accent: const Color(0xFF78B5FF),
              ),
              _MetricCard(
                title: 'IMC',
                value: _overview.bmi == null
                    ? _overview.bmiLabel
                    : '${_overview.bmi!.toStringAsFixed(1)} • ${_overview.bmiLabel}',
                accent: const Color(0xFFF9C66B),
              ),
              _MetricCard(
                title: 'Comida média',
                value: _scoreLabel(_overview.weeklyAverageFood),
                accent: const Color(0xFF88F089),
              ),
              _MetricCard(
                title: 'Treino médio',
                value: _scoreLabel(_overview.weeklyAverageTraining),
                accent: const Color(0xFF8E82FF),
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

  List<BodyCareMealSuggestion> get _extraMeals {
    return const [
      BodyCareMealSuggestion(
        title: 'Prato leve',
        subtitle: 'Faixa leve • cerca de 320 kcal',
        items: [
          BodyCareMealItem(
            name: 'Salada grande',
            portion: '1 prato',
            calories: 55,
          ),
          BodyCareMealItem(
            name: 'Frango grelhado',
            portion: '100 g',
            calories: 165,
          ),
          BodyCareMealItem(
            name: 'Batata inglesa',
            portion: '100 g',
            calories: 87,
          ),
        ],
      ),
      BodyCareMealSuggestion(
        title: 'Prato moderado',
        subtitle: 'Faixa moderada • cerca de 470 kcal',
        items: [
          BodyCareMealItem(
            name: 'Arroz cozido',
            portion: '120 g',
            calories: 156,
          ),
          BodyCareMealItem(
            name: 'Feijão cozido',
            portion: '100 g',
            calories: 76,
          ),
          BodyCareMealItem(
            name: 'Patinho moído',
            portion: '120 g',
            calories: 190,
          ),
          BodyCareMealItem(name: 'Legumes', portion: '1 porção', calories: 48),
        ],
      ),
      BodyCareMealSuggestion(
        title: 'Prato reforçado',
        subtitle: 'Faixa alta • cerca de 690 kcal',
        items: [
          BodyCareMealItem(
            name: 'Macarrão cozido',
            portion: '180 g',
            calories: 282,
          ),
          BodyCareMealItem(
            name: 'Frango grelhado',
            portion: '150 g',
            calories: 248,
          ),
          BodyCareMealItem(
            name: 'Azeite',
            portion: '1 colher sopa',
            calories: 90,
          ),
          BodyCareMealItem(name: 'Legumes', portion: '1 porção', calories: 70),
        ],
      ),
      BodyCareMealSuggestion(
        title: 'Lanche proteico',
        subtitle: 'Faixa moderada • cerca de 410 kcal',
        items: [
          BodyCareMealItem(
            name: 'Iogurte natural',
            portion: '170 g',
            calories: 110,
          ),
          BodyCareMealItem(name: 'Aveia', portion: '40 g', calories: 152),
          BodyCareMealItem(name: 'Banana', portion: '1 un', calories: 90),
          BodyCareMealItem(
            name: 'Pasta de amendoim',
            portion: '10 g',
            calories: 58,
          ),
        ],
      ),
    ];
  }

  List<BodyCareFoodTableItem> get _extraFoodTable {
    return const [
      BodyCareFoodTableItem(
        group: 'Proteína',
        item: 'Patinho moído',
        portion: '100 g',
        calories: 160,
        note: 'Boa base para prato simples.',
      ),
      BodyCareFoodTableItem(
        group: 'Proteína',
        item: 'Tilápia grelhada',
        portion: '100 g',
        calories: 129,
        note: 'Leve e fácil de combinar.',
      ),
      BodyCareFoodTableItem(
        group: 'Carboidrato',
        item: 'Macarrão cozido',
        portion: '100 g',
        calories: 157,
        note: 'Energia prática para dias de treino.',
      ),
      BodyCareFoodTableItem(
        group: 'Carboidrato',
        item: 'Cuscuz',
        portion: '100 g',
        calories: 112,
        note: 'Base rápida para café ou jantar.',
      ),
      BodyCareFoodTableItem(
        group: 'Gordura boa',
        item: 'Pasta de amendoim',
        portion: '15 g',
        calories: 88,
        note: 'Boa em lanches, mas sem exagero.',
      ),
      BodyCareFoodTableItem(
        group: 'Vegetal',
        item: 'Brócolis cozido',
        portion: '100 g',
        calories: 35,
        note: 'Volume e fibra com poucas calorias.',
      ),
    ];
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
                  accent: const Color(0xFF88F089),
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoMetricCard(
                  title: 'Água',
                  body: _nutrition.hydrationLabel,
                  accent: const Color(0xFF78B5FF),
                  icon: Icons.water_drop_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoMetricCard(
            title: 'Movimento',
            body: _nutrition.activityLabel,
            accent: const Color(0xFF8E82FF),
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
                      color: Color(0xFF88F089),
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

  Map<String, List<BodyCareMealSuggestion>> _mealBuckets() {
    final allMeals = <BodyCareMealSuggestion>[
      ..._nutrition.meals,
      ..._extraMeals,
    ];

    final buckets = <String, List<BodyCareMealSuggestion>>{
      'Até 350 kcal': [],
      '351–550 kcal': [],
      'Acima de 550 kcal': [],
    };

    for (final meal in allMeals) {
      final kcal = meal.totalCalories;
      if (kcal <= 350) {
        buckets['Até 350 kcal']!.add(meal);
      } else if (kcal <= 550) {
        buckets['351–550 kcal']!.add(meal);
      } else {
        buckets['Acima de 550 kcal']!.add(meal);
      }
    }
    return buckets;
  }

  Widget _buildMealSuggestions() {
    final buckets = _mealBuckets();

    return _SectionCard(
      title: 'Refeições por faixa de calorias',
      subtitle: 'Agora os pratos ficam separados por nível de calorias totais.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: buckets.entries.map((entry) {
          if (entry.value.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...entry.value.map((meal) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: const Color(0xFF10192A),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                    color: Color(0xFF78B5FF),
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
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFoodTable() {
    final rows = <BodyCareFoodTableItem>[
      ..._nutrition.foodTable,
      ..._extraFoodTable,
    ];

    return _SectionCard(
      title: 'Tabela rápida de alimentos',
      subtitle:
          'Valores aproximados por item para ajudar na noção e na organização.',
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
          rows: rows.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.group)),
                DataCell(
                  SizedBox(
                    width: 160,
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
                      color: Color(0xFF88F089),
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

  Widget _buildSmartwatchSection() {
    final snapshot = _smartwatchSnapshot;
    final syncText = _service.formatSmartwatchSync(snapshot.lastSyncAt);

    return _SectionCard(
      title: 'Smartwatch & saúde',
      subtitle:
          'Ligação simples via Health Connect para puxar dados reais sem complicar o módulo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: snapshot.isConnected
                    ? const [Color(0xFF0C3D2B), Color(0xFF0F6A4E)]
                    : const [Color(0xFF10192A), Color(0xFF18304F)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.12),
                      ),
                      child: Icon(
                        snapshot.isConnected
                            ? Icons.watch_rounded
                            : Icons.watch_off_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.isConnected
                                ? 'Conexão pronta'
                                : 'Conectar em 1 toque',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.isConnected
                                ? 'Última sincronização: $syncText'
                                : 'Use o caminho mais simples no Android: Health Connect.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.76),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openSmartHealthPage,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(
                      snapshot.isConnected
                          ? 'Abrir conexão e sincronização'
                          : 'Conectar smartwatch / Health Connect',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _MetricCard(
                title: 'Passos hoje',
                value: snapshot.stepsToday == null
                    ? '—'
                    : '${snapshot.stepsToday}',
                accent: const Color(0xFF78B5FF),
              ),
              _MetricCard(
                title: 'Sono recente',
                value: snapshot.sleepHours == null
                    ? '—'
                    : '${snapshot.sleepHours!.toStringAsFixed(1).replaceAll('.', ',')}h',
                accent: const Color(0xFFF9C66B),
              ),
              _MetricCard(
                title: 'Atividade hoje',
                value: snapshot.activeMinutesToday == null
                    ? '—'
                    : '${snapshot.activeMinutesToday} min',
                accent: const Color(0xFF88F089),
              ),
              _MetricCard(
                title: 'Calorias ativas',
                value: snapshot.activeCaloriesToday == null
                    ? '—'
                    : '${snapshot.activeCaloriesToday} kcal',
                accent: const Color(0xFF8E82FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: 'Como isso entra no fitness',
            body:
                'O app usa os dados principais como fonte real para reforçar a leitura do dia. Isso ajuda o Areas sem apagar seus lançamentos manuais.',
          ),
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10192A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                title: const Text(
                  'Detalhes secundários',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Treinos e leitura complementar ficam escondidos aqui.',
                  style: TextStyle(color: Colors.white.withOpacity(0.62)),
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Exercício 7d',
                          value: snapshot.exerciseMinutes7d == null
                              ? '—'
                              : '${snapshot.exerciseMinutes7d!.toStringAsFixed(0)} min',
                          accent: const Color(0xFF88F089),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'Treinos 7d',
                          value: snapshot.workoutCount7d?.toString() ?? '—',
                          accent: const Color(0xFF9EC2FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                  color: const Color(0xFF10192A),
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
                        if (entry.steps != null)
                          _TinyTag(label: 'Passos ${entry.steps}'),
                        if (entry.activeMinutes != null)
                          _TinyTag(label: 'Ativo ${entry.activeMinutes} min'),
                        if (entry.weightKg != null)
                          _TinyTag(
                            label:
                                'Peso ${entry.weightKg!.toStringAsFixed(1).replaceAll('.', ',')}kg',
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

  List<Widget> _buildTabSections() {
    switch (_selectedModuleTab) {
      case 0:
        return [
          _buildQuickOverview(),
          const SizedBox(height: 14),
          BodyProgressSection(
            week: _week,
            recent: _recent,
            targetWeightKg: _profile.targetWeightKg,
            latestWeightKg: _overview.latestWeightKg,
            weeklyAverageFood: _overview.weeklyAverageFood,
            weeklyAverageTraining: _overview.weeklyAverageTraining,
            referenceWeightLabel: _overview.referenceWeightLabel,
            goalLabel: _overview.goalLabel,
          ),
          if (_overview.quickTips.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Dicas rápidas',
              subtitle: 'Pequenas correções que ajudam muito no módulo.',
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
        ];
      case 1:
        return [
          _buildDaySelector(),
          const SizedBox(height: 14),
          _buildWeightSection(),
          const SizedBox(height: 12),
          _buildQuestionCard(
            title: 'Alimentação',
            subtitle: 'Como seu corpo foi alimentado nesse dia.',
            icon: Icons.restaurant_outlined,
            accent: const Color(0xFF88F089),
            value: _entry.food,
            options: BodyCareService.foodOptions,
            onSave: (score) => _saveScore(score, _service.saveFood),
          ),
          const SizedBox(height: 12),
          _buildQuestionCard(
            title: 'Movimento / treino',
            subtitle: 'O quanto você se mexeu ou treinou.',
            icon: Icons.fitness_center_rounded,
            accent: const Color(0xFF8E82FF),
            value: _entry.training,
            options: BodyCareService.trainingOptions,
            onSave: (score) => _saveScore(score, _service.saveTraining),
          ),
          const SizedBox(height: 12),
          _buildQuestionCard(
            title: 'Água',
            subtitle: 'Seu nível de hidratação no dia.',
            icon: Icons.water_drop_outlined,
            accent: const Color(0xFF78B5FF),
            value: _entry.water,
            options: BodyCareService.waterOptions,
            onSave: (score) => _saveScore(score, _service.saveWater),
          ),
          const SizedBox(height: 12),
          _buildQuestionCard(
            title: 'Sono',
            subtitle: 'Como seu corpo descansou.',
            icon: Icons.bedtime_outlined,
            accent: const Color(0xFFF9C66B),
            value: _entry.sleep,
            options: BodyCareService.sleepOptions,
            onSave: (score) => _saveScore(score, _service.saveSleep),
          ),
        ];
      case 2:
        return [
          _buildNutritionSummary(),
          const SizedBox(height: 14),
          _buildPlateSection(),
          const SizedBox(height: 14),
          _buildMealSuggestions(),
          const SizedBox(height: 14),
          _buildFoodTable(),
          const SizedBox(height: 14),
          _buildCareTips(),
        ];
      case 3:
        return [_buildSmartwatchSection()];
      case 4:
        return [_buildRecentHistory()];
      default:
        return [_buildQuickOverview()];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corpo & Saúde'),
        actions: [
          IconButton(
            onPressed: _openWeightNoteSheet,
            icon: const Icon(Icons.notes_rounded),
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
                  _buildModuleTabs(),
                  const SizedBox(height: 14),
                  ..._buildTabSections(),
                ],
              ),
            ),
    );
  }
}

class _ModuleTabItem {
  const _ModuleTabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _ModuleTabChip extends StatelessWidget {
  const _ModuleTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? const Color(0xFF41D26C) : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF41D26C).withOpacity(0.26),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
          border: Border.all(
            color: selected
                ? const Color(0xFF41D26C)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.black : Colors.white.withOpacity(0.76),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white.withOpacity(0.76),
                fontWeight: FontWeight.w900,
              ),
            ),
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
        color: const Color(0xFF08101E),
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
        color: const Color(0xFF10192A),
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
        color: const Color(0xFF10192A),
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
        color: const Color(0xFF78B5FF).withOpacity(0.14),
        border: Border.all(color: const Color(0xFF78B5FF).withOpacity(0.25)),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF78B5FF),
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
          child: Icon(icon, size: 16, color: const Color(0xFF88F089)),
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
