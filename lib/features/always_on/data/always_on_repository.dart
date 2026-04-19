// ============================================================================
// FILE: lib/features/always_on/data/always_on_repository.dart
//
// O que este arquivo faz:
// - Carrega e salva as preferências do Sempre Ligado
// - Busca notícias públicas por RSS e cotações públicas de mercado
// - Monta o snapshot final consumido pela interface
// - Prioriza o que parece mais útil e mais urgente para o usuário
// - Garante fallback por seção quando a internet falhar ou vier vazia
// ============================================================================

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/always_on/data/always_on_presets.dart';
import 'package:vida_app/features/always_on/domain/always_on_models.dart';

class AlwaysOnRepository {
  static const _activePresetIdsKey = 'always_on_active_presets';
  static const _customTopicsKey = 'always_on_custom_topics';
  static const _trackedTickersKey = 'always_on_tracked_tickers';

  Future<AlwaysOnSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final activePresetIds = _readStringList(prefs, _activePresetIdsKey);
    final customTopics = _readStringList(prefs, _customTopicsKey);
    final trackedTickers = _readStringList(prefs, _trackedTickersKey);

    if (activePresetIds.isEmpty &&
        customTopics.isEmpty &&
        trackedTickers.isEmpty) {
      return AlwaysOnSettings.defaults;
    }

    return AlwaysOnSettings(
      activePresetIds: activePresetIds.isEmpty
          ? AlwaysOnSettings.defaults.activePresetIds
          : activePresetIds,
      customTopics: customTopics,
      trackedTickers: trackedTickers,
    );
  }

  Future<void> saveSettings(AlwaysOnSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedKey(_activePresetIdsKey),
      settings.activePresetIds,
    );
    await prefs.setStringList(
      _scopedKey(_customTopicsKey),
      settings.customTopics,
    );
    await prefs.setStringList(
      _scopedKey(_trackedTickersKey),
      settings.trackedTickers,
    );
  }

  Future<AlwaysOnSnapshot> loadSnapshot() async {
    final settings = await loadSettings();

    List<AlwaysOnMarketQuote> marketQuotes = const [];
    List<AlwaysOnSection> sections = const [];
    var usedFallback = false;

    try {
      marketQuotes = await _loadMarketQuotes();
    } catch (_) {
      marketQuotes = _fallbackMarketQuotes();
      usedFallback = true;
    }

    try {
      sections = await _loadSections(settings);
      if (sections.isEmpty) {
        sections = _fallbackSections(settings);
        usedFallback = true;
      } else {
        sections = _mergeMissingFallbackSections(settings, sections);
      }
    } catch (_) {
      sections = _fallbackSections(settings);
      usedFallback = true;
    }

    final highlights = _buildHighlights(sections);
    final summary = _buildSummary(settings, sections, marketQuotes, highlights);
    final topSignal = _buildTopSignal(highlights, settings);

    return AlwaysOnSnapshot(
      settings: settings,
      summary: summary,
      marketQuotes: marketQuotes,
      sections: sections,
      personalHighlights: highlights,
      loadedAt: DateTime.now(),
      usedFallback: usedFallback,
      topSignal: topSignal,
    );
  }

  List<String> _readStringList(SharedPreferences prefs, String key) {
    final values = prefs.getStringList(_scopedKey(key)) ?? const <String>[];
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _scopedKey(String key) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return key;
    return '$uid:$key';
  }

  Future<List<AlwaysOnMarketQuote>> _loadMarketQuotes() async {
    final latestUrl = Uri.parse(
      'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL,BTC-BRL,ETH-BRL',
    );

    final latestRaw = await _fetchString(latestUrl);
    final latestData = jsonDecode(latestRaw) as Map<String, dynamic>;

    final historyUrls = <String, Uri>{
      'USDBRL': Uri.parse(
        'https://economia.awesomeapi.com.br/json/daily/USD-BRL/7',
      ),
      'EURBRL': Uri.parse(
        'https://economia.awesomeapi.com.br/json/daily/EUR-BRL/7',
      ),
      'BTCBRL': Uri.parse(
        'https://economia.awesomeapi.com.br/json/daily/BTC-BRL/7',
      ),
      'ETHBRL': Uri.parse(
        'https://economia.awesomeapi.com.br/json/daily/ETH-BRL/7',
      ),
    };

    final historyMap = <String, List<double>>{};
    for (final entry in historyUrls.entries) {
      try {
        final raw = await _fetchString(entry.value);
        final decoded = jsonDecode(raw) as List<dynamic>;
        historyMap[entry.key] = decoded
            .map<double>((item) {
              final map = item as Map<String, dynamic>;
              return double.tryParse('${map['bid'] ?? map['ask'] ?? '0'}') ?? 0;
            })
            .where((value) => value > 0)
            .toList()
            .reversed
            .toList();
      } catch (_) {
        historyMap[entry.key] = const <double>[];
      }
    }

    final configs = <String, ({String code, String title})>{
      'USDBRL': (code: 'USD/BRL', title: 'Dólar'),
      'EURBRL': (code: 'EUR/BRL', title: 'Euro'),
      'BTCBRL': (code: 'BTC/BRL', title: 'Bitcoin'),
      'ETHBRL': (code: 'ETH/BRL', title: 'Ethereum'),
    };

    final quotes = <AlwaysOnMarketQuote>[];

    for (final entry in configs.entries) {
      final raw = latestData[entry.key] as Map<String, dynamic>?;
      if (raw == null) continue;

      final bid = double.tryParse('${raw['bid'] ?? '0'}') ?? 0;
      final change = double.tryParse('${raw['pctChange'] ?? '0'}') ?? 0;

      quotes.add(
        AlwaysOnMarketQuote(
          code: entry.value.code,
          title: entry.value.title,
          priceLabel: _formatMoney(bid),
          changePercent: change,
          changeLabel: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
          history: historyMap[entry.key] ?? const <double>[],
        ),
      );
    }

    quotes.sort(
      (a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()),
    );
    return quotes;
  }

  Future<List<AlwaysOnSection>> _loadSections(AlwaysOnSettings settings) async {
    final sections = <AlwaysOnSection>[];

    for (final presetId in settings.activePresetIds) {
      final preset = AlwaysOnPresets.byId(presetId);
      if (preset == null) continue;

      final articles = await _loadRssSection(
        sectionId: preset.id,
        sectionTitle: preset.title,
        query: preset.query,
      );

      sections.add(
        AlwaysOnSection(
          id: preset.id,
          title: preset.title,
          icon: preset.icon,
          items: articles.isEmpty
              ? _fallbackArticlesForPreset(preset)
              : articles,
        ),
      );
    }

    for (final topic in settings.customTopics) {
      final articles = await _loadRssSection(
        sectionId: 'custom-${topic.toLowerCase()}',
        sectionTitle: topic,
        query: topic,
      );

      sections.add(
        AlwaysOnSection(
          id: 'custom-${topic.toLowerCase()}',
          title: topic,
          icon: Icons.interests_rounded,
          items: articles.isEmpty
              ? _fallbackArticlesForCustomTopic(topic)
              : articles,
        ),
      );
    }

    for (final ticker in settings.trackedTickers) {
      final articles = await _loadRssSection(
        sectionId: 'ticker-${ticker.toLowerCase()}',
        sectionTitle: ticker.toUpperCase(),
        query: '${ticker.toUpperCase()} bolsa OR ações OR mercado',
      );

      sections.add(
        AlwaysOnSection(
          id: 'ticker-${ticker.toLowerCase()}',
          title: ticker.toUpperCase(),
          icon: Icons.candlestick_chart_rounded,
          items: articles.isEmpty
              ? _fallbackArticlesForTicker(ticker)
              : articles,
        ),
      );
    }

    return sections.where((section) => section.items.isNotEmpty).toList();
  }

  Future<List<AlwaysOnArticle>> _loadRssSection({
    required String sectionId,
    required String sectionTitle,
    required String query,
  }) async {
    final rssUrl = Uri.parse(
      'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=pt-BR&gl=BR&ceid=BR:pt-419',
    );

    final raw = await _fetchString(rssUrl);
    final items = _extractBlocks(raw, 'item');

    final mapped = items
        .take(6)
        .map((item) {
          final fullTitle = _decodeXml(_readTag(item, 'title'));
          final link = _readTag(item, 'link');
          final pubDate = _readTag(item, 'pubDate');

          final titleParts = fullTitle.split(' - ');
          final source = titleParts.length > 1
              ? titleParts.last.trim()
              : _decodeXml(_readTag(item, 'source')).trim();

          final title = titleParts.length > 1
              ? titleParts.sublist(0, titleParts.length - 1).join(' - ').trim()
              : fullTitle.trim();

          final cleanTitle = title.isEmpty ? fullTitle : title;
          final score = _scoreArticle(sectionTitle, cleanTitle);
          final urgency = _urgencyForTitle(sectionTitle, cleanTitle);

          return AlwaysOnArticle(
            id: '${sectionId}_${link.hashCode}',
            title: cleanTitle,
            source: source.isEmpty ? 'Fonte pública' : source,
            sectionId: sectionId,
            sectionTitle: sectionTitle,
            link: link.trim(),
            summary: _buildArticleSummary(sectionTitle, cleanTitle),
            publishLabel: _normalizePublishLabel(pubDate),
            shortReason: _buildShortReason(sectionTitle, cleanTitle, urgency),
            whyItMatters: _buildWhyItMatters(sectionTitle, cleanTitle, urgency),
            urgency: urgency,
            relevanceScore: score,
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList();

    mapped.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return mapped.take(5).toList();
  }

  List<AlwaysOnArticle> _buildHighlights(List<AlwaysOnSection> sections) {
    final items = <AlwaysOnArticle>[];
    final seen = <String>{};

    for (final section in sections) {
      for (final article in section.items) {
        final key = article.title.toLowerCase();
        if (!seen.add(key)) continue;
        items.add(article);
      }
    }

    items.sort((a, b) {
      final urgencyCompare = b.urgency.index.compareTo(a.urgency.index);
      if (urgencyCompare != 0) return urgencyCompare;
      return b.relevanceScore.compareTo(a.relevanceScore);
    });

    return items.take(6).toList();
  }

  String _buildSummary(
    AlwaysOnSettings settings,
    List<AlwaysOnSection> sections,
    List<AlwaysOnMarketQuote> marketQuotes,
    List<AlwaysOnArticle> highlights,
  ) {
    if (sections.isEmpty) {
      return 'Seu radar está pronto, mas ainda não encontrou algo realmente forte para mostrar agora.';
    }

    final themes =
        settings.activePresetIds.length +
        settings.customTopics.length +
        settings.trackedTickers.length;
    final strongest = highlights.isEmpty ? null : highlights.first;
    final marketPulse = marketQuotes.isEmpty
        ? ''
        : ' Mercado mexendo mais com ${marketQuotes.first.title.toLowerCase()}.';

    if (strongest == null) {
      return '$themes interesses ligados e ${sections.length} blocos ativos.$marketPulse';
    }

    return '$themes interesses ligados. O que mais parece valer seu tempo agora: ${strongest.shortReason}.$marketPulse';
  }

  String _buildTopSignal(
    List<AlwaysOnArticle> highlights,
    AlwaysOnSettings settings,
  ) {
    if (highlights.isNotEmpty) {
      return highlights.first.shortReason;
    }

    if (settings.isEmpty) {
      return 'Ligue alguns interesses para o radar começar a ficar mais a sua cara.';
    }

    return 'Seu radar está ativo. Falta só chegar algo novo que realmente combine com você.';
  }

  String _buildArticleSummary(String sectionTitle, String title) {
    switch (sectionTitle.toLowerCase()) {
      case 'mercado':
        return 'Movimento de mercado com possível impacto em preço, risco ou oportunidade.';
      case 'mundo':
        return 'Acontecimento externo que pode mudar ambiente econômico, político ou social.';
      case 'tecnologia':
        return 'Mudança em produto, IA ou internet que pode alterar rotina, trabalho ou atenção.';
      case 'política':
        return 'Tema público com chance de afetar bolso, regras ou clima do país.';
      case 'saúde':
        return 'Informação de saúde e bem-estar com efeito prático no dia a dia.';
      case 'estudos':
        return 'Conteúdo útil para aprender melhor, produzir mais ou evoluir na carreira.';
      default:
        return 'Resumo rápido do que aconteceu e por que isso pode valer sua atenção.';
    }
  }

  String _buildShortReason(
    String sectionTitle,
    String title,
    AlwaysOnUrgency urgency,
  ) {
    final tone = urgency == AlwaysOnUrgency.high
        ? 'Vale olhar agora'
        : urgency == AlwaysOnUrgency.medium
        ? 'Pode te interessar hoje'
        : 'Bom para acompanhar';

    switch (sectionTitle.toLowerCase()) {
      case 'mercado':
        return '$tone: isso pode mexer com preço, risco ou oportunidade';
      case 'mundo':
        return '$tone: tema externo com possível efeito em economia e humor do mercado';
      case 'tecnologia':
        return '$tone: mudança que pode impactar rotina digital, trabalho ou atenção';
      case 'fé':
        return '$tone: conteúdo de reflexão e contexto do meio cristão';
      case 'política':
        return '$tone: decisão pública que pode bater no bolso ou nas regras';
      case 'saúde':
        return '$tone: informação com efeito em energia, prevenção ou qualidade de vida';
      case 'esportes':
        return '$tone: destaque esportivo que tende a puxar repercussão';
      case 'cultura':
        return '$tone: assunto cultural que está ganhando tração';
      case 'estudos':
        return '$tone: tema útil para aprender melhor e evoluir';
      default:
        return '$tone: isso tem a ver com seu radar';
    }
  }

  String _buildWhyItMatters(
    String sectionTitle,
    String title,
    AlwaysOnUrgency urgency,
  ) {
    switch (sectionTitle.toLowerCase()) {
      case 'mercado':
        return urgency == AlwaysOnUrgency.high
            ? 'Pode influenciar preço, risco percebido e até decisões de entrada, espera ou proteção.'
            : 'Ajuda a entender se o cenário está abrindo oportunidade ou pedindo mais cautela.';
      case 'mundo':
        return 'Mesmo quando parece longe, esse tipo de notícia pode alterar humor do mercado, dólar, inflação ou narrativa pública.';
      case 'tecnologia':
        return 'Pode mexer no seu jeito de trabalhar, aprender, produzir ou até no que vale sua atenção hoje.';
      case 'fé':
        return 'Pode ser um ponto de reflexão, contexto do meio cristão ou tema que conversa com seus valores.';
      case 'política':
        return 'Pode afetar regras, impostos, percepção de risco e decisões do dia a dia.';
      case 'saúde':
        return 'Pode influenciar prevenção, disposição, sono, foco ou escolhas de rotina.';
      case 'esportes':
        return 'É o tipo de assunto que pode dominar conversa, repercussão e interesse coletivo rapidamente.';
      case 'cultura':
        return 'Ajuda a não perder o que está puxando assunto, referência e tendência cultural.';
      case 'estudos':
        return 'Pode melhorar sua forma de aprender, organizar tempo e crescer com mais clareza.';
      default:
        return 'Esse assunto conversa com o que você escolheu seguir no radar.';
    }
  }

  int _scoreArticle(String sectionTitle, String title) {
    final lower = title.toLowerCase();
    var score = 10;

    const hotWords = [
      'alerta',
      'urgente',
      'dispara',
      'cai',
      'sobe',
      'recorde',
      'aprova',
      'suspende',
      'ban',
      'novo',
      'lança',
      'crise',
      'ataque',
      'guerra',
      'tarifa',
      'juros',
      'ia',
      'bitcoin',
      'dólar',
      'inflação',
    ];

    for (final word in hotWords) {
      if (lower.contains(word)) score += 6;
    }

    switch (sectionTitle.toLowerCase()) {
      case 'mercado':
      case 'política':
      case 'tecnologia':
        score += 8;
        break;
      case 'saúde':
      case 'estudos':
        score += 5;
        break;
      default:
        score += 3;
    }

    if (lower.contains('?')) score -= 2;
    if (lower.length > 110) score -= 2;

    return score;
  }

  AlwaysOnUrgency _urgencyForTitle(String sectionTitle, String title) {
    final lower = title.toLowerCase();

    const highSignals = [
      'alerta',
      'urgente',
      'dispara',
      'desaba',
      'ataque',
      'guerra',
      'crise',
      'aprova',
      'proíbe',
      'suspende',
      'tarifa',
      'inflação',
      'juros',
      'recorde',
    ];

    for (final word in highSignals) {
      if (lower.contains(word)) return AlwaysOnUrgency.high;
    }

    if (sectionTitle.toLowerCase() == 'mercado' &&
        (lower.contains('dólar') ||
            lower.contains('bitcoin') ||
            lower.contains('selic') ||
            lower.contains('juros'))) {
      return AlwaysOnUrgency.high;
    }

    if (sectionTitle.toLowerCase() == 'tecnologia' &&
        (lower.contains('ia') ||
            lower.contains('openai') ||
            lower.contains('google') ||
            lower.contains('apple'))) {
      return AlwaysOnUrgency.medium;
    }

    return AlwaysOnUrgency.medium;
  }

  String _normalizePublishLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Agora';

    final normalized = value.replaceAll('GMT', '').trim();
    return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
  }

  Future<String> _fetchString(Uri uri) async {
    final bundle = NetworkAssetBundle(uri);
    return bundle.loadString(uri.toString());
  }

  List<String> _extractBlocks(String xml, String tag) {
    final regex = RegExp('<$tag>([\s\S]*?)</$tag>', caseSensitive: false);
    return regex
        .allMatches(xml)
        .map((match) => match.group(1) ?? '')
        .where((block) => block.trim().isNotEmpty)
        .toList();
  }

  String _readTag(String block, String tag) {
    final regex = RegExp(
      '<$tag(?:\s[^>]*)?>([\s\S]*?)</$tag>',
      caseSensitive: false,
    );

    final match = regex.firstMatch(block);
    final raw = match?.group(1) ?? '';
    return raw.replaceAll('<![CDATA[', '').replaceAll(']]>', '').trim();
  }

  String _decodeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  String _formatMoney(double value) {
    final fixed = value.toStringAsFixed(value >= 1000 ? 0 : 2);
    final normalized = fixed.replaceAll('.', ',');
    return 'R\$ $normalized';
  }

  List<AlwaysOnSection> _mergeMissingFallbackSections(
    AlwaysOnSettings settings,
    List<AlwaysOnSection> sections,
  ) {
    final existingIds = sections.map((item) => item.id).toSet();
    final fallback = _fallbackSections(settings);
    final merged = List<AlwaysOnSection>.from(sections);

    for (final section in fallback) {
      if (!existingIds.contains(section.id)) {
        merged.add(section);
      }
    }
    return merged;
  }

  List<AlwaysOnArticle> _fallbackArticlesForPreset(
    AlwaysOnInterestPreset preset,
  ) {
    return [
      AlwaysOnArticle(
        id: '${preset.id}_fallback_1',
        title: 'Seu espaço de ${preset.title} está pronto',
        source: 'Modo local',
        sectionId: preset.id,
        sectionTitle: preset.title,
        link: '',
        summary:
            'Assim que a internet responder, o radar volta a trazer notícias públicas desse tema.',
        publishLabel: 'Offline',
        shortReason: 'Seu radar de ${preset.title} está ligado',
        whyItMatters:
            'Quando a conexão voltar, esse bloco vai puxar conteúdos ligados ao que você escolheu acompanhar.',
        urgency: AlwaysOnUrgency.low,
        relevanceScore: 1,
      ),
      AlwaysOnArticle(
        id: '${preset.id}_fallback_2',
        title: 'Você pode deixar esse bloco mais pessoal',
        source: 'Modo local',
        sectionId: preset.id,
        sectionTitle: preset.title,
        link: '',
        summary:
            'Abra a personalização para ligar, desligar ou mudar os interesses desse radar.',
        publishLabel: 'Offline',
        shortReason: 'Dá para afinar melhor o radar',
        whyItMatters:
            'Quanto mais alinhado com seus interesses, menos conteúdo inútil e mais assunto que parece valer seu tempo.',
        urgency: AlwaysOnUrgency.low,
        relevanceScore: 1,
      ),
    ];
  }

  List<AlwaysOnArticle> _fallbackArticlesForCustomTopic(String topic) {
    return [
      AlwaysOnArticle(
        id: 'custom_${topic}_1',
        title: topic,
        source: 'Modo local',
        sectionId: 'custom-${topic.toLowerCase()}',
        sectionTitle: topic,
        link: '',
        summary:
            'Tema salvo no seu radar. Quando houver conexão, ele puxa atualizações ligadas a esse assunto.',
        publishLabel: 'Offline',
        shortReason: 'Tema salvo no seu radar pessoal',
        whyItMatters:
            'Esse assunto foi escolhido por você, então o feed tende a ficar mais direto e menos genérico.',
        urgency: AlwaysOnUrgency.low,
        relevanceScore: 1,
      ),
    ];
  }

  List<AlwaysOnArticle> _fallbackArticlesForTicker(String ticker) {
    return [
      AlwaysOnArticle(
        id: 'ticker_${ticker}_1',
        title: ticker.toUpperCase(),
        source: 'Modo local',
        sectionId: 'ticker-${ticker.toLowerCase()}',
        sectionTitle: ticker.toUpperCase(),
        link: '',
        summary:
            'Assim que a internet responder, o radar volta a buscar notícias desse ativo.',
        publishLabel: 'Offline',
        shortReason: 'Ticker salvo no seu radar',
        whyItMatters:
            'Isso ajuda o radar a puxar contexto e notícias ligadas a esse código quando houver conteúdo disponível.',
        urgency: AlwaysOnUrgency.low,
        relevanceScore: 1,
      ),
    ];
  }

  List<AlwaysOnSection> _fallbackSections(AlwaysOnSettings settings) {
    final sections = <AlwaysOnSection>[];

    final selectedPresets = settings.activePresetIds
        .map(AlwaysOnPresets.byId)
        .whereType<AlwaysOnInterestPreset>()
        .toList();

    for (final preset in selectedPresets) {
      sections.add(
        AlwaysOnSection(
          id: preset.id,
          title: preset.title,
          icon: preset.icon,
          items: _fallbackArticlesForPreset(preset),
        ),
      );
    }

    for (final topic in settings.customTopics) {
      sections.add(
        AlwaysOnSection(
          id: 'custom-${topic.toLowerCase()}',
          title: topic,
          icon: Icons.interests_rounded,
          items: _fallbackArticlesForCustomTopic(topic),
        ),
      );
    }

    for (final ticker in settings.trackedTickers) {
      sections.add(
        AlwaysOnSection(
          id: 'ticker-${ticker.toLowerCase()}',
          title: ticker.toUpperCase(),
          icon: Icons.candlestick_chart_rounded,
          items: _fallbackArticlesForTicker(ticker),
        ),
      );
    }

    return sections;
  }

  List<AlwaysOnMarketQuote> _fallbackMarketQuotes() {
    return const [
      AlwaysOnMarketQuote(
        code: 'USD/BRL',
        title: 'Dólar',
        priceLabel: '--',
        changePercent: 0,
        changeLabel: 'sem rede',
        history: [1, 1, 1, 1, 1, 1, 1],
      ),
      AlwaysOnMarketQuote(
        code: 'BTC/BRL',
        title: 'Bitcoin',
        priceLabel: '--',
        changePercent: 0,
        changeLabel: 'sem rede',
        history: [1, 1, 1, 1, 1, 1, 1],
      ),
    ];
  }
}
