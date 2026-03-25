import 'package:flutter/material.dart';
import 'package:vida_app/data/models/area_data_source.dart';

class AreaItemDef {
  const AreaItemDef({
    required this.id,
    required this.title,
    required this.description,
    required this.defaultSource,
    this.weight = 1.0,
    this.hint,
    this.recommendedAction,
    this.supportsAutomaticData = false,
  });

  final String id;
  final String title;
  final String description;
  final AreaDataSource defaultSource;
  final double weight;
  final String? hint;
  final String? recommendedAction;
  final bool supportsAutomaticData;
}

class AreaDef {
  const AreaDef({
    required this.id,
    required this.title,
    required this.titleShort,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.items,
  });

  final String id;
  final String title;
  final String titleShort;
  final String subtitle;
  final String description;
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
      description:
          'Mostra como está sua saúde física, rotina de cuidados e sinais de bem-estar.',
      icon: Icons.favorite,
      items: [
        AreaItemDef(
          id: 'energy',
          title: 'Energia',
          description: 'Avalia disposição e sensação de energia no dia a dia.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.0,
          recommendedAction: 'Responder como foi sua energia nos últimos dias.',
        ),
        AreaItemDef(
          id: 'sleep',
          title: 'Sono',
          description: 'Quantidade e qualidade do sono recente.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.2,
          recommendedAction:
              'Atualizar horas de sono para manter a área confiável.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'movement',
          title: 'Movimento / Exercício',
          description:
              'Atividade física, movimento e frequência de exercícios.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.0,
          recommendedAction: 'Registrar atividade física recente.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'nutrition',
          title: 'Alimentação',
          description:
              'Consistência dos hábitos alimentares e qualidade da rotina.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.0,
          recommendedAction: 'Responder como esteve sua alimentação.',
        ),
        AreaItemDef(
          id: 'checkups',
          title: 'Check-ups / Exames',
          description:
              'Acompanha o tempo desde o último check-up ou exame relevante.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Atualizar a data do último check-up.',
        ),
        AreaItemDef(
          id: 'women_cycle',
          title: 'Ciclo (se aplicável)',
          description:
              'Espaço para acompanhamento de ciclo e sinais relacionados.',
          defaultSource: AreaDataSource.manual,
          weight: 0.8,
          recommendedAction: 'Registrar ou revisar informações do ciclo.',
        ),
      ],
    ),
    AreaDef(
      id: mindEmotion,
      title: 'Mente & Emoções',
      titleShort: 'Emoções',
      subtitle: 'Humor, estresse e foco',
      description: 'Resume seu estado emocional, mental e capacidade de foco.',
      icon: Icons.psychology,
      items: [
        AreaItemDef(
          id: 'mood',
          title: 'Humor',
          description: 'Percepção geral do humor recente.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve seu humor.',
        ),
        AreaItemDef(
          id: 'stress',
          title: 'Estresse',
          description: 'Nível de tensão e sobrecarga recente.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.1,
          recommendedAction: 'Atualizar o nível de estresse percebido.',
        ),
        AreaItemDef(
          id: 'anxiety',
          title: 'Ansiedade',
          description: 'Sinais de ansiedade e impacto no cotidiano.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.1,
          recommendedAction: 'Registrar como esteve sua ansiedade.',
        ),
        AreaItemDef(
          id: 'focus',
          title: 'Foco',
          description: 'Capacidade de manter atenção nas tarefas e objetivos.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder sobre seu nível de foco.',
        ),
        AreaItemDef(
          id: 'selfcare',
          title: 'Autocuidado',
          description: 'Rotina de cuidado pessoal e recuperação mental.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Marcar práticas recentes de autocuidado.',
        ),
      ],
    ),
    AreaDef(
      id: financeMaterial,
      title: 'Finanças & Material',
      titleShort: 'Finanças',
      subtitle: 'Gastos, renda e metas',
      description:
          'Mostra a saúde financeira atual, equilíbrio entre entrada e saída e segurança material.',
      icon: Icons.account_balance_wallet,
      items: [
        AreaItemDef(
          id: 'income',
          title: 'Renda',
          description:
              'Capacidade atual de geração de renda e constância de entrada.',
          defaultSource: AreaDataSource.manual,
          weight: 1.2,
          recommendedAction: 'Atualizar a renda mensal atual.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'spending',
          title: 'Gastos',
          description: 'Volume de gastos recentes e controle sobre saídas.',
          defaultSource: AreaDataSource.manual,
          weight: 1.2,
          recommendedAction: 'Atualizar gastos do período.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'budget',
          title: 'Orçamento / Controle',
          description:
              'Nível de organização financeira e acompanhamento do orçamento.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Revisar o orçamento atual.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'debts',
          title: 'Dívidas',
          description: 'Impacto das dívidas na situação financeira atual.',
          defaultSource: AreaDataSource.manual,
          weight: 1.3,
          recommendedAction: 'Atualizar dívidas ou parcelamentos ativos.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'savings',
          title: 'Reserva',
          description:
              'Presença de reserva financeira e segurança de curto prazo.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Informar o status da sua reserva.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'goals_fin',
          title: 'Metas financeiras',
          description:
              'Progresso em metas como economizar, quitar ou investir.',
          defaultSource: AreaDataSource.manual,
          weight: 0.9,
          recommendedAction: 'Atualizar avanço das metas financeiras.',
        ),
      ],
    ),
    AreaDef(
      id: workVocation,
      title: 'Trabalho & Vocação',
      titleShort: 'Trabalho',
      subtitle: 'Carreira e rotina',
      description:
          'Avalia rotina produtiva, progresso e equilíbrio com a vida.',
      icon: Icons.work,
      items: [
        AreaItemDef(
          id: 'routine',
          title: 'Rotina',
          description: 'Organização da rotina de trabalho ou estudo principal.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Atualizar como esteve sua rotina.',
        ),
        AreaItemDef(
          id: 'output',
          title: 'Entrega',
          description: 'Percepção de progresso e entregas recentes.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve seu rendimento.',
        ),
        AreaItemDef(
          id: 'growth',
          title: 'Crescimento',
          description: 'Sinais de evolução, aprendizado e avanço na área.',
          defaultSource: AreaDataSource.onboarding,
          recommendedAction: 'Revisar metas de crescimento.',
        ),
        AreaItemDef(
          id: 'balance',
          title: 'Equilíbrio',
          description: 'Equilíbrio entre produtividade, descanso e pressão.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.1,
          recommendedAction: 'Atualizar percepção de equilíbrio.',
        ),
      ],
    ),
    AreaDef(
      id: learningIntellect,
      title: 'Aprendizado & Intelecto',
      titleShort: 'Estudos',
      subtitle: 'Estudo e progresso',
      description:
          'Mostra avanço intelectual, constância de estudo e desenvolvimento de habilidades.',
      icon: Icons.school,
      items: [
        AreaItemDef(
          id: 'study',
          title: 'Tempo de estudo',
          description: 'Consistência do tempo dedicado ao aprendizado.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Atualizar tempo de estudo recente.',
        ),
        AreaItemDef(
          id: 'courses',
          title: 'Cursos / Progresso',
          description: 'Evolução em cursos e trilhas em andamento.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Marcar progresso nos cursos ativos.',
        ),
        AreaItemDef(
          id: 'reading',
          title: 'Leitura',
          description: 'Ritmo de leitura e contato com novos conteúdos.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Atualizar hábito de leitura.',
        ),
        AreaItemDef(
          id: 'skills',
          title: 'Habilidades',
          description: 'Desenvolvimento prático de competências relevantes.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Registrar avanço em habilidades.',
        ),
      ],
    ),
    AreaDef(
      id: relationsCommunity,
      title: 'Relações & Comunidade',
      titleShort: 'Social',
      subtitle: 'Família e amigos',
      description:
          'Resume vínculos sociais, proximidade e sensação de conexão.',
      icon: Icons.groups,
      items: [
        AreaItemDef(
          id: 'family',
          title: 'Família',
          description: 'Qualidade da relação e contato com a família.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Atualizar como estiveram as relações familiares.',
        ),
        AreaItemDef(
          id: 'friends',
          title: 'Amigos',
          description: 'Presença de amizade, apoio e convivência social.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como estiveram suas amizades.',
        ),
        AreaItemDef(
          id: 'partner',
          title: 'Relacionamento',
          description:
              'Acompanhamento do relacionamento afetivo, se aplicável.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Atualizar situação do relacionamento.',
        ),
        AreaItemDef(
          id: 'community',
          title: 'Comunidade',
          description:
              'Participação em grupo, comunidade ou sensação de pertencimento.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve sua conexão com pessoas.',
        ),
      ],
    ),
    AreaDef(
      id: purposeValues,
      title: 'Propósito & Valores',
      titleShort: 'Propósito',
      subtitle: 'Sentido e direção',
      description:
          'Ajuda a medir clareza de direção, coerência com valores e sentido da rotina.',
      icon: Icons.auto_awesome,
      items: [
        AreaItemDef(
          id: 'purpose',
          title: 'Propósito',
          description: 'Clareza sobre direção e sentido de vida.',
          defaultSource: AreaDataSource.onboarding,
          weight: 1.2,
          recommendedAction: 'Revisar sua direção atual.',
        ),
        AreaItemDef(
          id: 'values',
          title: 'Valores',
          description: 'Alinhamento entre suas escolhas e seus valores.',
          defaultSource: AreaDataSource.onboarding,
          recommendedAction:
              'Refletir se sua rotina está alinhada aos seus valores.',
        ),
        AreaItemDef(
          id: 'gratitude',
          title: 'Gratidão',
          description: 'Percepção de apreciação e presença no cotidiano.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve sua percepção do dia.',
        ),
        AreaItemDef(
          id: 'spiritual',
          title: 'Espiritualidade',
          description:
              'Espaço para práticas espirituais ou conexão interior, se fizer sentido.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Registrar práticas espirituais ou reflexivas.',
        ),
      ],
    ),
    AreaDef(
      id: environmentHome,
      title: 'Ambiente & Casa',
      titleShort: 'Casa',
      subtitle: 'Organização',
      description:
          'Mostra se seu ambiente está ajudando ou atrapalhando seu bem-estar.',
      icon: Icons.home,
      items: [
        AreaItemDef(
          id: 'organization',
          title: 'Organização',
          description: 'Nível de organização do espaço e facilidade de rotina.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Atualizar como está sua organização.',
        ),
        AreaItemDef(
          id: 'cleaning',
          title: 'Rotina',
          description: 'Manutenção básica do ambiente e constância de cuidado.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve sua rotina com a casa.',
        ),
        AreaItemDef(
          id: 'comfort',
          title: 'Conforto',
          description:
              'Sensação de conforto, acolhimento e funcionalidade do espaço.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Avaliar o conforto do seu ambiente.',
        ),
        AreaItemDef(
          id: 'nature',
          title: 'Natureza',
          description:
              'Contato com luz natural, ar livre e elementos de natureza.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction:
              'Atualizar sua conexão com natureza e ambiente externo.',
        ),
      ],
    ),
    AreaDef(
      id: digitalTech,
      title: 'Digital & Tecnologia',
      titleShort: 'Digital',
      subtitle: 'Foco e hábitos',
      description:
          'Resume como a tecnologia está ajudando ou atrapalhando sua vida atual.',
      icon: Icons.devices,
      items: [
        AreaItemDef(
          id: 'screen_time',
          title: 'Tempo de tela',
          description:
              'Quantidade de tempo gasto em telas e impacto no equilíbrio.',
          defaultSource: AreaDataSource.manual,
          weight: 1.2,
          recommendedAction: 'Atualizar tempo médio de tela.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'distraction',
          title: 'Distrações',
          description:
              'Nível de distração gerado por apps, notificações e excesso de estímulo.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.1,
          recommendedAction: 'Responder se houve muita distração digital.',
        ),
        AreaItemDef(
          id: 'digital_hygiene',
          title: 'Higiene digital',
          description:
              'Qualidade dos hábitos digitais e uso intencional da tecnologia.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Revisar hábitos digitais.',
        ),
        AreaItemDef(
          id: 'privacy',
          title: 'Privacidade',
          description:
              'Cuidados com privacidade, segurança e controle das contas.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Revisar configurações de privacidade.',
        ),
      ],
    ),
  ];

  static AreaDef byId(String id) {
    return _defs.firstWhere((d) => d.id == id, orElse: () => _defs.first);
  }

  static List<AreaDef> all() => List.unmodifiable(_defs);

  static AreaItemDef? itemById(String areaId, String itemId) {
    final area = byId(areaId);
    for (final item in area.items) {
      if (item.id == itemId) return item;
    }
    return null;
  }
}
