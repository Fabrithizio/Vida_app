// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/areas_catalog.dart
//
// Catálogo das 9 macroáreas do Painel de Vida (nomes curtos e diretos):
// - titleShort foi ajustado para não cortar e ser óbvio
// - items continuam como “sinais” (pra motor automático depois)
// ============================================================================

import 'package:flutter/material.dart';

class AreaItemDef {
  const AreaItemDef({required this.id, required this.title});

  final String id;
  final String title;
}

class AreaDef {
  const AreaDef({
    required this.id,
    required this.title,
    required this.titleShort,
    required this.subtitle,
    required this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final String titleShort;
  final String subtitle;
  final IconData icon;
  final List<AreaItemDef> items;
}

class AreasCatalog {
  static const String bodyHealth = 'body_health';
  static const String mindEmotion = 'mind_emotion';
  static const String financeMaterial = 'finance_material';
  static const String workVocation = 'work_vocation';
  static const String learningIntellect = 'learning_intellect';
  static const String relationsCommunity = 'relations_community';
  static const String purposeValues = 'purpose_values';
  static const String environmentHome = 'environment_home';
  static const String digitalTech = 'digital_tech';

  static const List<AreaDef> _defs = [
    AreaDef(
      id: bodyHealth,
      title: 'Corpo & Saúde',
      titleShort: 'Saúde',
      subtitle: 'Energia, sono e hábitos',
      icon: Icons.favorite,
      items: [
        AreaItemDef(id: 'energy', title: 'Energia'),
        AreaItemDef(id: 'sleep', title: 'Sono'),
        AreaItemDef(id: 'movement', title: 'Movimento / Exercício'),
        AreaItemDef(id: 'nutrition', title: 'Alimentação'),
        AreaItemDef(id: 'checkups', title: 'Check-ups / Exames'),
        AreaItemDef(id: 'women_cycle', title: 'Ciclo (se aplicável)'),
      ],
    ),
    AreaDef(
      id: mindEmotion,
      title: 'Mente & Emoções',
      titleShort: 'Emoções',
      subtitle: 'Humor, estresse e foco',
      icon: Icons.psychology,
      items: [
        AreaItemDef(id: 'mood', title: 'Humor'),
        AreaItemDef(id: 'stress', title: 'Estresse'),
        AreaItemDef(id: 'anxiety', title: 'Ansiedade'),
        AreaItemDef(id: 'focus', title: 'Foco'),
        AreaItemDef(id: 'selfcare', title: 'Autocuidado'),
      ],
    ),
    AreaDef(
      id: financeMaterial,
      title: 'Finanças & Material',
      titleShort: 'Finanças',
      subtitle: 'Gastos, renda e metas',
      icon: Icons.account_balance_wallet,
      items: [
        AreaItemDef(id: 'income', title: 'Renda'),
        AreaItemDef(id: 'spending', title: 'Gastos'),
        AreaItemDef(id: 'budget', title: 'Orçamento / Controle'),
        AreaItemDef(id: 'debts', title: 'Dívidas'),
        AreaItemDef(id: 'savings', title: 'Reserva'),
        AreaItemDef(id: 'goals_fin', title: 'Metas financeiras'),
      ],
    ),
    AreaDef(
      id: workVocation,
      title: 'Trabalho & Vocação',
      titleShort: 'Trabalho',
      subtitle: 'Carreira e rotina',
      icon: Icons.work,
      items: [
        AreaItemDef(id: 'routine', title: 'Rotina'),
        AreaItemDef(id: 'output', title: 'Entrega'),
        AreaItemDef(id: 'growth', title: 'Crescimento'),
        AreaItemDef(id: 'balance', title: 'Equilíbrio'),
      ],
    ),
    AreaDef(
      id: learningIntellect,
      title: 'Aprendizado & Intelecto',
      titleShort: 'Estudos',
      subtitle: 'Estudo e progresso',
      icon: Icons.school,
      items: [
        AreaItemDef(id: 'study', title: 'Tempo de estudo'),
        AreaItemDef(id: 'courses', title: 'Cursos / Progresso'),
        AreaItemDef(id: 'reading', title: 'Leitura'),
        AreaItemDef(id: 'skills', title: 'Habilidades'),
      ],
    ),
    AreaDef(
      id: relationsCommunity,
      title: 'Relações & Comunidade',
      titleShort: 'Social',
      subtitle: 'Família e amigos',
      icon: Icons.groups,
      items: [
        AreaItemDef(id: 'family', title: 'Família'),
        AreaItemDef(id: 'friends', title: 'Amigos'),
        AreaItemDef(id: 'partner', title: 'Relacionamento'),
        AreaItemDef(id: 'community', title: 'Comunidade'),
      ],
    ),
    AreaDef(
      id: purposeValues,
      title: 'Propósito & Valores',
      titleShort: 'Propósito',
      subtitle: 'Sentido e direção',
      icon: Icons.auto_awesome,
      items: [
        AreaItemDef(id: 'purpose', title: 'Propósito'),
        AreaItemDef(id: 'values', title: 'Valores'),
        AreaItemDef(id: 'gratitude', title: 'Gratidão'),
        AreaItemDef(id: 'spiritual', title: 'Espiritualidade'),
      ],
    ),
    AreaDef(
      id: environmentHome,
      title: 'Ambiente & Casa',
      titleShort: 'Casa',
      subtitle: 'Organização',
      icon: Icons.home,
      items: [
        AreaItemDef(id: 'organization', title: 'Organização'),
        AreaItemDef(id: 'cleaning', title: 'Rotina'),
        AreaItemDef(id: 'comfort', title: 'Conforto'),
        AreaItemDef(id: 'nature', title: 'Natureza'),
      ],
    ),
    AreaDef(
      id: digitalTech,
      title: 'Digital & Tecnologia',
      titleShort: 'Digital',
      subtitle: 'Foco e hábitos',
      icon: Icons.devices,
      items: [
        AreaItemDef(id: 'screen_time', title: 'Tempo de tela'),
        AreaItemDef(id: 'distraction', title: 'Distrações'),
        AreaItemDef(id: 'digital_hygiene', title: 'Higiene digital'),
        AreaItemDef(id: 'privacy', title: 'Privacidade'),
      ],
    ),
  ];

  static AreaDef byId(String id) =>
      _defs.firstWhere((d) => d.id == id, orElse: () => _defs.first);

  static List<AreaDef> all() => List.unmodifiable(_defs);
}
