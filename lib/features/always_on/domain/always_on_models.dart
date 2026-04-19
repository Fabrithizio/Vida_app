// ============================================================================
// FILE: lib/features/always_on/domain/always_on_models.dart
//
// O que este arquivo faz:
// - Define os modelos do sistema Sempre Ligado
// - Centraliza dados de interesses, notícias, mercado e preferências do usuário
// - Adiciona prioridade, motivo curto e impacto prático para o radar ficar
//   mais direto e mais pessoal
// ============================================================================

import 'package:flutter/material.dart';

class AlwaysOnInterestPreset {
  const AlwaysOnInterestPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final String query;
  final IconData icon;
}

enum AlwaysOnUrgency { low, medium, high }

class AlwaysOnArticle {
  const AlwaysOnArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.sectionId,
    required this.sectionTitle,
    required this.link,
    required this.summary,
    required this.publishLabel,
    required this.shortReason,
    required this.whyItMatters,
    required this.urgency,
    required this.relevanceScore,
  });

  final String id;
  final String title;
  final String source;
  final String sectionId;
  final String sectionTitle;
  final String link;
  final String summary;
  final String publishLabel;
  final String shortReason;
  final String whyItMatters;
  final AlwaysOnUrgency urgency;
  final int relevanceScore;

  bool get isHighPriority => urgency == AlwaysOnUrgency.high;
}

class AlwaysOnMarketQuote {
  const AlwaysOnMarketQuote({
    required this.code,
    required this.title,
    required this.priceLabel,
    required this.changePercent,
    required this.changeLabel,
    required this.history,
  });

  final String code;
  final String title;
  final String priceLabel;
  final double changePercent;
  final String changeLabel;
  final List<double> history;

  bool get isPositive => changePercent >= 0;
}

class AlwaysOnSection {
  const AlwaysOnSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<AlwaysOnArticle> items;
}

class AlwaysOnSettings {
  const AlwaysOnSettings({
    required this.activePresetIds,
    required this.customTopics,
    required this.trackedTickers,
  });

  final List<String> activePresetIds;
  final List<String> customTopics;
  final List<String> trackedTickers;

  bool get isEmpty =>
      activePresetIds.isEmpty && customTopics.isEmpty && trackedTickers.isEmpty;

  AlwaysOnSettings copyWith({
    List<String>? activePresetIds,
    List<String>? customTopics,
    List<String>? trackedTickers,
  }) {
    return AlwaysOnSettings(
      activePresetIds: activePresetIds ?? this.activePresetIds,
      customTopics: customTopics ?? this.customTopics,
      trackedTickers: trackedTickers ?? this.trackedTickers,
    );
  }

  static const AlwaysOnSettings defaults = AlwaysOnSettings(
    activePresetIds: ['mercado', 'mundo', 'tecnologia', 'fe'],
    customTopics: [],
    trackedTickers: ['PETR4', 'VALE3'],
  );
}

class AlwaysOnSnapshot {
  const AlwaysOnSnapshot({
    required this.settings,
    required this.summary,
    required this.marketQuotes,
    required this.sections,
    required this.personalHighlights,
    required this.loadedAt,
    required this.usedFallback,
    required this.topSignal,
  });

  final AlwaysOnSettings settings;
  final String summary;
  final List<AlwaysOnMarketQuote> marketQuotes;
  final List<AlwaysOnSection> sections;
  final List<AlwaysOnArticle> personalHighlights;
  final DateTime loadedAt;
  final bool usedFallback;
  final String topSignal;

  int get totalItems =>
      personalHighlights.length +
      sections.fold<int>(0, (sum, section) => sum + section.items.length);
}
