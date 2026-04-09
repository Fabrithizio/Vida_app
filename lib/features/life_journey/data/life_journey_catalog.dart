// ============================================================================
// FILE: lib/features/life_journey/data/life_journey_catalog.dart
//
// O que este arquivo faz:
// - Centraliza o conteúdo da Linha da Vida.
// - Organiza marcos por idade com conteúdo mais útil para o mundo real.
// - Separa o que vale para todo mundo e o que é específico para homem/mulher.
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
        summary: 'O início da sua linha pessoal de crescimento.',
        body:
            'A Linha da Vida existe para mostrar que amadurecer não é decorar regras. '
            'É aprender o que o mundo real cobra em cada fase: corpo, rotina, dinheiro, relações, trabalho, limites e direção.',
        category: 'Base',
        label: 'Início',
      ),
      LifeJourneyMilestone.minorAfterBirth(
        id: 'life-foundation',
        daysSinceBirth: 120,
        icon: Icons.foundation_rounded,
        title: 'Pequenos hábitos viram base',
        summary: 'Sono, higiene e rotina simples já constroem o futuro.',
        body:
            'Antes de grandes metas, existe base. Dormir melhor, comer de forma mais limpa, ter horários e manter o ambiente minimamente em ordem criam segurança para a vida inteira.',
        label: '120 dias',
        category: 'Base',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-12-juventude',
        ageYears: 12,
        icon: Icons.rocket_launch_rounded,
        title: 'Juventude: primeiros degraus',
        summary: 'Seu corpo muda e sua autonomia começa a crescer.',
        body:
            'Dos 12 aos 15, o foco é criar alicerce: higiene impecável, rotina mínima, respeito próprio, menos piloto automático e mais consciência do que você consome e faz.',
        category: 'Marco importante',
        label: '12 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-12-higiene',
        ageYears: 12,
        daysAfterBirthday: 20,
        icon: Icons.clean_hands_rounded,
        title: 'Higiene impecável',
        summary: 'Cuidar do corpo é respeito próprio.',
        body:
            'Seu corpo mudou. Banho, dentes, pele, roupas limpas e atenção ao próprio cheiro deixam de ser detalhe. Autocuidado não é vaidade: é dignidade, saúde e presença.',
        category: 'Saúde',
        label: '12 + 20 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-12-boredom',
        ageYears: 12,
        daysAfterBirthday: 55,
        icon: Icons.hourglass_top_rounded,
        title: 'O tédio também ensina',
        summary: 'Nem todo vazio precisa ser preenchido com tela.',
        body:
            'Quando você aprende a ficar um pouco sem estímulo, sua criatividade, observação e autonomia crescem. O tédio saudável abre espaço para ideias, leitura e descanso mental.',
        category: 'Tempo',
        label: '12 + 55 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-12-authority',
        ageYears: 12,
        daysAfterBirthday: 95,
        icon: Icons.record_voice_over_rounded,
        title: 'Questionar com respeito',
        summary: 'Aprender a discordar sem se destruir por dentro.',
        body:
            'Maturidade não é obedecer calado, nem explodir por qualquer coisa. É saber perguntar, entender limites e sustentar sua posição sem perder o respeito.',
        category: 'Relações',
        label: '12 + 95 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-13-body-mind',
        ageYears: 13,
        icon: Icons.psychology_alt_rounded,
        title: 'Mudanças do corpo e da mente',
        summary: 'Entender a puberdade com menos medo e mais clareza.',
        body:
            'Essa fase mistura energia, vergonha, curiosidade e intensidade. Conhecer o que está mudando ajuda a reduzir culpa, comparação e confusão.',
        category: 'Marco importante',
        label: '13 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-13-food-basics',
        ageYears: 13,
        daysAfterBirthday: 35,
        icon: Icons.restaurant_rounded,
        title: 'Comida de verdade',
        summary: 'Nutrição básica é energia, foco e autonomia.',
        body:
            'Entender o básico de alimentação evita viver refém de ultraprocessados, delivery e picos de energia. Comer bem não é perfeição: é constância possível.',
        category: 'Saúde',
        label: '13 + 35 dias',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-13-cycle',
        ageYears: 13,
        icon: Icons.favorite_rounded,
        title: 'Entender o ciclo biológico',
        summary: 'Conhecer o corpo ajuda a viver com mais clareza.',
        body:
            'Aprender sobre o ciclo menstrual, sinais do corpo, autocuidado e rotina reduz medo e aumenta autonomia. Saber o que acontece com você é uma forma de liberdade.',
        audience: LifeJourneyAudience.female,
        category: 'Saúde',
        label: '13 anos',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-14-digital-education',
        ageYears: 14,
        icon: Icons.phone_android_rounded,
        title: 'Educação digital',
        summary: 'O que você posta pode te acompanhar por anos.',
        body:
            'Sua reputação online vale mais do que parece. Exposição demais, prints, golpes, comparações e impulsos digitais deixam rastros. Aprender isso cedo protege seu futuro.',
        category: 'Digital',
        label: '14 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-14-digital-safety',
        ageYears: 14,
        daysAfterBirthday: 20,
        icon: Icons.security_rounded,
        title: 'Segurança digital',
        summary: 'Senha, privacidade e atenção valem ouro.',
        body:
            'Golpes, contas roubadas, chantagem, localização exposta e conversas perigosas são reais. Segurança digital é parte do autocuidado moderno.',
        category: 'Segurança',
        label: '14 + 20 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-14-character',
        ageYears: 14,
        daysAfterBirthday: 80,
        icon: Icons.visibility_rounded,
        title: 'Leitura de caráter',
        summary: 'Observe ações, não só discursos.',
        body:
            'Aprender a perceber incoerência, manipulação, interesse e respeito nas atitudes das pessoas evita muita dor. Gente segura costuma ter palavra e postura.',
        category: 'Relações',
        label: '14 + 80 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-15-limits',
        ageYears: 15,
        icon: Icons.shield_rounded,
        title: 'Limites e respeito',
        summary: 'Ser querido é bom; ser respeitado é essencial.',
        body:
            'Nessa fase, aprender a dizer não, sair de ambientes ruins e não negociar o próprio valor muda o rumo de muitas relações.',
        category: 'Marco importante',
        label: '15 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-15-assertive-communication',
        ageYears: 15,
        daysAfterBirthday: 30,
        icon: Icons.chat_bubble_rounded,
        title: 'Comunicação assertiva',
        summary: 'Pedir, negar e conversar com clareza é uma habilidade.',
        body:
            'Falar bem não é falar muito. É saber se expressar sem agressão, sem se apagar e sem culpa. Isso vale em casa, amizades, trabalho e namoro.',
        category: 'Relações',
        label: '15 + 30 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-15-consent',
        ageYears: 15,
        daysAfterBirthday: 85,
        icon: Icons.handshake_rounded,
        title: 'Consentimento e rejeição',
        summary: 'Não é não. E frustração também precisa ser aprendida.',
        body:
            'Respeitar limites e lidar com rejeição sem destruir sua autoestima faz parte de crescer. Relações saudáveis não funcionam na pressão nem na posse.',
        category: 'Relações',
        label: '15 + 85 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-16-social-mask',
        ageYears: 16,
        icon: Icons.workspaces_rounded,
        title: 'Máscara social',
        summary: 'Ambiente profissional pede postura, não falsidade.',
        body:
            'Ser você mesmo não significa agir igual em todo lugar. Existe hora de brincar e hora de sustentar postura, foco, pontualidade e respeito ao contexto.',
        category: 'Trabalho',
        label: '16 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-16-documents',
        ageYears: 16,
        daysAfterBirthday: 25,
        icon: Icons.badge_rounded,
        title: 'Documentos e responsabilidade',
        summary: 'Cuidar dos próprios dados já é parte da vida real.',
        body:
            'Guardar documentos, conferir informações, saber para que servem e manter o básico organizado evita muito problema quando a vida adulta apertar.',
        category: 'Autonomia',
        label: '16 + 25 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-16-cooking',
        ageYears: 16,
        daysAfterBirthday: 70,
        icon: Icons.soup_kitchen_rounded,
        title: 'Culinária básica',
        summary: 'Saber se alimentar é liberdade.',
        body:
            'Preparar uma refeição simples, segura e barata muda a saúde e o bolso. Quem não aprende o básico vira dependente de conveniência cara.',
        category: 'Autonomia',
        label: '16 + 70 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-17-direction',
        ageYears: 17,
        icon: Icons.explore_rounded,
        title: 'Escolhas e direção',
        summary: 'Nem toda decisão define sua vida, mas toda decisão ensina.',
        body:
            'Essa fase cobra mais comparação e pressão. O ponto é aprender a escolher com mais consciência, sem esperar ter certeza absoluta antes de agir.',
        category: 'Propósito',
        label: '17 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-17-life-maintenance',
        ageYears: 17,
        daysAfterBirthday: 45,
        icon: Icons.build_circle_rounded,
        title: 'Manutenção de vida',
        summary: 'Trocar, limpar, costurar, cuidar.',
        body:
            'Trocar uma lâmpada, limpar a casa, costurar um botão, organizar um armário e resolver o básico não é glamour. É maturidade funcional.',
        category: 'Autonomia',
        label: '17 + 45 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-17-digital-curriculum',
        ageYears: 17,
        daysAfterBirthday: 95,
        icon: Icons.folder_shared_rounded,
        title: 'Seu currículo invisível',
        summary: 'Internet também fala por você.',
        body:
            'Mesmo antes de um emprego formal, sua presença online passa sinais. Humor, agressividade, exposição, consistência e interesses contam uma história sobre você.',
        category: 'Digital',
        label: '17 + 95 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-18-majority',
        ageYears: 18,
        icon: Icons.workspace_premium_rounded,
        title: 'Maioridade',
        summary: 'Mais liberdade, mais responsabilidade, menos desculpas.',
        body:
            'A vida adulta começa sem manual. Liberdade sem direção vira bagunça. O ideal é usar essa virada para ganhar autonomia real, não só sensação de independência.',
        category: 'Marco importante',
        label: '18 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-18-financial-basis',
        ageYears: 18,
        daysAfterBirthday: 20,
        icon: Icons.account_balance_wallet_rounded,
        title: 'Gestão financeira real',
        summary: 'Dinheiro é ferramenta de liberdade, não de pose.',
        body:
            'Aqui entra o básico que a escola quase não ensina: orçamento, juros compostos, crédito, parcelamento, reserva, diferença entre querer e poder e o custo de viver no automático.',
        category: 'Finanças',
        label: '18 + 20 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-18-credit-tax',
        ageYears: 18,
        daysAfterBirthday: 65,
        icon: Icons.receipt_long_rounded,
        title: 'Crédito, impostos e boletos',
        summary: 'Entender regras evita dívida boba e susto caro.',
        body:
            'Cartão não é renda extra. Juros não são detalhe. Imposto não some porque você ignora. Aprender cedo evita anos de bagunça financeira.',
        category: 'Finanças',
        label: '18 + 65 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-18-male-health',
        ageYears: 18,
        daysAfterBirthday: 120,
        icon: Icons.monitor_heart_rounded,
        title: 'Saúde masculina sem tabu',
        summary: 'Exame e acompanhamento não diminuem ninguém.',
        body:
            'Conhecer o próprio corpo, fazer acompanhamento médico quando necessário e falar sobre saúde com naturalidade evita negligência e medo desnecessário.',
        audience: LifeJourneyAudience.male,
        category: 'Saúde',
        label: '18 + 120 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-18-female-reproductive-health',
        ageYears: 18,
        daysAfterBirthday: 120,
        icon: Icons.health_and_safety_rounded,
        title: 'Saúde reprodutiva com autonomia',
        summary: 'Conhecer o próprio corpo é parte da liberdade.',
        body:
            'Métodos contraceptivos, prevenção, exames e sinais do corpo devem ser tratados com clareza e sem vergonha. Informação boa protege sua autonomia.',
        audience: LifeJourneyAudience.female,
        category: 'Saúde',
        label: '18 + 120 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-20-young-adult',
        ageYears: 20,
        icon: Icons.trending_up_rounded,
        title: 'Transição para o jovem adulto',
        summary: 'Você começa a colher o que repete.',
        body:
            'Daqui em diante, hábitos, amigos, energia e dinheiro passam a mostrar consequências mais claras. O que parecia pequeno começa a cobrar juros.',
        category: 'Marco importante',
        label: '20 anos',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-21-time-value',
        ageYears: 21,
        icon: Icons.schedule_rounded,
        title: 'O valor do tempo',
        summary: 'Duas horas focadas podem vencer um dia inteiro disperso.',
        body:
            'Aprender a proteger seu tempo muda estudo, trabalho, saúde e dinheiro. Tempo é o ativo mais democrático e mais desperdiçado.',
        category: 'Tempo',
        label: '21 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-21-preventive-health',
        ageYears: 21,
        daysAfterBirthday: 35,
        icon: Icons.favorite_border_rounded,
        title: 'Saúde preventiva',
        summary: 'Sono, hidratação e check-up deixam de ser opcionais.',
        body:
            'Quando a rotina aperta, muita gente começa a trocar saúde por produtividade. A conta chega. Prevenção custa menos do que conserto.',
        category: 'Saúde',
        label: '21 + 35 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-21-networking',
        ageYears: 21,
        daysAfterBirthday: 90,
        icon: Icons.groups_rounded,
        title: 'Networking real',
        summary: 'Nem toda companhia fortalece; algumas só consomem.',
        body:
            'Cultivar gente séria, confiável e competente abre portas, amplia repertório e melhora seu padrão de conversa e decisão.',
        category: 'Trabalho',
        label: '21 + 90 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-24-work-identity',
        ageYears: 24,
        icon: Icons.work_history_rounded,
        title: 'Trabalho e identidade',
        summary:
            'Você não é só o que produz, mas também não vive sem estrutura.',
        body:
            'Fase boa para entender diferença entre vocação, emprego, conta para pagar e projeto de longo prazo. Nem tudo precisa estar resolvido, mas precisa estar em movimento.',
        category: 'Trabalho',
        label: '24 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-24-failure-data',
        ageYears: 24,
        daysAfterBirthday: 60,
        icon: Icons.analytics_rounded,
        title: 'Fracasso é dado',
        summary: 'Erro não precisa virar identidade.',
        body:
            'Você vai errar. O ponto é extrair informação, ajustar rota e seguir. Culpa sem aprendizado só drena energia.',
        category: 'Emoções',
        label: '24 + 60 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-26-adult-relationships',
        ageYears: 26,
        icon: Icons.favorite_border_rounded,
        title: 'Relacionamentos adultos',
        summary:
            'Carinho sem limite vira desgaste; limite sem carinho vira dureza.',
        body:
            'Relações maduras pedem conversa clara, responsabilidade afetiva, espaço, respeito e capacidade de encarar conflitos sem teatro constante.',
        category: 'Relações',
        label: '26 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-26-radical-responsibility',
        ageYears: 26,
        daysAfterBirthday: 50,
        icon: Icons.flag_circle_rounded,
        title: 'Responsabilidade radical',
        summary: 'A culpa pode não ser sua; a resposta agora é.',
        body:
            'Em muitos pontos da vida, você não controla o início do problema. Mas, com o tempo, passa a responder pelo que faz diante dele. Isso amadurece qualquer pessoa.',
        category: 'Autonomia',
        label: '26 + 50 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-26-female-independence',
        ageYears: 26,
        daysAfterBirthday: 100,
        icon: Icons.savings_rounded,
        title: 'Independência financeira total',
        summary: 'Ter renda própria amplia segurança e escolha.',
        body:
            'Dinheiro próprio não é só conforto. Também é proteção, margem de decisão e menos vulnerabilidade em relações ruins ou ambientes abusivos.',
        audience: LifeJourneyAudience.female,
        category: 'Finanças',
        label: '26 + 100 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-26-male-emotional-literacy',
        ageYears: 26,
        daysAfterBirthday: 100,
        icon: Icons.psychology_rounded,
        title: 'Alfabetização emocional',
        summary: 'Nem tudo que parece raiva é raiva.',
        body:
            'Dar nome ao que sente melhora relação, autocontrole e decisão. Medo, tristeza, vergonha e frustração muitas vezes se escondem atrás de dureza e silêncio.',
        audience: LifeJourneyAudience.male,
        category: 'Emoções',
        label: '26 + 100 dias',
      ),

      LifeJourneyMilestone.majorBirthday(
        id: 'age-30-consolidated-adult',
        ageYears: 30,
        icon: Icons.apartment_rounded,
        title: 'Adulto consolidado',
        summary: 'Agora fica mais claro o que você está construindo.',
        body:
            'Dos 30 em diante, o jogo deixa de ser só experimentar. A vida começa a mostrar padrão: como você cuida do corpo, do dinheiro, do amor, do trabalho e do próprio caos.',
        category: 'Marco importante',
        label: '30 anos',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-30-therapy',
        ageYears: 30,
        daysAfterBirthday: 30,
        icon: Icons.self_improvement_rounded,
        title: 'Terapia e autoconhecimento',
        summary: 'Entender sua história evita repeti-la no automático.',
        body:
            'Resolver feridas antigas, padrões repetidos e reações automáticas reduz dano em relações, filhos, trabalho e autoconceito. Olhar para dentro pode ser trabalho de adulto forte.',
        category: 'Emoções',
        label: '30 + 30 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-31-grief',
        ageYears: 31,
        daysAfterBirthday: 90,
        icon: Icons.spa_rounded,
        title: 'Luto e perda',
        summary:
            'Perder pessoas faz parte da vida; aprender a atravessar isso também.',
        body:
            'Ninguém gosta de tocar nesse assunto, mas a maturidade também passa por lidar com ausência, saudade, morte e mudança sem endurecer por completo.',
        category: 'Emoções',
        label: '31 + 90 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-33-legacy',
        ageYears: 33,
        daysAfterBirthday: 45,
        icon: Icons.auto_graph_rounded,
        title: 'Legado',
        summary: 'O que você está deixando além das contas pagas?',
        body:
            'Legado pode ser família, trabalho, projeto, caráter, presença ou serviço. O ponto é sair do sobreviver puro e começar a construir algo que permaneça.',
        category: 'Legado',
        label: '33 + 45 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-35-female-intuition-safety',
        ageYears: 35,
        daysAfterBirthday: 40,
        icon: Icons.shield_moon_rounded,
        title: 'Intuição e segurança',
        summary: 'Perceber risco cedo também é inteligência.',
        body:
            'Se um lugar, pessoa ou situação parecem errados, vale ouvir esse alerta. Cuidado e firmeza podem proteger sua paz, seu corpo e sua autonomia.',
        audience: LifeJourneyAudience.female,
        category: 'Segurança',
        label: '35 + 40 dias',
      ),
      LifeJourneyMilestone.minorAfterBirthday(
        id: 'age-35-male-self-control',
        ageYears: 35,
        daysAfterBirthday: 40,
        icon: Icons.fitness_center_rounded,
        title: 'Força sob controle',
        summary: 'Autocontrole vale mais do que explosão.',
        body:
            'Firmeza de caráter não é agressividade. É presença, proteção, constância e capacidade de responder sem se deixar dominar por impulso.',
        audience: LifeJourneyAudience.male,
        category: 'Autonomia',
        label: '35 + 40 dias',
      ),
      LifeJourneyMilestone.majorBirthday(
        id: 'age-38-quiet-leadership',
        ageYears: 38,
        icon: Icons.workspace_premium_rounded,
        title: 'Liderança serena',
        summary:
            'Quem amadurece de verdade passa a organizar melhor a própria volta.',
        body:
            'Liderar não é mandar em todo mundo. É sustentar direção, exemplo, responsabilidade e tranquilidade suficiente para guiar sem esmagar.',
        category: 'Legado',
        label: '38 anos',
      ),
    ];
  }
}
