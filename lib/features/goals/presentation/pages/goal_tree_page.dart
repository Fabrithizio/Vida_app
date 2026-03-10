// lib/features/goals/presentation/pages/goal_tree_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/goal_tree_models.dart';
import '../../goal_tree_store.dart';
import '../painter/goal_tree_painter.dart';
import '../widgets/reward_toast.dart';

class GoalTreePage extends StatefulWidget {
  const GoalTreePage({super.key, required this.store});

  final GoalTreeStore store;

  @override
  State<GoalTreePage> createState() => _GoalTreePageState();
}

class _GoalTreePageState extends State<GoalTreePage>
    with TickerProviderStateMixin {
  final TransformationController _xf = TransformationController();
  OverlayEntry? _rewardOverlay;

  static const Size worldSize = Size(1800, 900);
  static const double nodeRadius = 34;

  Offset? _downPos;
  DateTime? _downAt;

  @override
  void initState() {
    super.initState();
    widget.store.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOn(const Offset(260, 230), scale: 1.0);
    });
  }

  @override
  void dispose() {
    _rewardOverlay?.remove();
    _xf.dispose();
    super.dispose();
  }

  void _centerOn(Offset worldPoint, {double scale = 1.0}) {
    final size = MediaQuery.of(context).size;
    final dx = (size.width / 2) - worldPoint.dx * scale;
    final dy = (size.height / 2) - worldPoint.dy * scale;

    final m = Matrix4.identity();
    final s = m.storage;

    s[0] = scale;
    s[5] = scale;
    s[10] = scale;
    s[12] = dx;
    s[13] = dy;

    _xf.value = m;
  }

  Offset _toWorld(Offset viewportPoint) {
    final inv = Matrix4.copy(_xf.value);
    final det = inv.invert();
    if (det == 0) return viewportPoint;
    return MatrixUtils.transformPoint(inv, viewportPoint);
  }

  GoalNodeModel? _hitTestNode(Offset worldPoint, List<GoalNodeModel> nodes) {
    for (final node in nodes) {
      final d = (node.position - worldPoint).distance;
      if (d <= nodeRadius + 8) return node;
    }
    return null;
  }

  void _showRewardToast({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    _rewardOverlay?.remove();
    final overlay = Overlay.of(context);

    late final AnimationController c;
    c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final anim = CurvedAnimation(parent: c, curve: Curves.easeOutBack);

    final entry = OverlayEntry(
      builder: (context) {
        final topInset = MediaQuery.of(context).padding.top;
        return Positioned(
          left: 16,
          right: 16,
          top: topInset + 12,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final t = anim.value;
                return Opacity(
                  opacity: math.min(1, t * 1.1),
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * -12),
                    child: Transform.scale(
                      scale: 0.98 + t * 0.02,
                      child: child,
                    ),
                  ),
                );
              },
              child: RewardToastCard(
                title: title,
                subtitle: subtitle,
                icon: icon,
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _rewardOverlay = entry;

    c.forward().then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await c.reverse();
      entry.remove();
      if (mounted && _rewardOverlay == entry) _rewardOverlay = null;
      c.dispose();
    });
  }

  void _handleTap(Offset localTap, List<GoalNodeModel> nodes) {
    final world = _toWorld(localTap);
    final hit = _hitTestNode(world, nodes);
    if (hit == null) return;

    final st = widget.store.statuses[hit.id] ?? GoalNodeStatus.locked;

    if (st == GoalNodeStatus.available) {
      HapticFeedback.mediumImpact();
      final ok = widget.store.complete(hit.id);
      if (ok) {
        _showRewardToast(
          title: 'Meta concluída: ${hit.title}',
          subtitle: 'Recompensa: ${hit.rewardLabel}',
          icon: Icons.auto_awesome,
        );
      }
      return;
    }

    if (st == GoalNodeStatus.locked) {
      HapticFeedback.selectionClick();
      final missing = widget.store.missingParents(hit.id);
      final msg = missing.isEmpty
          ? 'Bloqueado.'
          : 'Complete antes: ${missing.map((m) => m.title).join(', ')}';
      _showRewardToast(title: hit.title, subtitle: msg, icon: Icons.lock);
      return;
    }

    HapticFeedback.selectionClick();
    _showRewardToast(
      title: hit.title,
      subtitle: 'Já concluído ✅  (${hit.rewardLabel})',
      icon: Icons.verified,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, child) {
        final s = widget.store.state;
        final nodes = s.nodes;
        final statuses = widget.store.statuses;

        final completed = s.completedIds.length;
        final total = nodes.length;
        final pct = total == 0 ? 0.0 : completed / total;

        return Scaffold(
          appBar: AppBar(
            title: Text(s.goalTitle),
            actions: [
              IconButton(
                tooltip: 'Centralizar',
                onPressed: () => _centerOn(const Offset(260, 230), scale: 1.0),
                icon: const Icon(Icons.my_location),
              ),
              IconButton(
                tooltip: 'Resetar progresso',
                onPressed: () async {
                  HapticFeedback.heavyImpact();
                  await widget.store.resetProgress(); // ✅ antes era reset()
                  _showRewardToast(
                    title: 'Progresso resetado',
                    subtitle: 'Você pode completar a árvore novamente.',
                    icon: Icons.restart_alt,
                  );
                },
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.1, -0.2),
                    radius: 1.2,
                    colors: [
                      Color(0xFF1A1D3A),
                      Color(0xFF0E1023),
                      Color(0xFF080A14),
                    ],
                  ),
                ),
              ),
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _downPos = e.localPosition;
                  _downAt = DateTime.now();
                },
                onPointerUp: (e) {
                  final dp = _downPos;
                  final dt = _downAt;
                  _downPos = null;
                  _downAt = null;

                  if (dp == null || dt == null) return;
                  final dist = (dp - e.localPosition).distance;
                  final elapsed = DateTime.now().difference(dt);

                  if (dist <= 8 && elapsed.inMilliseconds <= 350) {
                    _handleTap(e.localPosition, nodes);
                  }
                },
                child: InteractiveViewer(
                  transformationController: _xf,
                  minScale: 0.6,
                  maxScale: 2.6,
                  boundaryMargin: const EdgeInsets.all(600),
                  constrained: false,
                  child: SizedBox(
                    width: worldSize.width,
                    height: worldSize.height,
                    child: CustomPaint(
                      painter: GoalTreePainter(
                        nodes: nodes,
                        statuses: statuses,
                        nodeRadius: nodeRadius,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progresso',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 10,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            '$completed/$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
