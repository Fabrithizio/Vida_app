// ============================================================================
// FILE: lib/features/always_on/data/always_on_presets.dart
//
// O que este arquivo faz:
// - Define os interesses prontos do Sempre Ligado
// - Dá uma base personalizada para notícias e contexto do usuário
// - Facilita ligar e desligar blocos sem espalhar regra na UI
// ============================================================================

import 'package:flutter/material.dart';
import 'package:vida_app/features/always_on/domain/always_on_models.dart';

class AlwaysOnPresets {
  static const List<AlwaysOnInterestPreset> all = [
    AlwaysOnInterestPreset(
      id: 'mercado',
      title: 'Mercado',
      subtitle: 'Bolsa, investimentos, dólar e macro',
      query: 'mercado financeiro OR bolsa OR investimentos OR economia',
      icon: Icons.show_chart_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'mundo',
      title: 'Mundo',
      subtitle: 'Temas globais e acontecimentos relevantes',
      query: 'mundo OR geopolítica OR conflitos OR economia global',
      icon: Icons.public_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'tecnologia',
      title: 'Tecnologia',
      subtitle: 'IA, produtos, internet e inovação',
      query: 'tecnologia OR inteligência artificial OR inovação',
      icon: Icons.memory_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'fe',
      title: 'Fé',
      subtitle: 'Evangelho, reflexão e notícias do meio cristão',
      query: 'evangelho OR bíblia OR igreja OR cristão',
      icon: Icons.auto_stories_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'politica',
      title: 'Política',
      subtitle: 'Decisões públicas e impacto prático',
      query: 'política OR congresso OR governo OR eleições',
      icon: Icons.account_balance_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'saude',
      title: 'Saúde',
      subtitle: 'Bem-estar, ciência e qualidade de vida',
      query: 'saúde OR bem-estar OR medicina OR prevenção',
      icon: Icons.favorite_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'esportes',
      title: 'Esportes',
      subtitle: 'Resultados, análise e destaques',
      query: 'esportes OR futebol OR campeonato OR seleção',
      icon: Icons.sports_soccer_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'cultura',
      title: 'Cultura',
      subtitle: 'Filmes, séries, música e tendências',
      query: 'cultura OR cinema OR séries OR música',
      icon: Icons.movie_creation_rounded,
    ),
    AlwaysOnInterestPreset(
      id: 'estudos',
      title: 'Estudos',
      subtitle: 'Aprendizado, carreira e desenvolvimento',
      query: 'educação OR carreira OR estudos OR produtividade',
      icon: Icons.school_rounded,
    ),
  ];

  static AlwaysOnInterestPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
