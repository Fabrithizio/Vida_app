// ============================================================================
// FILE: lib/presentation/pages/home/tabs/areas/areas_catalog.dart
//
// Catálogo das 9 macroáreas do Painel de Vida:
// - Define id, título, título curto, subtítulo e ícone
// - Define sub-itens (sinais) que no futuro serão alimentados automaticamente pelos módulos
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
      titleShort: 'Corpo',
      subtitle: 'Energia, sono, hábitos e check-ups',
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
      titleShort: 'Mente',
      subtitle: 'Humor, estresse, foco e equilíbrio',
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
      subtitle: 'Gastos, renda, metas e segurança',
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
      subtitle: 'Carreira, rotina, realização',
      icon: Icons.work,
      items: [
        AreaItemDef(id: 'routine', title: 'Rotina de trabalho'),
        AreaItemDef(id: 'output', title: 'Entrega'),
        AreaItemDef(id: 'growth', title: 'Crescimento'),
        AreaItemDef(id: 'balance', title: 'Equilíbrio'),
      ],
    ),
    AreaDef(
      id: learningIntellect,
      title: 'Aprendizado & Intelecto',
      titleShort: 'Aprender',
      subtitle: 'Estudo, leitura, cursos e evolução',
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
      titleShort: 'Relações',
      subtitle: 'Família, amigos e vínculos',
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
      subtitle: 'Sentido, valores e direção',
      icon: Icons.auto_awesome,
      items: [
        AreaItemDef(id: 'purpose', title: 'Propósito'),
        AreaItemDef(id: 'values', title: 'Valores'),
        AreaItemDef(id: 'gratitude', title: 'Gratidão'),
        AreaItemDef(id: 'spiritual', title: 'Espiritualidade'),
        AreaItemDef(id: 'culture', title: 'Cultura / Identidade'),
      ],
    ),
    AreaDef(
      id: environmentHome,
      title: 'Ambiente & Casa',
      titleShort: 'Casa',
      subtitle: 'Organização e espaço físico',
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
      subtitle: 'Tempo de tela e hábitos',
      icon: Icons.devices,
      items: [
        AreaItemDef(id: 'screen_time', title: 'Tempo de tela'),
        AreaItemDef(id: 'distraction', title: 'Distrações'),
        AreaItemDef(id: 'digital_hygiene', title: 'Higiene digital'),
        AreaItemDef(id: 'privacy', title: 'Privacidade'),
      ],
    ),
  ];

  static AreaDef byId(String id) {
    return _defs.firstWhere((d) => d.id == id, orElse: () => _defs.first);
  }

  static List<AreaDef> all() => List.unmodifiable(_defs);
}
