// ============================================================================
// FILE: lib/features/always_on/presentation/pages/always_on_tab.dart
//
// O que este arquivo faz:
// - Exibe o Sempre Ligado em tela cheia ou dentro do painel flutuante
// - Deixa o radar mais direto, mais pessoal e com menos texto inútil
// - Mostra primeiro o motivo de olhar, e só depois o texto complementar
// - Mantém personalização, refresh e leitura rápida das notícias
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vida_app/features/always_on/data/always_on_presets.dart';
import 'package:vida_app/features/always_on/data/always_on_repository.dart';
import 'package:vida_app/features/always_on/domain/always_on_models.dart';
import 'package:vida_app/features/always_on/presentation/pages/always_on_customize_page.dart';

class AlwaysOnTab extends StatefulWidget {
  const AlwaysOnTab({
    super.key,
    this.embedded = false,
    this.onMinimize,
    this.onOpenFinance,
  });

  final bool embedded;
  final VoidCallback? onMinimize;
  final VoidCallback? onOpenFinance;

  @override
  State<AlwaysOnTab> createState() => _AlwaysOnTabState();
}

class _AlwaysOnTabState extends State<AlwaysOnTab>
    with AutomaticKeepAliveClientMixin {
  final AlwaysOnRepository _repository = AlwaysOnRepository();

  late Future<AlwaysOnSnapshot> _future;
  bool _reloading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadSnapshot();
  }

  Future<void> _reload() async {
    if (_reloading) return;
    setState(() => _reloading = true);
    final future = _repository.loadSnapshot();
    setState(() => _future = future);
    try {
      await future;
    } finally {
      if (mounted) {
        setState(() => _reloading = false);
      }
    }
  }

  Future<void> _openCustomize(AlwaysOnSettings settings) async {
    final result = await Navigator.of(context).push<AlwaysOnSettings>(
      MaterialPageRoute(
        builder: (_) => AlwaysOnCustomizePage(initialSettings: settings),
      ),
    );

    if (result == null) return;

    await _repository.saveSettings(result);
    await _reload();
  }

  void _openArticle(AlwaysOnArticle article) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ArticleSheet(article: article),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final content = FutureBuilder<AlwaysOnSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const _LoadingView();
        }

        final data = snapshot.data;
        if (data == null) {
          return _ErrorView(onRetry: _reload);
        }

        final radarCount =
            data.settings.activePresetIds.length +
            data.settings.customTopics.length +
            data.settings.trackedTickers.length;

        return RefreshIndicator(
          color: const Color(0xFF22C55E),
          backgroundColor: const Color(0xFF0E1527),
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              widget.embedded ? 10 : 8,
              16,
              widget.embedded ? 18 : 28,
            ),
            children: [
              _PulseHeaderCard(
                snapshot: data,
                embedded: widget.embedded,
                reloading: _reloading,
                onRefresh: _reload,
                onCustomize: () => _openCustomize(data.settings),
                onMinimize: widget.onMinimize,
              ),
              const SizedBox(height: 14),
              _TopSignalCard(signal: data.topSignal),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.radar_rounded,
                      label: 'Radar',
                      value: '$radarCount',
                      subtitle: radarCount == 1 ? 'tema ativo' : 'temas ativos',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.priority_high_rounded,
                      label: 'Quentes',
                      value:
                          '${data.personalHighlights.where((item) => item.isHighPriority).length}',
                      subtitle: 'para ver primeiro',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStatCard(
                      icon: Icons.newspaper_rounded,
                      label: 'Blocos',
                      value: '${data.sections.length}',
                      subtitle: 'seguindo agora',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (radarCount > 0) ...[
                const _SectionTitle(
                  icon: Icons.tune_rounded,
                  title: 'Seu radar agora',
                  subtitle:
                      'O conteúdo daqui já está filtrado pelo que você escolheu',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...data.settings.activePresetIds.map((item) {
                      final preset = AlwaysOnPresets.byId(item);
                      return _TagChip(
                        icon: preset?.icon ?? Icons.radar_rounded,
                        label: preset?.title ?? item,
                      );
                    }),
                    ...data.settings.customTopics.map(
                      (item) =>
                          _TagChip(icon: Icons.interests_rounded, label: item),
                    ),
                    ...data.settings.trackedTickers.map(
                      (item) => _TagChip(
                        icon: Icons.candlestick_chart_rounded,
                        label: item.toUpperCase(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              if (data.personalHighlights.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Vale ver agora',
                  subtitle:
                      'O radar já separou o que parece mais importante para você',
                ),
                const SizedBox(height: 10),
                ...data.personalHighlights
                    .take(4)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HighlightCard(
                          article: item,
                          onTap: () => _openArticle(item),
                        ),
                      ),
                    ),
                const SizedBox(height: 10),
              ],
              if (data.marketQuotes.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.show_chart_rounded,
                  title: 'Pulso do mercado',
                  subtitle:
                      'Movimentos rápidos que chamam atenção sem sair do radar',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 176,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.marketQuotes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return _MarketCard(quote: data.marketQuotes[index]);
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
              ...data.sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CompactNewsSection(
                    section: section,
                    onArticleTap: _openArticle,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return Container(color: const Color(0xFF070D19), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sempre Ligado'),
        actions: [
          IconButton(
            tooltip: 'Personalizar',
            onPressed: () async {
              final settings = await _repository.loadSettings();
              if (!mounted) return;
              await _openCustomize(settings);
            },
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF22C55E)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF10182B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 34),
              const SizedBox(height: 14),
              const Text(
                'Não foi possível abrir o Sempre Ligado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tente atualizar novamente. O radar continua pronto para voltar assim que houver conexão.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseHeaderCard extends StatelessWidget {
  const _PulseHeaderCard({
    required this.snapshot,
    required this.embedded,
    required this.reloading,
    required this.onRefresh,
    required this.onCustomize,
    this.onMinimize,
  });

  final AlwaysOnSnapshot snapshot;
  final bool embedded;
  final bool reloading;
  final VoidCallback onRefresh;
  final VoidCallback onCustomize;
  final VoidCallback? onMinimize;

  String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary.replaceAll('\n', ' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF14253B), Color(0xFF0A1222)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF163425),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFF8BFF7C),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radar Vivo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Menos texto morto. Mais motivo para olhar.',
                      style: TextStyle(
                        color: Color(0xC8FFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (embedded && onMinimize != null) ...[
                _MiniGlassButton(
                  icon: Icons.remove_rounded,
                  onTap: onMinimize!,
                ),
                const SizedBox(width: 8),
              ],
              _MiniGlassButton(icon: Icons.tune_rounded, onTap: onCustomize),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: snapshot.usedFallback
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                            : const Color(0xFF22C55E).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: snapshot.usedFallback
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                              : const Color(0xFF22C55E).withValues(alpha: 0.24),
                        ),
                      ),
                      child: Text(
                        snapshot.usedFallback ? 'Modo local' : 'Atualizado',
                        style: TextStyle(
                          color: snapshot.usedFallback
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFF86EFAC),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'às ${_timeLabel(snapshot.loadedAt)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionPill(
                      icon: reloading
                          ? Icons.hourglass_top_rounded
                          : Icons.refresh_rounded,
                      label: reloading ? 'Atualizando' : 'Atualizar',
                      onTap: reloading ? null : onRefresh,
                    ),
                    const SizedBox(width: 8),
                    _ActionPill(
                      icon: Icons.tune_rounded,
                      label: 'Ajustar radar',
                      onTap: onCustomize,
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

class _TopSignalCard extends StatelessWidget {
  const _TopSignalCard({required this.signal});

  final String signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13281A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF8BFF7C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Por que isso vale seu tempo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  signal,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _MiniGlassButton extends StatelessWidget {
  const _MiniGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1527),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8BFF7C), size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8BFF7C), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8BFF7C), size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.quote});

  final AlwaysOnMarketQuote quote;

  @override
  Widget build(BuildContext context) {
    final accent = quote.isPositive
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return Container(
      width: 162,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.12), const Color(0xFF0E1527)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.code,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quote.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quote.priceLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.26)),
            ),
            child: Text(
              quote.changeLabel,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 28,
            child: CustomPaint(
              painter: _MiniLinePainter(values: quote.history, color: accent),
              size: const Size(double.infinity, 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  const _MiniLinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? 0.0
          : (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.article, required this.onTap});

  final AlwaysOnArticle article;
  final VoidCallback onTap;

  Color get _accent {
    switch (article.urgency) {
      case AlwaysOnUrgency.high:
        return const Color(0xFFEF4444);
      case AlwaysOnUrgency.medium:
        return const Color(0xFFF59E0B);
      case AlwaysOnUrgency.low:
        return const Color(0xFF22C55E);
    }
  }

  String get _badgeText {
    switch (article.urgency) {
      case AlwaysOnUrgency.high:
        return 'Importa agora';
      case AlwaysOnUrgency.medium:
        return 'Vale ver hoje';
      case AlwaysOnUrgency.low:
        return 'Pode acompanhar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2537), Color(0xFF10182B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _accent.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    _badgeText,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${article.source} • ${article.publishLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              article.shortReason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                article.whyItMatters,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactNewsSection extends StatelessWidget {
  const _CompactNewsSection({
    required this.section,
    required this.onArticleTap,
  });

  final AlwaysOnSection section;
  final ValueChanged<AlwaysOnArticle> onArticleTap;

  @override
  Widget build(BuildContext context) {
    final articles = section.items.cast<AlwaysOnArticle>().take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1527),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(section.icon, color: const Color(0xFF8BFF7C), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${section.items.length} itens',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...articles.map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ArticleTile(
                article: article,
                onTap: () => onArticleTap(article),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});

  final AlwaysOnArticle article;
  final VoidCallback onTap;

  Color get _accent {
    switch (article.urgency) {
      case AlwaysOnUrgency.high:
        return const Color(0xFFEF4444);
      case AlwaysOnUrgency.medium:
        return const Color(0xFFF59E0B);
      case AlwaysOnUrgency.low:
        return const Color(0xFF22C55E);
    }
  }

  String get _badgeText {
    switch (article.urgency) {
      case AlwaysOnUrgency.high:
        return 'Agora';
      case AlwaysOnUrgency.medium:
        return 'Hoje';
      case AlwaysOnUrgency.low:
        return 'Radar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _accent.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    _badgeText,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              article.shortReason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              article.whyItMatters,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${article.source} • ${article.publishLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleSheet extends StatelessWidget {
  const _ArticleSheet({required this.article});

  final AlwaysOnArticle article;

  Color get _accent {
    switch (article.urgency) {
      case AlwaysOnUrgency.high:
        return const Color(0xFFEF4444);
      case AlwaysOnUrgency.medium:
        return const Color(0xFFF59E0B);
      case AlwaysOnUrgency.low:
        return const Color(0xFF22C55E);
    }
  }

  String get _badgeText {
    switch (article.urgency) {
      case AlwaysOnUrgency.high:
        return 'Importa agora';
      case AlwaysOnUrgency.medium:
        return 'Vale ver hoje';
      case AlwaysOnUrgency.low:
        return 'Pode acompanhar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1120),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.sectionTitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    article.publishLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _accent.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    _badgeText,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                article.shortReason,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Por que isso pode valer seu tempo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.whyItMatters,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    color: Color(0xFF8BFF7C),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      article.source,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: article.link),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copiado.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar link'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
