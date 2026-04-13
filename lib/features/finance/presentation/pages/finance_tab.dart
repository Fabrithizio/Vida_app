// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance_tab.dart
//
// Tela principal de Finanças do Vida, agora refatorada.
//
// O que este arquivo faz:
// - Orquestra a home financeira e as 4 áreas internas: Visão, Planejar,
//   Investir e Controle.
// - Mantém a lógica de preferências locais, privacidade e simulações.
// - Delega widgets e modelos para arquivos separados, deixando a manutenção
//   muito mais simples do que antes.
// - Continua compatível com o FinanceStore e com o AddTransactionPage atuais.
// ============================================================================

import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/finance_category.dart';
import '../../data/models/finance_period_type.dart';
import '../../data/models/finance_transaction.dart';
import '../stores/finance_store.dart';
import 'add_transaction_page.dart';
import 'finance/finance_planning_catalog.dart';
import 'finance/finance_tab_models.dart';
import 'finance/finance_tab_utils.dart';
import 'finance/finance_tab_widgets.dart';

String _financePeriodLabel(FinancePeriodType period) {
  switch (period) {
    case FinancePeriodType.currentMonth:
      return 'Este mês';
    case FinancePeriodType.previousMonth:
      return 'Mês passado';
    case FinancePeriodType.currentYear:
      return 'Este ano';
    case FinancePeriodType.allTime:
      return 'Tudo';
  }
}

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key, this.store});

  final FinanceStore? store;

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  late final FinanceStore _store;

  bool _loadingPrefs = true;
  bool _hideValues = false;
  int _currentSection = 0;

  int _planningPresetIndex = 0;
  double _monthlyIncomePlan = 0;
  double _planningEssentialPercent = 60;
  double _planningFuturePercent = 30;
  double _planningFreePercent = 10;
  Map<String, double> _plannedByCategory = <String, double>{};
  Set<String> _activePlanningCategoryIds = <String>{};
  bool _planningOwnHome = false;
  bool _planningMealTicket = false;
  bool _planningNoCar = false;
  bool _planningFreeTransit = false;
  bool _planningHasHealthPlan = false;

  double _investedPrincipal = 0;
  double _investedCurrentValue = 0;
  double _monthlyInvestmentContribution = 0;
  double _annualInterestRate = 10;
  double _investmentTarget = 0;

  String get _prefsPrefix {
    final uid = FirebaseAuth.instance.currentUser?.uid?.trim();
    return (uid == null || uid.isEmpty) ? 'anon' : uid;
  }

  List<FinancePlanningPreset> get _planningPresets => const [
    FinancePlanningPreset(
      label: '60/30/10',
      essential: 60,
      future: 30,
      free: 10,
    ),
    FinancePlanningPreset(
      label: '70/20/10',
      essential: 70,
      future: 20,
      free: 10,
    ),
    FinancePlanningPreset(
      label: '50/30/20',
      essential: 50,
      future: 30,
      free: 20,
    ),
    FinancePlanningPreset(
      label: '80/10/10',
      essential: 80,
      future: 10,
      free: 10,
    ),
  ];

  List<FinanceCategory> get _planningCategories => _store.categories
      .where((item) => item.isIncomeCategory != true)
      .cast<FinanceCategory>()
      .toList();

  Set<String> _defaultActivePlanningIds() {
    return FinancePlanningCatalog.defaultActiveIds(_planningCategories).toSet();
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? FinanceStore();
    _boot();
  }

  Future<void> _boot() async {
    if (!_store.hasLoaded && !_store.isLoading) {
      await _store.load();
    }
    await _loadPrefs();
  }

  Future<void> _refreshAll() async {
    await _store.load();
    await _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nextPlanned = <String, double>{};

    for (final category in _planningCategories) {
      nextPlanned[category.id] =
          prefs.getDouble('$_prefsPrefix:plan:${category.id}') ?? 0;
    }

    final rawActiveIds = prefs.getStringList(
      '$_prefsPrefix:finance_plan_active_ids',
    );
    final knownIds = _planningCategories.map((item) => item.id).toSet();
    final activeIds = (rawActiveIds == null || rawActiveIds.isEmpty)
        ? _defaultActivePlanningIds()
        : rawActiveIds.where(knownIds.contains).toSet();

    if (!mounted) return;

    setState(() {
      _hideValues = prefs.getBool('$_prefsPrefix:finance_hide_values') ?? false;
      _planningPresetIndex =
          prefs.getInt('$_prefsPrefix:finance_plan_preset') ?? 0;
      _monthlyIncomePlan =
          prefs.getDouble('$_prefsPrefix:finance_income_plan') ?? 0;
      _planningEssentialPercent =
          prefs.getDouble('$_prefsPrefix:finance_plan_essentials_percent') ??
          60;
      _planningFuturePercent =
          prefs.getDouble('$_prefsPrefix:finance_plan_future_percent') ?? 30;
      _planningFreePercent =
          prefs.getDouble('$_prefsPrefix:finance_plan_free_percent') ?? 10;
      _plannedByCategory = nextPlanned;
      _activePlanningCategoryIds = activeIds;
      _planningOwnHome =
          prefs.getBool('$_prefsPrefix:plan_life_own_home') ?? false;
      _planningMealTicket =
          prefs.getBool('$_prefsPrefix:plan_life_meal_ticket') ?? false;
      _planningNoCar = prefs.getBool('$_prefsPrefix:plan_life_no_car') ?? false;
      _planningFreeTransit =
          prefs.getBool('$_prefsPrefix:plan_life_free_transit') ?? false;
      _planningHasHealthPlan =
          prefs.getBool('$_prefsPrefix:plan_life_health_plan') ?? false;
      _investedPrincipal =
          prefs.getDouble('$_prefsPrefix:invest_principal') ?? 0;
      _investedCurrentValue =
          prefs.getDouble('$_prefsPrefix:invest_current_value') ?? 0;
      _monthlyInvestmentContribution =
          prefs.getDouble('$_prefsPrefix:invest_monthly_contribution') ?? 0;
      _annualInterestRate =
          prefs.getDouble('$_prefsPrefix:invest_annual_rate') ?? 10;
      _investmentTarget = prefs.getDouble('$_prefsPrefix:invest_target') ?? 0;
      _loadingPrefs = false;
    });
  }

  Future<void> _togglePrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_hideValues;
    await prefs.setBool('$_prefsPrefix:finance_hide_values', next);
    if (!mounted) return;
    setState(() => _hideValues = next);
  }

  Future<void> _openAddTransactionPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddTransactionPage(store: _store),
      ),
    );
    await _refreshAll();
  }

  Future<void> _openEditTransactionPage(FinanceTransaction transaction) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AddTransactionPage(store: _store, initialTransaction: transaction),
      ),
    );
    await _refreshAll();
  }

  Future<void> _confirmRemoveTransaction(FinanceTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover lançamento'),
        content: Text('Deseja remover "${transaction.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _store.removeTransaction(transaction.id);
  }

  Future<void> _openPlanningSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final incomeController = TextEditingController(
      text: _monthlyIncomePlan == 0 ? '' : moneyField(_monthlyIncomePlan),
    );
    final controllers = <String, TextEditingController>{
      for (final category in _planningCategories)
        category.id: TextEditingController(
          text: (_plannedByCategory[category.id] ?? 0) <= 0
              ? ''
              : moneyField(_plannedByCategory[category.id] ?? 0),
        ),
    };

    int localPreset = _planningPresetIndex;
    double essential = _planningEssentialPercent;
    double future = _planningFuturePercent;
    double free = _planningFreePercent;
    var localActiveIds = <String>{
      ...(_activePlanningCategoryIds.isEmpty
          ? _defaultActivePlanningIds()
          : _activePlanningCategoryIds),
    };
    bool ownHome = _planningOwnHome;
    bool mealTicket = _planningMealTicket;
    bool noCar = _planningNoCar;
    bool freeTransit = _planningFreeTransit;
    bool hasHealthPlan = _planningHasHealthPlan;
    bool showAllOptional = false;

    Map<String, double> readCurrentValues() {
      return {
        for (final category in _planningCategories)
          category.id: parseMoney(controllers[category.id]!.text),
      };
    }

    double totalAllocated(Map<String, double> values) {
      return localActiveIds.fold<double>(
        0,
        (sum, id) => sum + (values[id] ?? 0),
      );
    }

    Map<String, double> autoPlan() {
      return _autoDistributePlan(
        income: parseMoney(incomeController.text),
        essentialPercent: essential,
        futurePercent: future,
        freePercent: free,
        activeIds: localActiveIds,
        ownHome: ownHome,
        mealTicket: mealTicket,
        noCar: noCar,
        freeTransit: freeTransit,
        hasHealthPlan: hasHealthPlan,
      );
    }

    void applyAutomatic({bool preserveManual = false}) {
      final suggested = autoPlan();
      final currentValues = readCurrentValues();
      for (final category in _planningCategories) {
        final currentValue = currentValues[category.id] ?? 0;
        final nextValue = preserveManual && currentValue > 0
            ? currentValue
            : (suggested[category.id] ?? 0);
        controllers[category.id]!.text = nextValue <= 0
            ? ''
            : moneyField(nextValue);
      }
    }

    String saveProfileLabel() {
      final labels = <String>[];
      if (ownHome) labels.add('casa própria');
      if (mealTicket) labels.add('vale alimentação');
      if (noCar) labels.add('sem carro');
      if (freeTransit) labels.add('passagem grátis');
      if (hasHealthPlan) labels.add('plano de saúde');
      if (labels.isEmpty) return 'Nenhum atalho aplicado.';
      return labels.join(' • ');
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final income = parseMoney(incomeController.text);
            final currentValues = readCurrentValues();
            final allocated = totalAllocated(currentValues);
            final remaining = math.max(0.0, income - allocated).toDouble();
            final activeCategories = _sortedPlanningCategories(localActiveIds);
            final optionalCategories = _sortedPlanningCategories(
              _planningCategories
                  .map((item) => item.id)
                  .toSet()
                  .difference(localActiveIds),
            );

            Future<void> save() async {
              final parsedIncome = parseMoney(incomeController.text);
              var parsedValues = readCurrentValues();
              double allocatedValue = localActiveIds.fold<double>(
                0,
                (sum, id) => sum + (parsedValues[id] ?? 0),
              );

              if (allocatedValue <= 0.01) {
                parsedValues = autoPlan();
                allocatedValue = localActiveIds.fold<double>(
                  0,
                  (sum, id) => sum + (parsedValues[id] ?? 0),
                );
              }

              if (allocatedValue > parsedIncome + 0.1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Os valores planejados passaram da renda do mês.',
                    ),
                  ),
                );
                return;
              }

              final remainder = parsedIncome - allocatedValue;
              if (remainder > 0.01) {
                final receiverId = _pickRemainderCategory(localActiveIds);
                if (receiverId != null) {
                  parsedValues[receiverId] =
                      (parsedValues[receiverId] ?? 0) + remainder;
                  localActiveIds.add(receiverId);
                }
              }

              await prefs.setDouble(
                '$_prefsPrefix:finance_income_plan',
                parsedIncome,
              );
              await prefs.setInt(
                '$_prefsPrefix:finance_plan_preset',
                localPreset,
              );
              await prefs.setDouble(
                '$_prefsPrefix:finance_plan_essentials_percent',
                essential,
              );
              await prefs.setDouble(
                '$_prefsPrefix:finance_plan_future_percent',
                future,
              );
              await prefs.setDouble(
                '$_prefsPrefix:finance_plan_free_percent',
                free,
              );
              await prefs.setStringList(
                '$_prefsPrefix:finance_plan_active_ids',
                localActiveIds.toList(),
              );
              await prefs.setBool('$_prefsPrefix:plan_life_own_home', ownHome);
              await prefs.setBool(
                '$_prefsPrefix:plan_life_meal_ticket',
                mealTicket,
              );
              await prefs.setBool('$_prefsPrefix:plan_life_no_car', noCar);
              await prefs.setBool(
                '$_prefsPrefix:plan_life_free_transit',
                freeTransit,
              );
              await prefs.setBool(
                '$_prefsPrefix:plan_life_health_plan',
                hasHealthPlan,
              );

              for (final category in _planningCategories) {
                await prefs.setDouble(
                  '$_prefsPrefix:plan:${category.id}',
                  parsedValues[category.id] ?? 0,
                );
              }

              if (!mounted) return;
              Navigator.of(context).pop();
              await _loadPrefs();
            }

            Widget buildLifeChip({
              required bool selected,
              required IconData icon,
              required String label,
              required VoidCallback onTap,
            }) {
              return FilterChip(
                selected: selected,
                onSelected: (_) => onTap(),
                avatar: Icon(icon, size: 18),
                label: Text(label),
              );
            }

            Widget buildCategoryEditor(FinanceCategory category) {
              final bucket = FinancePlanningCatalog.bucketOf(category.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF111A1A),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: category.color.withOpacity(0.18),
                          child: Icon(
                            category.icon,
                            color: category.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                FinancePlanningCatalog.bucketLabel(bucket),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.62),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover do plano',
                          onPressed: () {
                            setSheetState(() {
                              localActiveIds.remove(category.id);
                              controllers[category.id]!.text = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controllers[category.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor planejado',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(category.icon),
                      ),
                    ),
                  ],
                ),
              );
            }

            return FinanceSheetFrame(
              title: 'Planejar o mês',
              subtitle:
                  'O app sugere, mas você adapta ao seu jeito de viver. O que você não usa sai da divisão.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FinanceTextField(
                    controller: incomeController,
                    label: 'Renda do mês',
                    prefixText: 'R\$ ',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Modelos rápidos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(_planningPresets.length, (
                      index,
                    ) {
                      final preset = _planningPresets[index];
                      return ChoiceChip(
                        label: Text(preset.label),
                        selected: localPreset == index,
                        onSelected: (_) {
                          setSheetState(() {
                            localPreset = index;
                            essential = preset.essential;
                            future = preset.future;
                            free = preset.free;
                            applyAutomatic();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FinanceMiniPercentCard(
                          label: 'Essenciais',
                          value: essential,
                          color: const Color(0xFF28C76F),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceMiniPercentCard(
                          label: 'Investir + reserva',
                          value: future,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceMiniPercentCard(
                          label: 'Livre',
                          value: free,
                          color: const Color(0xFFFFB020),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Seu jeito de viver',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildLifeChip(
                        selected: ownHome,
                        icon: Icons.home_work_outlined,
                        label: 'Casa própria',
                        onTap: () => setSheetState(() {
                          ownHome = !ownHome;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: mealTicket,
                        icon: Icons.lunch_dining_outlined,
                        label: 'Vale alimentação',
                        onTap: () => setSheetState(() {
                          mealTicket = !mealTicket;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: noCar,
                        icon: Icons.no_crash_outlined,
                        label: 'Sem carro',
                        onTap: () => setSheetState(() {
                          noCar = !noCar;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: freeTransit,
                        icon: Icons.directions_bus_outlined,
                        label: 'Passagem grátis',
                        onTap: () => setSheetState(() {
                          freeTransit = !freeTransit;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                      buildLifeChip(
                        selected: hasHealthPlan,
                        icon: Icons.health_and_safety_outlined,
                        label: 'Plano de saúde',
                        onTap: () => setSheetState(() {
                          hasHealthPlan = !hasHealthPlan;
                          applyAutomatic(preserveManual: true);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FinanceSoftInfoCard(
                    title: 'Perfil aplicado',
                    text: saveProfileLabel(),
                    icon: Icons.auto_awesome_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              setSheetState(() => applyAutomatic()),
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Distribuir automático'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setSheetState(
                            () => applyAutomatic(preserveManual: true),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Redistribuir restante'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const FinanceSoftInfoCard(
                    title: 'Como o saldo restante é tratado',
                    text:
                        'Se você reduzir uma categoria e sobrar dinheiro, o restante vai para reserva/caixinha ao salvar.',
                    icon: Icons.savings_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FinanceValueBadge(
                          label: 'Planejado agora',
                          value: formatCurrency(allocated, hideValues: false),
                          color: const Color(0xFF39D0FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FinanceValueBadge(
                          label: 'Ainda sobrando',
                          value: formatCurrency(remaining, hideValues: false),
                          color: const Color(0xFFFFB020),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Categorias do seu plano',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ative só o que faz sentido para sua vida. O resto fica como opção.',
                    style: TextStyle(color: Colors.white.withOpacity(0.68)),
                  ),
                  const SizedBox(height: 12),
                  ...activeCategories.map(buildCategoryEditor),
                  const SizedBox(height: 6),
                  const Text(
                    'Adicionar mais categorias',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category
                          in (showAllOptional
                              ? optionalCategories
                              : optionalCategories.take(12).toList()))
                        ActionChip(
                          avatar: Icon(
                            category.icon,
                            size: 18,
                            color: category.color,
                          ),
                          label: Text(category.name),
                          onPressed: () {
                            setSheetState(() {
                              localActiveIds.add(category.id);
                              final suggested = autoPlan()[category.id] ?? 0;
                              if (parseMoney(controllers[category.id]!.text) <=
                                  0) {
                                controllers[category.id]!.text = suggested <= 0
                                    ? ''
                                    : moneyField(suggested);
                              }
                            });
                          },
                        ),
                      if (optionalCategories.length > 12)
                        ActionChip(
                          avatar: const Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                          ),
                          label: Text(
                            showAllOptional ? 'Ver menos' : 'Ver mais',
                          ),
                          onPressed: () => setSheetState(() {
                            showAllOptional = !showAllOptional;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Salvar planejamento'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openInvestmentSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final principalController = TextEditingController(
      text: _investedPrincipal == 0 ? '' : moneyField(_investedPrincipal),
    );
    final currentValueController = TextEditingController(
      text: _investedCurrentValue == 0 ? '' : moneyField(_investedCurrentValue),
    );
    final monthlyContributionController = TextEditingController(
      text: _monthlyInvestmentContribution == 0
          ? ''
          : moneyField(_monthlyInvestmentContribution),
    );
    final rateController = TextEditingController(
      text: _annualInterestRate == 0
          ? ''
          : _annualInterestRate.toStringAsFixed(2),
    );
    final targetController = TextEditingController(
      text: _investmentTarget == 0 ? '' : moneyField(_investmentTarget),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FinanceSheetFrame(
          title: 'Ajustar investimentos',
          subtitle: 'Seu dinheiro aportado é só o que saiu do seu bolso.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FinanceTextField(
                controller: principalController,
                label: 'Seu dinheiro já aportado',
                prefixText: 'R\$ ',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: currentValueController,
                label: 'Montante atual',
                prefixText: 'R\$ ',
                icon: Icons.savings_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: monthlyContributionController,
                label: 'Aporte mensal',
                prefixText: 'R\$ ',
                icon: Icons.calendar_month_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: rateController,
                label: 'Juros médios ao ano',
                suffixText: '%',
                icon: Icons.trending_up_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              FinanceTextField(
                controller: targetController,
                label: 'Meta de patrimônio',
                prefixText: 'R\$ ',
                icon: Icons.flag_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              const FinanceSoftInfoCard(
                title: 'Como ler',
                text:
                    'Montante atual = seu dinheiro aportado + rendimento. '
                    'A projeção abaixo não desconta IR, IOF, taxas ou inflação.',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_principal',
                      parseMoney(principalController.text),
                    );
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_current_value',
                      parseMoney(currentValueController.text),
                    );
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_monthly_contribution',
                      parseMoney(monthlyContributionController.text),
                    );
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_annual_rate',
                      parseDoubleValue(rateController.text),
                    );
                    await prefs.setDouble(
                      '$_prefsPrefix:invest_target',
                      parseMoney(targetController.text),
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    await _loadPrefs();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar investimento'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCategoryDetails(FinanceCategoryTotal item) async {
    final matches =
        _store.expenseTransactions
            .where((tx) => tx.category.id == item.category.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FinanceSheetFrame(
          title: item.category.name,
          subtitle: 'Lançamentos do período selecionado.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FinanceCategorySummaryTile(
                icon: item.category.icon,
                color: item.category.color,
                title: 'Total da categoria',
                subtitle: _financePeriodLabel(_store.selectedPeriod),
                trailing: formatCurrency(item.total, hideValues: _hideValues),
              ),
              const SizedBox(height: 12),
              if (matches.isEmpty)
                const Text('Nenhum lançamento nessa categoria no período.')
              else
                ...matches.map(
                  (tx) => FinanceTransactionTile(
                    transaction: tx,
                    amountLabel: formatCurrency(
                      tx.amount,
                      hideValues: _hideValues,
                    ),
                    dateLabel: formatShortDate(tx.date),
                    onEdit: () => _openEditTransactionPage(tx),
                    onDelete: () => _confirmRemoveTransaction(tx),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, double> _resolvedPlanValues() {
    final activeIds = _activePlanningCategoryIds.isEmpty
        ? _defaultActivePlanningIds()
        : _activePlanningCategoryIds;
    final currentValues = <String, double>{
      for (final category in _planningCategories)
        category.id: activeIds.contains(category.id)
            ? (_plannedByCategory[category.id] ?? 0)
            : 0,
    };
    final total = activeIds.fold<double>(
      0,
      (sum, id) => sum + (currentValues[id] ?? 0),
    );
    if (total <= 0.01) {
      return _autoDistributePlan(
        income: _monthlyIncomePlan,
        essentialPercent: _planningEssentialPercent,
        futurePercent: _planningFuturePercent,
        freePercent: _planningFreePercent,
        activeIds: activeIds,
        ownHome: _planningOwnHome,
        mealTicket: _planningMealTicket,
        noCar: _planningNoCar,
        freeTransit: _planningFreeTransit,
        hasHealthPlan: _planningHasHealthPlan,
      );
    }
    return currentValues;
  }

  List<FinanceCategory> _sortedPlanningCategories(Iterable<String> ids) {
    final idSet = ids.toSet();
    final items = _planningCategories
        .where((item) => idSet.contains(item.id))
        .toList();
    items.sort(FinancePlanningCatalog.compareCategories);
    return items;
  }

  String? _pickRemainderCategory(Set<String> activeIds) {
    const preferredIds = <String>[
      'future_emergency',
      'future_caixinha',
      'future_stocks',
      'other_expense',
    ];
    for (final id in preferredIds) {
      if (_planningCategories.any((category) => category.id == id)) {
        return id;
      }
    }
    if (activeIds.isNotEmpty) {
      final sorted = _sortedPlanningCategories(activeIds);
      return sorted.isEmpty ? null : sorted.first.id;
    }
    final defaults = _defaultActivePlanningIds();
    return defaults.isEmpty ? null : defaults.first;
  }

  Map<String, double> _autoDistributePlan({
    required double income,
    required double essentialPercent,
    required double futurePercent,
    required double freePercent,
    required Set<String> activeIds,
    required bool ownHome,
    required bool mealTicket,
    required bool noCar,
    required bool freeTransit,
    required bool hasHealthPlan,
  }) {
    final safeActiveIds = activeIds.isEmpty
        ? _defaultActivePlanningIds()
        : activeIds;
    final result = <String, double>{
      for (final category in _planningCategories) category.id: 0,
    };

    final essentialTotal = income * (essentialPercent / 100);
    final futureTotal = income * (futurePercent / 100);
    final freeTotal = income * (freePercent / 100);

    void distribute(FinancePlanningBucketKind bucket, double total) {
      final bucketCategories = _planningCategories.where((category) {
        return safeActiveIds.contains(category.id) &&
            FinancePlanningCatalog.bucketOf(category.id) == bucket;
      }).toList();

      final fallback = _planningCategories.where((category) {
        return FinancePlanningCatalog.bucketOf(category.id) == bucket &&
            FinancePlanningCatalog.starterFor(category.id);
      }).toList();

      final targets = bucketCategories.isEmpty ? fallback : bucketCategories;
      if (targets.isEmpty || total <= 0) return;

      final weights = <String, double>{};
      var totalWeight = 0.0;
      for (final category in targets) {
        final baseWeight = FinancePlanningCatalog.baseWeightFor(category.id);
        final profileWeight = FinancePlanningCatalog.profileMultiplier(
          category.id,
          ownHome: ownHome,
          mealTicket: mealTicket,
          noCar: noCar,
          freeTransit: freeTransit,
          hasHealthPlan: hasHealthPlan,
        );
        final weight = math.max(0.0, baseWeight * profileWeight).toDouble();
        if (weight <= 0) continue;
        weights[category.id] = weight;
        totalWeight += weight;
      }

      if (weights.isEmpty || totalWeight <= 0) return;

      var distributed = 0.0;
      final targetIds = weights.keys.toList();
      for (var index = 0; index < targetIds.length; index++) {
        final id = targetIds[index];
        final isLast = index == targetIds.length - 1;
        final value = isLast
            ? (total - distributed)
            : double.parse(
                (total * (weights[id]! / totalWeight)).toStringAsFixed(2),
              );
        result[id] = math.max(0.0, value).toDouble();
        distributed += result[id]!;
      }
    }

    distribute(FinancePlanningBucketKind.essential, essentialTotal);
    distribute(FinancePlanningBucketKind.future, futureTotal);
    distribute(FinancePlanningBucketKind.free, freeTotal);
    return result;
  }

  List<FinancePlanningBucket> _buildPlanningBuckets() {
    final values = _resolvedPlanValues();
    final activeCategories = _sortedPlanningCategories(
      _activePlanningCategoryIds.isEmpty
          ? _defaultActivePlanningIds()
          : _activePlanningCategoryIds,
    );

    final items = <FinancePlanningBucket>[];
    for (final category in activeCategories) {
      final amount = values[category.id] ?? 0;
      if (amount <= 0) continue;
      final bucket = FinancePlanningCatalog.bucketOf(category.id);
      items.add(
        FinancePlanningBucket(
          title: category.name,
          subtitle: FinancePlanningCatalog.bucketLabel(bucket),
          amount: amount,
          color: category.color,
        ),
      );
    }

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  Map<String, double> _buildPlanningSummary() {
    final income = _monthlyIncomePlan;
    final values = _resolvedPlanValues();
    double essential = 0;
    double future = 0;
    double free = 0;

    for (final category in _planningCategories) {
      final amount = values[category.id] ?? 0;
      switch (FinancePlanningCatalog.bucketOf(category.id)) {
        case FinancePlanningBucketKind.essential:
          essential += amount;
          break;
        case FinancePlanningBucketKind.future:
          future += amount;
          break;
        case FinancePlanningBucketKind.free:
          free += amount;
          break;
      }
    }

    return {
      'Renda planejada': income,
      'Essenciais': essential,
      'Investir + reserva': future,
      'Livre': free,
      'Sobra': math.max(0.0, income - (essential + future + free)).toDouble(),
    };
  }

  List<FinanceCategoryTotal> _buildCategoryTotals() {
    final byCategory = <String, FinanceCategoryTotal>{};

    for (final tx in _store.expenseTransactions) {
      final key = tx.category.id;
      final existing = byCategory[key];
      if (existing == null) {
        byCategory[key] = FinanceCategoryTotal(
          category: tx.category,
          total: tx.amount,
        );
      } else {
        byCategory[key] = FinanceCategoryTotal(
          category: existing.category,
          total: existing.total + tx.amount,
        );
      }
    }

    final list = byCategory.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  FinanceInvestmentViewData _buildInvestmentData() {
    final current = _investedCurrentValue;
    final principal = _investedPrincipal;
    final monthly = _monthlyInvestmentContribution;
    final annualRate = _annualInterestRate;
    final monthlyRate = annualRate <= 0 ? 0 : annualRate / 100 / 12;
    final earnings = math.max(0.0, current - principal).toDouble();
    final progress = _investmentTarget <= 0
        ? 0.0
        : (current / _investmentTarget).clamp(0.0, 1.0);

    final snapshots = <FinanceInvestmentSnapshot>[];
    for (final months in <int>[6, 12, 24, 60]) {
      double total = current;
      double principalPart = principal;
      for (int i = 0; i < months; i++) {
        total += monthly;
        principalPart += monthly;
        total *= (1 + monthlyRate);
      }
      snapshots.add(
        FinanceInvestmentSnapshot(
          label: months >= 12 ? '${months ~/ 12}a' : '${months}m',
          total: total,
          principal: principalPart,
          earnings: math.max(0.0, total - principalPart).toDouble(),
        ),
      );
    }

    int? monthsToTarget;
    if (_investmentTarget > 0 && current < _investmentTarget) {
      double total = current;
      int safety = 0;
      while (total < _investmentTarget && safety < 1200) {
        total += monthly;
        total *= (1 + monthlyRate);
        safety++;
      }
      if (safety < 1200) monthsToTarget = safety;
    }

    return FinanceInvestmentViewData(
      principal: principal,
      current: current,
      earnings: earnings,
      monthlyContribution: monthly,
      annualRate: annualRate,
      target: _investmentTarget,
      targetProgress: progress,
      monthsToTarget: monthsToTarget,
      snapshots: snapshots,
    );
  }

  Widget _buildPlanPreviewTile(FinancePlanningBucket bucket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111A1A),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: bucket.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucket.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  bucket.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCurrency(bucket.amount, hideValues: _hideValues),
            style: TextStyle(fontWeight: FontWeight.w800, color: bucket.color),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionSection() {
    final items = _buildCategoryTotals();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Leitura rápida',
          subtitle: _store.quickInsight,
          child: Column(
            children: [
              FinancePeriodChips(
                current: _store.selectedPeriod,
                onChanged: _store.setPeriod,
              ),
              const SizedBox(height: 12),
              Text(
                _store.periodComparisonText,
                style: TextStyle(color: Colors.white.withOpacity(0.72)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Gastos por categoria',
          subtitle:
              'Valores do período selecionado. Toque para ver os lançamentos.',
          child: Column(
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhuma saída registrada no período.'),
                )
              else
                ...items.take(6).map((item) {
                  final maxValue = items.first.total <= 0
                      ? 1.0
                      : items.first.total;
                  final progress = (item.total / maxValue).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openCategoryDetails(item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFF111A1A),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: item.category.color
                                      .withOpacity(0.18),
                                  child: Icon(
                                    item.category.icon,
                                    color: item.category.color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  formatCurrency(
                                    item.total,
                                    hideValues: _hideValues,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: Colors.white.withOpacity(0.06),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.category.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanningSection() {
    final summary = _buildPlanningSummary();
    final preview = _buildPlanningBuckets();
    final activeCategories = _sortedPlanningCategories(
      _activePlanningCategoryIds.isEmpty
          ? _defaultActivePlanningIds()
          : _activePlanningCategoryIds,
    );
    final lifeFlags = <String>[
      if (_planningOwnHome) 'Casa própria',
      if (_planningMealTicket) 'Vale alimentação',
      if (_planningNoCar) 'Sem carro',
      if (_planningFreeTransit) 'Passagem grátis',
      if (_planningHasHealthPlan) 'Plano de saúde',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Planejamento do mês',
          subtitle: 'O app sugere, mas você adapta ao seu jeito de viver.',
          trailing: TextButton.icon(
            onPressed: _openPlanningSheet,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Renda planejada',
                      value: formatCurrency(
                        summary['Renda planejada'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF9CFF3F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Essenciais',
                      value: formatCurrency(
                        summary['Essenciais'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF28C76F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Investir + reserva',
                      value: formatCurrency(
                        summary['Investir + reserva'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Livre',
                      value: formatCurrency(
                        summary['Livre'] ?? 0,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFFFFB020),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FinanceValueBadge(
                label: 'Sobra automática',
                value: formatCurrency(
                  summary['Sobra'] ?? 0,
                  hideValues: _hideValues,
                ),
                color: const Color(0xFF39D0FF),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Seu perfil do mês',
          subtitle: 'Esses atalhos mudam a divisão automática.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lifeFlags.isEmpty)
                Text(
                  'Nenhum atalho ligado. Toque em Editar para marcar casa própria, vale alimentação, sem carro e outros.',
                  style: TextStyle(color: Colors.white.withOpacity(0.72)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lifeFlags
                      .map((label) => Chip(label: Text(label)))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Categorias ativas do plano',
          subtitle: 'Só aparece forte aqui o que você realmente usa.',
          child: Column(
            children: [
              if (activeCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhuma categoria ativa ainda.'),
                )
              else
                ...activeCategories.take(8).map((category) {
                  final amount = (_resolvedPlanValues()[category.id] ?? 0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FinanceCategorySummaryTile(
                      icon: category.icon,
                      color: category.color,
                      title: category.name,
                      subtitle: FinancePlanningCatalog.bucketLabel(
                        FinancePlanningCatalog.bucketOf(category.id),
                      ),
                      trailing: formatCurrency(amount, hideValues: _hideValues),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Sugestão em ação',
          subtitle:
              'A divisão automática respeita as categorias ativas e o jeito que você vive.',
          child: Column(
            children: preview.take(6).map(_buildPlanPreviewTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestSection() {
    final data = _buildInvestmentData();
    final current = data.current <= 0 ? 1.0 : data.current;
    final principalRatio = (data.principal / current).clamp(0.0, 1.0);
    final earningsRatio = (data.earnings / current).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Investimentos',
          subtitle:
              'Seu dinheiro, rendimento e meta em uma leitura mais clara.',
          trailing: TextButton.icon(
            onPressed: _openInvestmentSheet,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Ajustar'),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Seu dinheiro',
                      value: formatCurrency(
                        data.principal,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF39D0FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Rendimento',
                      value: formatCurrency(
                        data.earnings,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFFFFB020),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Montante atual',
                      value: formatCurrency(
                        data.current,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceValueBadge(
                      label: 'Aporte mensal',
                      value: formatCurrency(
                        data.monthlyContribution,
                        hideValues: _hideValues,
                      ),
                      color: const Color(0xFF9CFF3F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Composição atual',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                        flex: math.max(1, (principalRatio * 1000).round()),
                        child: Container(color: const Color(0xFF39D0FF)),
                      ),
                      Expanded(
                        flex: math.max(1, (earningsRatio * 1000).round()),
                        child: Container(color: const Color(0xFFFFB020)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  FinanceLegendDot(
                    color: Color(0xFF39D0FF),
                    text: 'Seu dinheiro',
                  ),
                  SizedBox(width: 14),
                  FinanceLegendDot(
                    color: Color(0xFFFFB020),
                    text: 'Juros / rendimento',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (data.target > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Progresso até a meta',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ),
                    Text(
                      formatCurrency(data.target, hideValues: _hideValues),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: data.targetProgress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF6C63FF),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.monthsToTarget == null
                      ? 'Com os dados atuais, a meta ainda não foi alcançada.'
                      : 'Mantendo esse ritmo, a projeção chega na meta em cerca de ${data.monthsToTarget} meses.',
                  style: TextStyle(color: Colors.white.withOpacity(0.72)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Projeção visual',
          subtitle:
              'Comparação do seu dinheiro x rendimento ao longo do tempo.',
          child: Column(
            children: data.snapshots.map((snap) {
              final total = snap.total <= 0 ? 1.0 : snap.total;
              final ownRatio = (snap.principal / total).clamp(0.0, 1.0);
              final earnRatio = (snap.earnings / total).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF111A1A),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            snap.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            formatCurrency(snap.total, hideValues: _hideValues),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 12,
                          child: Row(
                            children: [
                              Expanded(
                                flex: math.max(1, (ownRatio * 1000).round()),
                                child: Container(
                                  color: const Color(0xFF39D0FF),
                                ),
                              ),
                              Expanded(
                                flex: math.max(1, (earnRatio * 1000).round()),
                                child: Container(
                                  color: const Color(0xFFFFB020),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seu dinheiro: ${formatCurrency(snap.principal, hideValues: _hideValues)}  •  Juros: ${formatCurrency(snap.earnings, hideValues: _hideValues)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.72)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildControlSection() {
    final items = _store.filteredTransactions.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionCard(
          title: 'Controle',
          subtitle: 'Aqui fica o lado mais detalhado do financeiro.',
          child: Column(
            children: [
              FinanceFilterChips(
                current: _store.selectedFilter,
                onChanged: _store.setFilter,
              ),
              const SizedBox(height: 12),
              FinancePeriodChips(
                current: _store.selectedPeriod,
                onChanged: _store.setPeriod,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FinanceCompactStatCard(
                      title: 'Registros',
                      value: _store.filteredTransactionCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FinanceCompactStatCard(
                      title: 'Top categoria',
                      value: _store.topExpenseCategory?.name ?? '—',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FinanceSectionCard(
          title: 'Lançamentos',
          subtitle: 'Últimos registros do filtro atual.',
          child: Column(
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Nenhum lançamento encontrado.'),
                )
              else
                ...items.map(
                  (tx) => FinanceTransactionTile(
                    transaction: tx,
                    amountLabel: formatCurrency(
                      tx.amount,
                      hideValues: _hideValues,
                    ),
                    dateLabel: formatShortDate(tx.date),
                    onEdit: () => _openEditTransactionPage(tx),
                    onDelete: () => _confirmRemoveTransaction(tx),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSection) {
      case 0:
        return _buildVisionSection();
      case 1:
        return _buildPlanningSection();
      case 2:
        return _buildInvestSection();
      case 3:
        return _buildControlSection();
      default:
        return _buildVisionSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddTransactionPage,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Lançar'),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
              children: [
                FinanceHeroCard(
                  title: 'Finanças',
                  subtitle: _financePeriodLabel(_store.selectedPeriod),
                  balanceLabel: 'Saldo disponível',
                  balanceValue: formatCurrency(
                    _store.balance,
                    hideValues: _hideValues,
                  ),
                  hideValues: _hideValues,
                  onTogglePrivacy: _loadingPrefs ? null : _togglePrivacy,
                  metrics: [
                    FinanceHeroMetric(
                      label: 'Entradas',
                      value: formatCurrency(
                        _store.totalIncome,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.call_received_rounded,
                      color: const Color(0xFF9CFF3F),
                    ),
                    FinanceHeroMetric(
                      label: 'Saídas',
                      value: formatCurrency(
                        _store.totalExpense,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.call_made_rounded,
                      color: const Color(0xFFFF5D73),
                    ),
                    FinanceHeroMetric(
                      label: 'Débito',
                      value: formatCurrency(
                        _store.totalDebitExpense,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF39D0FF),
                    ),
                    FinanceHeroMetric(
                      label: 'Crédito',
                      value: formatCurrency(
                        _store.totalCreditExpense,
                        hideValues: _hideValues,
                      ),
                      icon: Icons.credit_card_outlined,
                      color: const Color(0xFF6C63FF),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FinanceSectionTabs(
                  currentIndex: _currentSection,
                  onChanged: (index) => setState(() => _currentSection = index),
                ),
                const SizedBox(height: 14),
                _buildCurrentSection(),
              ],
            ),
          ),
        );
      },
    );
  }
}
