// ============================================================================
// FILE: lib/features/always_on/presentation/pages/always_on_tab.dart
//
// O que este arquivo faz:
// - Exibe o Sempre Ligado em tela cheia ou dentro do painel flutuante
// - Melhora a leitura com cards mais compactos e menos texto pesado
// - Corrige o bug final de overflow nos cards de mercado
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vida_app/features/always_on/data/always_on_presets.dart';
import 'package:vida_app/features/always_on/data/always_on_repository.dart';
import 'package:vida_app/features/always_on/domain/always_on_models.dart';
import 'package:vida_app/features/always_on/presentation/pages/always_on_customize_page.dart';
import 'package:vida_app/features/finance/presentation/pages/finance_tab.dart';

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

  Future<void> _openFinance() async {
    if (widget.onOpenFinance != null) {
      widget.onOpenFinance!.call();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FinanceTab()));
  }

  void _openArticle(AlwaysOnArticle article) {
    showModalBottomSheet<void>(
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
              _HeaderCard(
                snapshot: data,
                embedded: widget.embedded,
                reloading: _reloading,
                onRefresh: _reload,
                onCustomize: () => _openCustomize(data.settings),
                onOpenFinance: _openFinance,
              ),
              const SizedBox(height: 14),
              if (data.marketQuotes.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.bolt_rounded,
                  title: 'Mercado rápido',
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 184,
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
              if (data.settings.activePresetIds.isNotEmpty ||
                  data.settings.customTopics.isNotEmpty ||
                  data.settings.trackedTickers.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.tune_rounded,
                  title: 'Seu radar',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...data.settings.activePresetIds.map((item) {
                      final preset = AlwaysOnPresets.byId(item);
                      return _TagChip(label: preset?.title ?? item);
                    }),
                    ...data.settings.customTopics.map(
                      (item) => _TagChip(label: item),
                    ),
                    ...data.settings.trackedTickers.map(
                      (item) => _TagChip(label: item),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              if (data.personalHighlights.isNotEmpty) ...[
                const _SectionTitle(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Para você hoje',
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
                const SizedBox(height: 8),
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
              const SizedBox(height: 4),
              _FinanceQuickCard(onTap: _openFinance),
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
                'Tente atualizar novamente. Se a rede falhar, o radar pode voltar no modo local.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.snapshot,
    required this.embedded,
    required this.reloading,
    required this.onRefresh,
    required this.onCustomize,
    required this.onOpenFinance,
  });

  final AlwaysOnSnapshot snapshot;
  final bool embedded;
  final bool reloading;
  final Future<void> Function() onRefresh;
  final VoidCallback onCustomize;
  final VoidCallback onOpenFinance;

  @override
  Widget build(BuildContext context) {
    final time =
        '${_twoDigits(snapshot.loadedAt.hour)}:${_twoDigits(snapshot.loadedAt.minute)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF131C33), Color(0xFF0A1120)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded) ...[
            Text(
              'Sempre Ligado',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Seu radar pessoal de atualidade, contexto e interesses.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _TopBadge(
                  icon: Icons.article_rounded,
                  text: '${snapshot.totalItems} itens',
                ),
                const SizedBox(width: 8),
                _TopBadge(
                  icon: Icons.interests_rounded,
                  text:
                      '${snapshot.settings.activePresetIds.length + snapshot.settings.customTopics.length} interesses',
                ),
                const SizedBox(width: 8),
                _TopBadge(
                  icon: snapshot.usedFallback
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  text: snapshot.usedFallback ? 'Modo local' : 'Online',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumo do momento',
                  style: TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Atualizado às $time',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ActionPill(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Finanças',
                  onTap: onOpenFinance,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: reloading ? Icons.sync : Icons.refresh_rounded,
                  label: reloading ? 'Atualizando' : 'Atualizar',
                  onTap: reloading ? null : () async => onRefresh(),
                  spinning: reloading,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.tune_rounded,
                  label: 'Personalizar',
                  onTap: onCustomize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.spinning = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              spinning
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF17233D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
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

    return SizedBox(
      width: 166,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quote.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              quote.priceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quote.changeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: quote.history,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                quote.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.article, required this.onTap});

  final AlwaysOnArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLink = article.link.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallInfoChip(label: article.source),
                _SmallInfoChip(label: article.publishLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _SmallInfoChip(label: article.sectionTitle)),
                const SizedBox(width: 10),
                Text(
                  hasLink ? 'Abrir' : 'Detalhes',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
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
  final void Function(AlwaysOnArticle article) onArticleTap;

  @override
  Widget build(BuildContext context) {
    final items = section.items.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10182B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(section.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${items.length} itens',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompactArticleRow(
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

class _CompactArticleRow extends StatelessWidget {
  const _CompactArticleRow({required this.article, required this.onTap});

  final AlwaysOnArticle article;
  final VoidCallback onTap;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF17233D),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.article_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    article.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          article.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        article.publishLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _FinanceQuickCard extends StatelessWidget {
  const _FinanceQuickCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF10182B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF17233D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abrir Finanças',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ir direto para a área completa sem perder o radar rápido.',
                    style: TextStyle(
                      color: Color(0xBEFFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  const _SmallInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.80),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ArticleSheet extends StatelessWidget {
  const _ArticleSheet({required this.article});

  final AlwaysOnArticle article;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1221),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
                      article.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InlineChip(label: article.source),
                  _InlineChip(label: article.publishLabel),
                  _InlineChip(label: article.sectionTitle),
                ],
              ),
              const SizedBox(height: 16),
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
                child: Text(
                  article.summary,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              if (article.link.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: article.link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Link copiado para a área de transferência.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar link'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final safeValues = values.isEmpty ? const [1.0, 1.0] : values;
    final minValue = safeValues.reduce((a, b) => a < b ? a : b);
    final maxValue = safeValues.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : (maxValue - minValue);

    final path = Path();
    for (var i = 0; i < safeValues.length; i++) {
      final dx = safeValues.length == 1
          ? 0.0
          : (i / (safeValues.length - 1)) * size.width;
      final normalized = (safeValues[i] - minValue) / span;
      final dy = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
