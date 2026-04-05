// ============================================================================
// FILE: lib/features/always_on/data/always_on_repository.dart
//
// O que este arquivo faz:
// - Carrega e salva as preferências do Sempre Ligado
// - Busca notícias públicas por RSS e cotações públicas de mercado
// - Monta o snapshot final consumido pela interface
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

    try {
      final marketQuotes = await _loadMarketQuotes();
      final sections = await _loadSections(settings);
      final highlights = _buildHighlights(sections);
      final summary = _buildSummary(settings, sections, marketQuotes);

      return AlwaysOnSnapshot(
        settings: settings,
        summary: summary,
        marketQuotes: marketQuotes,
        sections: sections,
        personalHighlights: highlights,
        loadedAt: DateTime.now(),
        usedFallback: false,
      );
    } catch (_) {
      final fallback = _fallbackSections(settings);

      return AlwaysOnSnapshot(
        settings: settings,
        summary:
            'Sem conexão agora. O Sempre Ligado manteve uma versão local para não deixar a aba vazia.',
        marketQuotes: _fallbackMarketQuotes(),
        sections: fallback,
        personalHighlights: _buildHighlights(fallback),
        loadedAt: DateTime.now(),
        usedFallback: true,
      );
    }
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

      if (articles.isNotEmpty) {
        sections.add(
          AlwaysOnSection(
            id: preset.id,
            title: preset.title,
            icon: preset.icon,
            items: articles,
          ),
        );
      }
    }

    for (final topic in settings.customTopics) {
      final articles = await _loadRssSection(
        sectionId: 'custom-${topic.toLowerCase()}',
        sectionTitle: topic,
        query: topic,
      );

      if (articles.isNotEmpty) {
        sections.add(
          AlwaysOnSection(
            id: 'custom-${topic.toLowerCase()}',
            title: topic,
            icon: Icons.interests_rounded,
            items: articles,
          ),
        );
      }
    }

    for (final ticker in settings.trackedTickers) {
      final articles = await _loadRssSection(
        sectionId: 'ticker-${ticker.toLowerCase()}',
        sectionTitle: ticker.toUpperCase(),
        query: '${ticker.toUpperCase()} bolsa OR ações OR mercado',
      );

      if (articles.isNotEmpty) {
        sections.add(
          AlwaysOnSection(
            id: 'ticker-${ticker.toLowerCase()}',
            title: ticker.toUpperCase(),
            icon: Icons.candlestick_chart_rounded,
            items: articles,
          ),
        );
      }
    }

    return sections;
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

    return items
        .take(5)
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

          return AlwaysOnArticle(
            id: '${sectionId}_${link.hashCode}',
            title: title.isEmpty ? fullTitle : title,
            source: source.isEmpty ? 'Fonte pública' : source,
            sectionId: sectionId,
            sectionTitle: sectionTitle,
            link: link.trim(),
            summary: _buildArticleSummary(
              sectionTitle,
              title.isEmpty ? fullTitle : title,
            ),
            publishLabel: _normalizePublishLabel(pubDate),
          );
        })
        .where((item) => item.title.isNotEmpty && item.link.isNotEmpty)
        .toList();
  }

  List<AlwaysOnArticle> _buildHighlights(List<AlwaysOnSection> sections) {
    final seen = <String>{};
    final items = <AlwaysOnArticle>[];

    for (final section in sections) {
      if (section.items.isEmpty) continue;

      final first = section.items.first;
      if (seen.add(first.title.toLowerCase())) {
        items.add(first);
      }

      if (items.length >= 6) break;
    }

    return items;
  }

  String _buildSummary(
    AlwaysOnSettings settings,
    List<AlwaysOnSection> sections,
    List<AlwaysOnMarketQuote> marketQuotes,
  ) {
    final interestsCount =
        settings.activePresetIds.length + settings.customTopics.length;
    final highlightedMarkets = marketQuotes
        .take(2)
        .map((item) => item.title)
        .join(' e ');

    if (sections.isEmpty) {
      return 'Seu radar está pronto, mas ainda faltou conteúdo novo agora. Tente atualizar novamente em instantes.';
    }

    return '$interestsCount interesses ativos, ${sections.length} blocos informativos e mercado com destaque para $highlightedMarkets.';
  }

  String _buildArticleSummary(String sectionTitle, String title) {
    return 'Resumo rápido de $sectionTitle: $title';
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
    final regex = RegExp('<$tag>([\\s\\S]*?)</$tag>', caseSensitive: false);
    return regex
        .allMatches(xml)
        .map((match) => match.group(1) ?? '')
        .where((block) => block.trim().isNotEmpty)
        .toList();
  }

  String _readTag(String block, String tag) {
    final regex = RegExp(
      '<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>',
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
          items: [
            AlwaysOnArticle(
              id: '${preset.id}_fallback_1',
              title: 'Seu espaço de ${preset.title} está pronto',
              source: 'Modo local',
              sectionId: preset.id,
              sectionTitle: preset.title,
              link: '',
              summary:
                  'Assim que a internet responder, o Sempre Ligado volta a trazer notícias públicas desse tema.',
              publishLabel: 'Offline',
            ),
            AlwaysOnArticle(
              id: '${preset.id}_fallback_2',
              title: 'Você pode personalizar esse bloco',
              source: 'Modo local',
              sectionId: preset.id,
              sectionTitle: preset.title,
              link: '',
              summary:
                  'Abra a personalização para ligar, desligar ou mudar os interesses desse radar.',
              publishLabel: 'Offline',
            ),
          ],
        ),
      );
    }

    if (settings.customTopics.isNotEmpty) {
      sections.add(
        AlwaysOnSection(
          id: 'custom_fallback',
          title: 'Seus temas',
          icon: Icons.interests_rounded,
          items: settings.customTopics.map((topic) {
            return AlwaysOnArticle(
              id: 'custom_$topic',
              title: topic,
              source: 'Modo local',
              sectionId: 'custom_fallback',
              sectionTitle: 'Seus temas',
              link: '',
              summary:
                  'Tema salvo no seu Sempre Ligado. Quando houver conexão, ele puxa atualizações ligadas a esse assunto.',
              publishLabel: 'Offline',
            );
          }).toList(),
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
