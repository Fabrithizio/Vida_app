// ============================================================================
// FILE: lib/features/home/presentation/tabs/areas/areas_catalog.dart
//
// O que faz:
// - Define o catálogo oficial das áreas e subáreas do painel Areas
// - Centraliza títulos, descrições, pesos e fonte padrão de cada item
// - Controla o que aparece ou não conforme o perfil do usuário
//
// Atualização desta versão:
// - alinha o catálogo ao sistema novo de score 0..100
// - atualiza Ambiente & Casa para refletir a ligação já existente com tarefas reais
// - troca a apresentação de "Direção Pessoal" para "Hábitos & Constância"
//   sem quebrar o id interno atual da área
// - remove textos antigos do tipo "ligar depois" onde a automação já existe
// ============================================================================

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
    this.showOnlyForWomen = false,
  });

  final String id;
  final String title;
  final String description;
  final AreaDataSource defaultSource;
  final double weight;
  final String? hint;
  final String? recommendedAction;
  final bool supportsAutomaticData;
  final bool showOnlyForWomen;
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
      subtitle: 'Energia, sono e cuidados',
      description:
          'Mostra como está sua saúde física com base em hábitos, registros e sinais recentes.',
      icon: Icons.favorite,
      items: [
        AreaItemDef(
          id: 'energy',
          title: 'Energia',
          description: 'Disposição e energia percebida no dia a dia.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve sua energia.',
        ),
        AreaItemDef(
          id: 'sleep',
          title: 'Sono',
          description: 'Quantidade e qualidade do sono recente.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.2,
          recommendedAction: 'Atualizar horas de sono.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'movement',
          title: 'Movimento / Exercício',
          description: 'Constância de atividade física e movimento.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Registrar se houve movimento ou treino.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'nutrition',
          title: 'Alimentação',
          description: 'Qualidade e consistência da alimentação.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve sua alimentação.',
        ),
        AreaItemDef(
          id: 'hydration',
          title: 'Hidratação',
          description: 'Percepção de hidratação e cuidado básico diário.',
          defaultSource: AreaDataSource.manual,
          recommendedAction:
              'Registrar sua hidratação quando esse módulo estiver ativo.',
        ),
        AreaItemDef(
          id: 'checkups',
          title: 'Check-ups / Exames',
          description: 'Tempo desde o último check-up ou exame relevante.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Atualizar a data do último check-up.',
        ),
        AreaItemDef(
          id: 'women_cycle',
          title: 'Ciclo menstrual',
          description: 'Acompanhamento do ciclo para perfis femininos.',
          defaultSource: AreaDataSource.manual,
          weight: 0.8,
          recommendedAction: 'Registrar dados do ciclo quando necessário.',
          showOnlyForWomen: true,
        ),
      ],
    ),
    AreaDef(
      id: mindEmotion,
      title: 'Mente & Emoções',
      titleShort: 'Emoções',
      subtitle: 'Humor, estresse e foco',
      description:
          'Resume seu estado mental usando sinais do dia a dia e percepção recente.',
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
          description: 'Nível de pressão e estresse recente.',
          defaultSource: AreaDataSource.dailyQuestions,
          weight: 1.1,
          recommendedAction: 'Atualizar o nível de estresse.',
        ),
        AreaItemDef(
          id: 'focus',
          title: 'Foco',
          description: 'Capacidade de manter atenção no que importa.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve seu foco.',
        ),
        AreaItemDef(
          id: 'mental_load',
          title: 'Sobrecarga mental',
          description: 'Percepção de peso mental e excesso de pressão.',
          defaultSource: AreaDataSource.estimated,
          weight: 1.0,
          recommendedAction:
              'Responder o check-in diário para estimar esta subárea.',
        ),
      ],
    ),
    AreaDef(
      id: financeMaterial,
      title: 'Finanças & Material',
      titleShort: 'Finanças',
      subtitle: 'Renda, controle e segurança',
      description:
          'Mostra a saúde financeira atual com base nos dados do módulo de Finanças.',
      icon: Icons.account_balance_wallet,
      items: [
        AreaItemDef(
          id: 'income',
          title: 'Renda',
          description: 'Entradas reais e capacidade de gerar renda.',
          defaultSource: AreaDataSource.automatic,
          weight: 1.2,
          recommendedAction: 'Registrar entradas na aba Finanças.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'spending',
          title: 'Gastos',
          description: 'Saídas recentes e controle sobre despesas.',
          defaultSource: AreaDataSource.automatic,
          weight: 1.2,
          recommendedAction: 'Registrar gastos na aba Finanças.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'monthly_flow',
          title: 'Fluxo do mês',
          description: 'Saldo entre entradas e saídas no mês atual.',
          defaultSource: AreaDataSource.automatic,
          weight: 1.2,
          recommendedAction: 'Manter entradas e saídas atualizadas.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'budget',
          title: 'Orçamento / Controle',
          description: 'Comparação entre orçamento e gasto real.',
          defaultSource: AreaDataSource.mixed,
          weight: 1.1,
          recommendedAction: 'Definir orçamento e registrar gastos.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'debts',
          title: 'Dívidas',
          description: 'Peso das dívidas na situação atual.',
          defaultSource: AreaDataSource.manual,
          weight: 1.3,
          recommendedAction: 'Atualizar dívidas ou parcelamentos.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'savings',
          title: 'Reserva',
          description: 'Segurança financeira de curto prazo.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Informar sua reserva financeira.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'goals_fin',
          title: 'Metas financeiras',
          description: 'Progresso para economizar, quitar ou investir.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Atualizar avanço das metas financeiras.',
        ),
      ],
    ),
    AreaDef(
      id: workVocation,
      title: 'Trabalho & Vocação',
      titleShort: 'Trabalho',
      subtitle: 'Rotina e consistência',
      description:
          'Avalia sua constância produtiva e o equilíbrio da rotina principal.',
      icon: Icons.work,
      items: [
        AreaItemDef(
          id: 'routine',
          title: 'Rotina',
          description: 'Organização da rotina principal no dia a dia.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder como esteve sua rotina.',
        ),
        AreaItemDef(
          id: 'output',
          title: 'Entrega',
          description: 'Percepção de entrega e avanço em tarefas importantes.',
          defaultSource: AreaDataSource.manual,
          recommendedAction:
              'Essa subárea pode ser ligada depois a metas e timeline.',
        ),
        AreaItemDef(
          id: 'consistency',
          title: 'Consistência',
          description: 'Capacidade de repetir o básico com frequência.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction:
              'Responder o check-in diário para alimentar esta subárea.',
        ),
        AreaItemDef(
          id: 'balance',
          title: 'Equilíbrio',
          description: 'Equilíbrio entre produtividade, descanso e pressão.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction:
              'Essa subárea pode ser ligada depois à agenda e rotina.',
        ),
      ],
    ),
    AreaDef(
      id: learningIntellect,
      title: 'Aprendizado & Intelecto',
      titleShort: 'Estudos',
      subtitle: 'Estudo e prática',
      description: 'Mostra constância de estudo e evolução intelectual.',
      icon: Icons.school,
      items: [
        AreaItemDef(
          id: 'study',
          title: 'Tempo de estudo',
          description: 'Constância do estudo recente.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder se houve estudo hoje.',
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
          description: 'Ritmo de leitura e contato com conteúdo de qualidade.',
          defaultSource: AreaDataSource.manual,
          recommendedAction:
              'Ligar depois a leitura, metas ou registros próprios.',
        ),
        AreaItemDef(
          id: 'skills',
          title: 'Habilidades',
          description: 'Desenvolvimento de competências relevantes.',
          defaultSource: AreaDataSource.manual,
          weight: 1.1,
          recommendedAction: 'Registrar avanço em habilidades.',
        ),
        AreaItemDef(
          id: 'review_practice',
          title: 'Revisão / Prática',
          description: 'Aplicação prática do que foi aprendido.',
          defaultSource: AreaDataSource.manual,
          recommendedAction:
              'Ligar depois a metas, exercícios ou prática guiada.',
        ),
      ],
    ),
    AreaDef(
      id: relationsCommunity,
      title: 'Relações & Conexões',
      titleShort: 'Social',
      subtitle: 'Contato e vínculos',
      description: 'Resume o quanto sua vida social está viva e presente.',
      icon: Icons.groups,
      items: [
        AreaItemDef(
          id: 'family',
          title: 'Família',
          description: 'Contato e qualidade da relação com a família.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Ligar depois a registros e check-ins sociais.',
        ),
        AreaItemDef(
          id: 'friends',
          title: 'Amigos',
          description: 'Presença de amizade, apoio e convivência.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Ligar depois a registros e check-ins sociais.',
        ),
        AreaItemDef(
          id: 'partner',
          title: 'Relacionamento',
          description:
              'Acompanhamento do relacionamento afetivo, se aplicável.',
          defaultSource: AreaDataSource.manual,
          recommendedAction:
              'Atualizar situação do relacionamento quando esse módulo estiver ativo.',
        ),
        AreaItemDef(
          id: 'social_contact',
          title: 'Contato social recente',
          description: 'Se houve conexão social relevante recentemente.',
          defaultSource: AreaDataSource.dailyQuestions,
          recommendedAction: 'Responder o check-in social do dia.',
        ),
      ],
    ),
    AreaDef(
      id: purposeValues,
      title: 'Hábitos & Constância',
      titleShort: 'Hábitos',
      subtitle: 'Base, repetição e recuperação',
      description:
          'Resume se você está conseguindo manter a base do dia a dia com regularidade, recuperação e repetição do básico.',
      icon: Icons.autorenew_rounded,
      items: [
        AreaItemDef(
          id: 'direction',
          title: 'Base da rotina',
          description:
              'Se o básico do dia a dia está minimamente organizado e funcional.',
          defaultSource: AreaDataSource.estimated,
          weight: 1.1,
          recommendedAction:
              'Calculado automaticamente pela rotina recente e pelo estado da casa.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'goals_review',
          title: 'Constância',
          description:
              'Capacidade de repetir ações úteis com regularidade, mesmo sem perfeição.',
          defaultSource: AreaDataSource.estimated,
          weight: 1.2,
          recommendedAction:
              'Calculado automaticamente pela frequência recente do check-in.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'gratitude',
          title: 'Recuperação',
          description:
              'Capacidade de voltar para o eixo depois de dias ruins ou cansativos.',
          defaultSource: AreaDataSource.estimated,
          weight: 1.0,
          recommendedAction:
              'Calculado automaticamente por sono, humor, estresse e recuperação mental.',
          supportsAutomaticData: true,
        ),
      ],
    ),
    AreaDef(
      id: environmentHome,
      title: 'Ambiente & Casa',
      titleShort: 'Casa',
      subtitle: 'Ordem, limpeza e manutenção',
      description:
          'Mostra se sua casa e ambiente estão ajudando sua vida ou atrapalhando, com base nas tarefas reais da casa.',
      icon: Icons.home,
      items: [
        AreaItemDef(
          id: 'organization',
          title: 'Organização',
          description:
              'Nível de organização do espaço e constância desse cuidado.',
          defaultSource: AreaDataSource.automatic,
          recommendedAction: 'Concluir tarefas de organização da casa.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'cleaning',
          title: 'Limpeza',
          description:
              'Constância da limpeza básica e do cuidado com o ambiente.',
          defaultSource: AreaDataSource.automatic,
          recommendedAction: 'Concluir tarefas de limpeza da casa.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'home_tasks',
          title: 'Pendências domésticas',
          description:
              'Quantidade, peso e envelhecimento das pendências abertas em casa.',
          defaultSource: AreaDataSource.automatic,
          recommendedAction:
              'Calculado automaticamente pelas tarefas domésticas pendentes.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'home_maintenance',
          title: 'Manutenção da casa',
          description: 'Reparos, consertos e cuidados maiores do ambiente.',
          defaultSource: AreaDataSource.automatic,
          recommendedAction:
              'Calculado automaticamente pelas tarefas de manutenção.',
          supportsAutomaticData: true,
        ),
      ],
    ),
    AreaDef(
      id: digitalTech,
      title: 'Digital & Tecnologia',
      titleShort: 'Digital',
      subtitle: 'Uso de tela e distração',
      description:
          'Resume como a tecnologia está ajudando ou atrapalhando sua vida atual.',
      icon: Icons.devices,
      items: [
        AreaItemDef(
          id: 'screen_time',
          title: 'Tempo de tela',
          description: 'Quantidade de tempo gasto em telas.',
          defaultSource: AreaDataSource.manual,
          weight: 1.2,
          recommendedAction: 'Atualizar tempo médio de tela.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'distraction',
          title: 'Distrações',
          description: 'Quanto o digital está atrapalhando seu foco.',
          defaultSource: AreaDataSource.estimated,
          weight: 1.1,
          recommendedAction:
              'Responder o check-in diário para estimar distração digital.',
        ),
        AreaItemDef(
          id: 'night_use',
          title: 'Uso noturno',
          description: 'Uso de tela perto da hora de dormir.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Pode ser ligado depois a dados do celular.',
          supportsAutomaticData: true,
        ),
        AreaItemDef(
          id: 'social_media',
          title: 'Tempo em redes sociais',
          description: 'Peso das redes sociais no seu uso digital.',
          defaultSource: AreaDataSource.manual,
          recommendedAction: 'Pode ser ligado depois a dados do celular.',
          supportsAutomaticData: true,
        ),
      ],
    ),
  ];

  static AreaDef byId(String id) {
    return _defs.firstWhere((d) => d.id == id, orElse: () => _defs.first);
  }

  static List<AreaDef> all() => List.unmodifiable(_defs);

  static List<AreaItemDef> itemsForArea(
    String areaId, {
    required bool includeWomenCycle,
  }) {
    final area = byId(areaId);
    return area.items
        .where((item) {
          if (item.showOnlyForWomen && !includeWomenCycle) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  static AreaItemDef? itemById(
    String areaId,
    String itemId, {
    bool includeWomenCycle = true,
  }) {
    final items = itemsForArea(areaId, includeWomenCycle: includeWomenCycle);
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }
}
