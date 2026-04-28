// ============================================================================
// FILE: lib/features/areas/presentation/pages/areas_rpg_profile_page.dart
//
// O que faz:
// - Abre a ficha RPG completa do usuário a partir do botão de perfil do Areas
// - Mostra classe, rank, atributos, dado adaptativo e livro de regras
// - Agora salva histórico diário e mostra evolução vs ontem
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vida_app/features/areas/application/profile/areas_rpg_profile_engine.dart';
import 'package:vida_app/features/areas/application/profile/areas_rpg_profile_history_service.dart'
    as rpg_history;
import 'package:vida_app/features/areas/application/profile/areas_rpg_profile_models.dart';

class AreasRpgProfilePage extends StatefulWidget {
  const AreasRpgProfilePage({
    super.key,
    required this.userName,
    required this.areaScores,
  });

  final String userName;
  final Map<String, int?> areaScores;

  @override
  State<AreasRpgProfilePage> createState() => _AreasRpgProfilePageState();
}

class _AreasRpgProfilePageState extends State<AreasRpgProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _diceController;
  late final Animation<double> _rotation;
  late Future<_RpgPageData> _future;

  final rpg_history.AreasRpgProfileHistoryService _history =
      rpg_history.AreasRpgProfileHistoryService();

  int? _rolledValue;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _rotation = CurvedAnimation(
      parent: _diceController,
      curve: Curves.easeOutCubic,
    );
    _future = _load();
  }

  Future<_RpgPageData> _load() async {
    final snapshot = await AreasRpgProfileEngine().build(
      userName: widget.userName,
      areaScores: widget.areaScores,
    );
    await _history.saveDailySnapshot(snapshot);
    final evolution = await _history.buildEvolution(snapshot);
    return _RpgPageData(snapshot: snapshot, evolution: evolution);
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  Future<void> _rollDice(
    AreasRpgProfileSnapshot snapshot, {
    _RollMode mode = _RollMode.normal,
  }) async {
    final rng = math.Random();
    await _diceController.forward(from: 0);

    int oneRoll() =>
        snapshot.dice.sanitizeRoll(rng.nextInt(snapshot.dice.diceSides) + 1);

    int safe;
    switch (mode) {
      case _RollMode.normal:
        safe = oneRoll();
        break;
      case _RollMode.advantage:
        safe = math.max(oneRoll(), oneRoll());
        break;
      case _RollMode.disadvantage:
        safe = math.min(oneRoll(), oneRoll());
        break;
    }

    if (!mounted) return;
    setState(() => _rolledValue = safe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Perfil RPG'),
      ),
      body: FutureBuilder<_RpgPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final rpg = data.snapshot;
          final evolution = data.evolution;
          final mainColor = rpg.attributes
              .reduce((a, b) => a.value >= b.value ? a : b)
              .type
              .accent;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HeroHeader(snapshot: rpg, accent: mainColor),
              const SizedBox(height: 14),
              _EvolutionCard(evolution: evolution),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _DiceCard(
                      snapshot: rpg,
                      rolledValue: _rolledValue,
                      rotation: _rotation,
                      onRollNormal: () => _rollDice(rpg),
                      onRollAdvantage: () =>
                          _rollDice(rpg, mode: _RollMode.advantage),
                      onRollDisadvantage: () =>
                          _rollDice(rpg, mode: _RollMode.disadvantage),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: _ClassCard(snapshot: rpg)),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Atributos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ...rpg.attributes.map((e) {
                final delta = evolution.attributeDeltas.firstWhere(
                  (item) => item.type == e.type,
                );
                return _AttributeTile(score: e, delta: delta.delta);
              }),
              const SizedBox(height: 14),
              _RulesBookCard(rules: rpg.rules),
            ],
          );
        },
      ),
    );
  }
}

enum _RollMode { normal, advantage, disadvantage }

class _RpgPageData {
  const _RpgPageData({required this.snapshot, required this.evolution});

  final AreasRpgProfileSnapshot snapshot;
  final rpg_history.AreasRpgEvolution evolution;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.snapshot, required this.accent});

  final AreasRpgProfileSnapshot snapshot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.18), const Color(0xFF101420)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.85),
                  accent.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(snapshot.archetype.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.archetype.label} • ${snapshot.rankLabel}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.archetype.fantasySummary,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniBadge(
                      label: 'Poder ${snapshot.totalPower}',
                      color: accent,
                    ),
                    _MiniBadge(
                      label: snapshot.classificationLabel,
                      color: Colors.white70,
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EvolutionCard extends StatelessWidget {
  const _EvolutionCard({required this.evolution});

  final rpg_history.AreasRpgEvolution evolution;

  Color _deltaColor(int delta) {
    if (delta > 0) return const Color(0xFF22C55E);
    if (delta < 0) return const Color(0xFFEF4444);
    return const Color(0xFF94A3B8);
  }

  String _deltaLabel(int delta) {
    if (delta > 0) return '+$delta';
    return '$delta';
  }

  @override
  Widget build(BuildContext context) {
    if (evolution.previous == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D111C),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'Esta é a primeira leitura salva da sua ficha RPG. A evolução diária começa a aparecer amanhã.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
      );
    }

    final highlights = evolution.attributeDeltas
        .where((e) => e.changed)
        .take(3)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evolução desde a última leitura',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                label: 'Poder ${_deltaLabel(evolution.powerDelta)}',
                color: _deltaColor(evolution.powerDelta),
              ),
              _MiniBadge(
                label: 'Piso do dado ${_deltaLabel(evolution.diceFloorDelta)}',
                color: _deltaColor(evolution.diceFloorDelta),
              ),
              _MiniBadge(
                label: 'Teto do dado ${_deltaLabel(evolution.diceCeilDelta)}',
                color: _deltaColor(evolution.diceCeilDelta),
              ),
              if (evolution.classChanged)
                const _MiniBadge(
                  label: 'Classe mudou',
                  color: Color(0xFFF59E0B),
                ),
              if (evolution.rankChanged)
                const _MiniBadge(label: 'Rank mudou', color: Color(0xFF8B5CF6)),
            ],
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...highlights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item.type.label}: ${_deltaLabel(item.delta)}',
                  style: TextStyle(
                    color: _deltaColor(item.delta),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiceCard extends StatelessWidget {
  const _DiceCard({
    required this.snapshot,
    required this.rolledValue,
    required this.rotation,
    required this.onRollNormal,
    required this.onRollAdvantage,
    required this.onRollDisadvantage,
  });

  final AreasRpgProfileSnapshot snapshot;
  final int? rolledValue;
  final Animation<double> rotation;
  final VoidCallback onRollNormal;
  final VoidCallback onRollAdvantage;
  final VoidCallback onRollDisadvantage;

  @override
  Widget build(BuildContext context) {
    final accent = Colors.amberAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.dice.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.dice.reason,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 14),
          Center(
            child: AnimatedBuilder(
              animation: rotation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: rotation.value * 8 * math.pi,
                  child: child,
                );
              },
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.90),
                      const Color(0xFFFF8C00),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${rolledValue ?? '?'}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Faixa do dia: ${snapshot.dice.minimumRoll} ~ ${snapshot.dice.maximumRoll}',
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Vantagem: ${snapshot.dice.advantageLabel}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Risco: ${snapshot.dice.riskLabel}',
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRollNormal,
              icon: const Icon(Icons.casino_rounded),
              label: const Text('Rolar normal'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRollAdvantage,
                  child: const Text('Vantagem'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onRollDisadvantage,
                  child: const Text('Desvantagem'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.snapshot});

  final AreasRpgProfileSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final accent = snapshot.attributes
        .reduce((a, b) => a.value >= b.value ? a : b)
        .type
        .accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Classe',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.18),
                child: Icon(snapshot.archetype.icon, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  snapshot.archetype.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            snapshot.archetype.fantasySummary,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            'Forças: ${snapshot.archetype.strengths.join(', ')}',
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AttributeTile extends StatelessWidget {
  const _AttributeTile({required this.score, required this.delta});

  final RpgAttributeScore score;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final color = score.type.accent;
    final deltaColor = delta > 0
        ? const Color(0xFF22C55E)
        : delta < 0
        ? const Color(0xFFEF4444)
        : Colors.white54;

    final deltaText = delta > 0 ? '+$delta' : '$delta';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D111C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(score.type.icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.type.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score.reason,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.value}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                  ),
                ),
                Text(
                  score.tierLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesBookCard extends StatefulWidget {
  const _RulesBookCard({required this.rules});

  final List<RpgRulesBookSection> rules;

  @override
  State<_RulesBookCard> createState() => _RulesBookCardState();
}

class _RulesBookCardState extends State<_RulesBookCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: Colors.amber),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Livro de regras',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: widget.rules
                    .map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...section.points.map(
                                (point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '• ',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            height: 1.35,
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
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}
