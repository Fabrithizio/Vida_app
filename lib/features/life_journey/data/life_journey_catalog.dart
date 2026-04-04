// ============================================================================
// FILE: lib/features/life_journey/data/life_journey_catalog.dart
//
// O que este arquivo faz:
// - Centraliza todo o conteúdo da Linha da Vida
// - Separa marcos grandes e pequenos em uma lista simples de manter
// - É o arquivo principal para você adicionar novos conteúdos depois
// ============================================================================
import 'package:flutter/material.dart';
import 'package:vida_app/features/life_journey/domain/life_journey_milestone.dart';

class LifeJourneyCatalog {
  static List<LifeJourneyMilestone> all() {
    return [
      LifeJourneyMilestone.majorBirthday(
        id: 'life-start',
        ageYears: 0,
        icon: Icons.auto_awesome_rounded,
        title: 'Começo da jornada',
        summary: 'O ponto zero da Linha da Vida.',
        body:
            'Este marco representa o começo da caminhada. Ele funciona como a base da linha e ajuda a mostrar que o app pode acompanhar a vida por fases, não só por tarefas.',
        category: 'Base',
        label: 'Início',
      ),
      LifeJourneyMilestone.minorAfterBirth(
        id: 'oral-care-start',
        daysSinceBirth: 30,
        icon: Icons.brush_rounded,
        title: 'Escovar os dentes',
        summary: 'Um conteúdo simples sobre higiene diária.',
        body:
            'Aqui pode entrar um vídeo curto, uma explicação visual ou um passo a passo sobre como cuidar da higiene bucal no dia a dia.',
        label: '30 dias',
      ),
      LifeJourneyMilestone.minorAfterBirth(
        id: 'sleep-routine-start',
        daysSinceBirth: 90,
        icon: Icons.bedtime_rounded,
        title: 'Rotina de sono',
        summary: 'Dormir bem muda humor, foco e energia.',
        body:
            'Conteúdo para ensinar hábitos pequenos de sono: horário mais estável, menos tela antes de dormir e atenção à qualidade do descanso.',
        label: '90 dias',
      ),
      LifeJourneyMilestone.minorAfterBirth(
        id: 'water-habit-start',
        daysSinceBirth: 180,
        icon: Icons.water_drop_rounded,
        title: 'Água e cuidado diário',
        summary: 'Pequeno lembrete de autocuidado.',
        body:
            'Este espaço é bom para conteúdos rápidos sobre hidratação, sinais do corpo e construção de hábitos simples que melhoram a rotina.',
        label: '180 dias',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-12-phase',
        ageYears: 12,
        icon: Icons.trending_up_rounded,
        title: 'Entrada na adolescência',
        summary: 'Uma nova fase de crescimento e autonomia.',
        body:
            'Este marco pode abrir uma visão geral da adolescência: responsabilidade crescente, autocuidado, mudanças de rotina e noção de consequência.',
        category: 'Marco importante',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-12-dental-skill',
        ageYears: 12,
        daysAfterBirthday: 15,
        icon: Icons.clean_hands_rounded,
        title: 'Higiene sem pressa',
        summary: 'Reforço de cuidado diário na prática.',
        body:
            'Conteúdo curto sobre montar uma rotina realista de manhã e à noite, incluindo banho, dentes, roupas e organização do próprio espaço.',
        label: '12 anos + 15 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-12-digital-balance',
        ageYears: 12,
        daysAfterBirthday: 60,
        icon: Icons.phone_android_rounded,
        title: 'Equilíbrio com telas',
        summary: 'Aprender a usar tecnologia com mais consciência.',
        body:
            'Aqui pode entrar um conteúdo rápido sobre pausas, foco, tempo de tela, comparação social e como a tecnologia pode ajudar sem dominar a rotina.',
        label: '12 anos + 60 dias',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-13-puberty',
        ageYears: 13,
        icon: Icons.psychology_alt_rounded,
        title: 'Mudanças do corpo e da mente',
        summary: 'Entender a puberdade com clareza e calma.',
        body:
            'Esse marco pode reunir orientações educativas sobre mudanças comuns da adolescência, emoções mais intensas, autoestima e conversa com responsáveis.',
        category: 'Marco importante',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-13-menstruation',
        ageYears: 13,
        icon: Icons.favorite_rounded,
        title: 'Ciclo menstrual',
        summary: 'Um conteúdo específico para quem precisa desse cuidado.',
        body:
            'Espaço para explicar menstruação de forma acolhedora e informativa, com foco em higiene, sinais do corpo, rotina e quando pedir ajuda.',
        audience: LifeJourneyAudience.female,
        category: 'Saúde',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-14-digital-safety',
        ageYears: 14,
        daysAfterBirthday: 20,
        icon: Icons.security_rounded,
        title: 'Segurança digital',
        summary: 'Privacidade, senha e cuidado ao conversar online.',
        body:
            'Conteúdo pequeno sobre golpes, exposição exagerada, proteção de conta, limites e segurança em redes sociais e jogos.',
        label: '14 anos + 20 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-15-emotional-regulation',
        ageYears: 15,
        daysAfterBirthday: 45,
        icon: Icons.self_improvement_rounded,
        title: 'Organizar emoções',
        summary: 'Aprender a nomear e lidar com o que sente.',
        body:
            'Bom espaço para explicar respiração, pausa, conversa, diário e outras formas saudáveis de regular estresse, raiva e frustração.',
        label: '15 anos + 45 dias',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-16-citizenship',
        ageYears: 16,
        icon: Icons.how_to_vote_rounded,
        title: 'Cidadania e participação',
        summary: 'Fase boa para entender mais do seu papel na sociedade.',
        body:
            'Esse marco pode abrir conteúdos sobre participação social, noção de cidadania, título eleitoral e como decisões públicas afetam a vida real.',
        category: 'Cidadania',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-16-documents',
        ageYears: 16,
        daysAfterBirthday: 25,
        icon: Icons.badge_rounded,
        title: 'Documentos e responsabilidade',
        summary: 'Entender o valor dos próprios dados e documentos.',
        body:
            'Espaço para ensinar a guardar documentos, conferir dados, evitar perda e começar a lidar com processos da vida adulta com mais autonomia.',
        label: '16 anos + 25 dias',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-18-majority',
        ageYears: 18,
        icon: Icons.workspace_premium_rounded,
        title: 'Maioridade',
        summary: 'Uma virada importante na Linha da Vida.',
        body:
            'Este marco pode reunir conteúdos de transição para vida adulta: mais autonomia, mais responsabilidade e cuidado com escolhas, rotina e futuro.',
        category: 'Marco importante',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-18-financial-basis',
        ageYears: 18,
        daysAfterBirthday: 20,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Base financeira',
        summary: 'Noções iniciais para não cair no automático.',
        body:
            'Um conteúdo curto sobre orçamento, gastos, reserva, metas simples e como ter mais clareza ao lidar com dinheiro.',
        label: '18 anos + 20 dias',
      ),
    ];
  }
}
