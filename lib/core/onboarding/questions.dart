// ============================================================================
// FILE: lib/core/onboarding/questions.dart
//
// O que faz:
// - Define a estrutura das perguntas iniciais do app
// - Mantém o fluxo em 2 etapas (personal + life) para não quebrar o gate atual
// - Foca o onboarding em criar o perfil-base do usuário
// - Serve de base para adaptar o check-in diário, a Linha da Vida e outras
//   partes do app conforme idade, rotina, casa, finanças, relações e prioridade
//
// Ajuste desta revisão:
// - remove perguntas iniciais que depois virão melhor por dados automáticos
//   ou por módulos reais do app
// - mantém ids importantes já usados no app, como nickname, gender, dob, cpf,
//   focus e goal
// - reorganiza o onboarding para entender melhor o perfil real do usuário
// ============================================================================

enum QuestionType { info, options, text, date }

enum OnboardingStage { personal, life }

class Question {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options;
  final bool optional;
  final String? helper;
  final String? sectionTitle;
  final String? sectionDescription;
  final String? ctaText;

  const Question({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.optional = false,
    this.helper,
    this.sectionTitle,
    this.sectionDescription,
    this.ctaText,
  });
}

/// Etapa 1: base pessoal do usuário
final List<Question> personalQuestions = [
  const Question(
    id: 'intro_initial_context',
    type: QuestionType.info,
    question: 'Vamos personalizar seu app',
    helper:
        'Estas perguntas criam seu perfil-base dentro do app.\n\n'
        'Com isso, o sistema adapta melhor as áreas, a Linha da Vida e as '
        'perguntas diárias para a sua realidade.\n\n'
        'Responda com sinceridade. Depois você poderá atualizar o que mudar.',
    ctaText: 'Começar',
  ),
  const Question(
    id: 'nickname',
    sectionTitle: 'Identidade básica',
    sectionDescription: 'Base pessoal',
    question: 'Como você quer ser chamado(a) no app?',
    type: QuestionType.text,
    helper: 'Pode ser um apelido. Você pode mudar depois no Perfil.',
  ),
  const Question(
    id: 'gender',
    sectionTitle: 'Identidade básica',
    sectionDescription: 'Base pessoal',
    question: 'Você é:',
    type: QuestionType.options,
    options: ['Homem', 'Mulher'],
  ),
  const Question(
    id: 'dob',
    sectionTitle: 'Identidade básica',
    sectionDescription: 'Base pessoal',
    question: 'Qual sua data de nascimento?',
    type: QuestionType.date,
    helper: 'Digite só os números. As barras serão colocadas automaticamente.',
  ),
  const Question(
    id: 'cpf',
    sectionTitle: 'Identidade básica',
    sectionDescription: 'Base pessoal',
    question: 'Quer adicionar CPF para liberar recursos no futuro?',
    type: QuestionType.text,
    optional: true,
    helper: 'Opcional. Digite só os 11 números do CPF ou toque em pular.',
  ),
];

/// Etapa 2: contexto de vida para personalizar o sistema do app
final List<Question> lifeQuestions = [
  const Question(
    id: 'living_with',
    sectionTitle: 'Casa e convivência',
    sectionDescription: 'Família e lar',
    question: 'Com quem você mora hoje?',
    type: QuestionType.options,
    options: [
      'Moro sozinho(a)',
      'Com pais ou responsáveis',
      'Com parceiro(a)',
      'Com filhos',
      'Com parceiro(a) e filhos',
      'Com familiares',
      'Com amigos / outras pessoas',
    ],
  ),
  const Question(
    id: 'children_count',
    sectionTitle: 'Casa e convivência',
    sectionDescription: 'Família e lar',
    question: 'Você tem filhos?',
    type: QuestionType.options,
    options: ['Não', 'Sim, moram comigo', 'Sim, não moram comigo'],
  ),
  const Question(
    id: 'family_relationship',
    sectionTitle: 'Casa e convivência',
    sectionDescription: 'Família e lar',
    question: 'Hoje, sua vida em casa te ajuda mais ou te desgasta mais?',
    type: QuestionType.options,
    options: [
      'Ajuda muito',
      'Ajuda mais do que desgasta',
      'Meio a meio',
      'Desgasta mais do que ajuda',
      'Desgasta muito',
    ],
  ),
  const Question(
    id: 'home_routine_load',
    sectionTitle: 'Casa e convivência',
    sectionDescription: 'Família e lar',
    question: 'A rotina da sua casa costuma ser:',
    type: QuestionType.options,
    options: ['Leve', 'Moderada', 'Corrida', 'Muito puxada', 'Instável'],
  ),
  const Question(
    id: 'study_work',
    sectionTitle: 'Rotina principal',
    sectionDescription: 'Trabalho, estudos e direção',
    question: 'Hoje sua rotina principal é mais ligada a:',
    type: QuestionType.options,
    options: [
      'Estudos',
      'Trabalho',
      'Trabalho e estudos',
      'Casa e família',
      'Organização da vida',
      'Estou sem rotina definida no momento',
    ],
  ),
  const Question(
    id: 'occupation_type',
    sectionTitle: 'Rotina principal',
    sectionDescription: 'Trabalho, estudos e direção',
    question: 'Hoje sua principal ocupação é:',
    type: QuestionType.options,
    options: [
      'Estudante',
      'Empregado(a) fixo(a)',
      'Autônomo(a) / freelancer',
      'Empreendo',
      'Cuido da casa / família',
      'Estou desempregado(a)',
      'Estou em fase de transição',
    ],
  ),
  const Question(
    id: 'work_schedule_format',
    sectionTitle: 'Rotina principal',
    sectionDescription: 'Trabalho, estudos e direção',
    question: 'Sua rotina principal acontece mais em qual formato?',
    type: QuestionType.options,
    options: [
      'Presencial',
      'Remoto',
      'Híbrido',
      'Varia muito',
      'Não se aplica',
    ],
  ),
  const Question(
    id: 'work_demand_type',
    sectionTitle: 'Rotina principal',
    sectionDescription: 'Trabalho, estudos e direção',
    question: 'No seu dia a dia, o que mais pesa?',
    type: QuestionType.options,
    options: [
      'Mais físico',
      'Mais mental',
      'Os dois igualmente',
      'Depende muito do dia',
    ],
  ),
  const Question(
    id: 'work_field',
    sectionTitle: 'Rotina principal',
    sectionDescription: 'Trabalho, estudos e direção',
    question: 'Sua rotina principal costuma exigir mais o quê de você?',
    type: QuestionType.options,
    options: [
      'Foco mental',
      'Esforço físico',
      'Pressão emocional',
      'Organização',
      'Um pouco de tudo',
    ],
  ),
  const Question(
    id: 'health_self_rating',
    sectionTitle: 'Saúde base',
    sectionDescription: 'Corpo e contexto',
    question: 'Como você descreveria sua saúde hoje?',
    type: QuestionType.options,
    options: ['Muito boa', 'Boa', 'Média', 'Ruim', 'Muito ruim'],
  ),
  const Question(
    id: 'health_limitations',
    sectionTitle: 'Saúde base',
    sectionDescription: 'Corpo e contexto',
    question:
        'Você tem alguma limitação física, condição de saúde ou cansaço '
        'frequente que afete sua rotina?',
    type: QuestionType.options,
    options: [
      'Não',
      'Sim, pouco',
      'Sim, moderadamente',
      'Sim, bastante',
      'Prefiro não responder',
    ],
  ),
  const Question(
    id: 'last_checkup',
    sectionTitle: 'Saúde base',
    sectionDescription: 'Corpo e contexto',
    question: 'Quando foi seu último check-up ou exame geral?',
    type: QuestionType.date,
    optional: true,
    helper:
        'Opcional. Digite só os números. As barras serão colocadas automaticamente.',
  ),
  const Question(
    id: 'stress_level',
    sectionTitle: 'Mente e emocional',
    sectionDescription: 'Mental e emocional',
    question: 'Como está seu nível de estresse hoje?',
    type: QuestionType.options,
    options: ['Muito baixo', 'Baixo', 'Médio', 'Alto', 'Muito alto'],
  ),
  const Question(
    id: 'emotional_state',
    sectionTitle: 'Mente e emocional',
    sectionDescription: 'Mental e emocional',
    question: 'Como está seu emocional na maior parte dos dias?',
    type: QuestionType.options,
    options: ['Muito bem', 'Bem', 'Oscilando', 'Mal', 'Muito mal'],
  ),
  const Question(
    id: 'rest_capacity',
    sectionTitle: 'Mente e emocional',
    sectionDescription: 'Mental e emocional',
    question:
        'Você sente que consegue se recuperar bem depois de dias pesados?',
    type: QuestionType.options,
    options: [
      'Sim, com facilidade',
      'Na maioria das vezes',
      'Mais ou menos',
      'Quase nunca',
      'Não',
    ],
  ),
  const Question(
    id: 'mental_load',
    sectionTitle: 'Mente e emocional',
    sectionDescription: 'Mental e emocional',
    question: 'Sua rotina hoje te deixa mais:',
    type: QuestionType.options,
    options: [
      'Leve',
      'Equilibrado(a)',
      'Cansado(a)',
      'Sobrecarregado(a)',
      'Esgotado(a)',
    ],
  ),
  const Question(
    id: 'financial_situation',
    sectionTitle: 'Finanças base',
    sectionDescription: 'Finanças e estabilidade',
    question: 'Como você vê sua situação financeira hoje?',
    type: QuestionType.options,
    options: [
      'Muito tranquila',
      'Estável',
      'Apertada',
      'Instável',
      'Muito difícil',
    ],
  ),
  const Question(
    id: 'income_stability',
    sectionTitle: 'Finanças base',
    sectionDescription: 'Finanças e estabilidade',
    question: 'Sua renda hoje é mais:',
    type: QuestionType.options,
    options: [
      'Muito estável',
      'Relativamente estável',
      'Variável',
      'Muito instável',
      'Não tenho renda no momento',
    ],
  ),
  const Question(
    id: 'financial_main_difficulty',
    sectionTitle: 'Finanças base',
    sectionDescription: 'Finanças e estabilidade',
    question: 'Hoje o dinheiro pesa mais em quê para você?',
    type: QuestionType.options,
    options: [
      'Ganhar dinheiro',
      'Controlar gastos',
      'Quitar dívidas',
      'Guardar dinheiro',
      'Organizar tudo',
      'Não pesa muito agora',
    ],
  ),
  const Question(
    id: 'dependents_financial',
    sectionTitle: 'Finanças base',
    sectionDescription: 'Finanças e estabilidade',
    question: 'Hoje você tem alguém que depende financeiramente de você?',
    type: QuestionType.options,
    options: ['Não', 'Sim, um pouco', 'Sim, bastante'],
  ),
  const Question(
    id: 'social_life',
    sectionTitle: 'Relações e apoio',
    sectionDescription: 'Relações e conexões',
    question: 'Como está sua vida social hoje?',
    type: QuestionType.options,
    options: [
      'Muito boa',
      'Boa',
      'Mais ou menos',
      'Fraca',
      'Quase inexistente',
    ],
  ),
  const Question(
    id: 'emotional_support',
    sectionTitle: 'Relações e apoio',
    sectionDescription: 'Relações e conexões',
    question: 'Você sente que tem apoio emocional quando precisa?',
    type: QuestionType.options,
    options: [
      'Sim, muito',
      'Sim, o suficiente',
      'Mais ou menos',
      'Quase não',
      'Não',
    ],
  ),
  const Question(
    id: 'loneliness',
    sectionTitle: 'Relações e apoio',
    sectionDescription: 'Relações e conexões',
    question: 'Na maior parte do tempo, você se sente mais:',
    type: QuestionType.options,
    options: [
      'Muito conectado(a)',
      'Conectado(a)',
      'Neutro(a)',
      'Sozinho(a)',
      'Muito sozinho(a)',
    ],
  ),
  const Question(
    id: 'personal_organization',
    sectionTitle: 'Organização e constância',
    sectionDescription: 'Hábitos, constância e ambiente',
    question: 'Como costuma estar sua organização pessoal?',
    type: QuestionType.options,
    options: ['Muito boa', 'Boa', 'Média', 'Ruim', 'Muito ruim'],
  ),
  const Question(
    id: 'home_organization',
    sectionTitle: 'Organização e constância',
    sectionDescription: 'Hábitos, constância e ambiente',
    question: 'Como costuma estar a organização da sua casa ou ambiente?',
    type: QuestionType.options,
    options: [
      'Muito boa',
      'Boa',
      'Média',
      'Ruim',
      'Muito ruim',
      'Não se aplica',
    ],
  ),
  const Question(
    id: 'consistency',
    sectionTitle: 'Organização e constância',
    sectionDescription: 'Hábitos, constância e ambiente',
    question:
        'Você sente que consegue manter constância nas coisas importantes?',
    type: QuestionType.options,
    options: [
      'Sim, muito',
      'Sim, razoavelmente',
      'Mais ou menos',
      'Quase não',
      'Não consigo',
    ],
  ),
  const Question(
    id: 'routine_predictability',
    sectionTitle: 'Organização e constância',
    sectionDescription: 'Hábitos, constância e ambiente',
    question: 'No geral, sua rotina hoje é mais:',
    type: QuestionType.options,
    options: [
      'Muito previsível',
      'Mais previsível do que caótica',
      'Meio termo',
      'Mais caótica do que previsível',
      'Muito caótica',
    ],
  ),
  const Question(
    id: 'routine_main_weight',
    sectionTitle: 'Organização e constância',
    sectionDescription: 'Hábitos, constância e ambiente',
    question: 'Hoje, o que mais pesa na sua rotina?',
    type: QuestionType.options,
    options: [
      'Falta de tempo',
      'Cansaço',
      'Dinheiro',
      'Família / casa',
      'Trabalho / estudos',
      'Saúde',
      'Emocional',
      'Falta de organização',
    ],
  ),
  const Question(
    id: 'focus',
    sectionTitle: 'Prioridade atual',
    sectionDescription: 'Objetivo e foco',
    question: 'Qual área da vida mais precisa de atenção hoje?',
    type: QuestionType.options,
    options: [
      'Corpo & saúde',
      'Mente & emoções',
      'Finanças',
      'Trabalho',
      'Projetos & progresso',
      'Relações',
      'Hábitos & constância',
      'Ambiente & casa',
      'Digital & tecnologia',
    ],
  ),
  const Question(
    id: 'goal',
    sectionTitle: 'Prioridade atual',
    sectionDescription: 'Objetivo e foco',
    question: 'Qual é sua prioridade principal neste momento?',
    type: QuestionType.options,
    options: [
      'Me organizar',
      'Ter mais constância',
      'Melhorar emocional',
      'Melhorar rotina',
      'Melhorar saúde',
      'Melhorar finanças',
      'Sair do caos',
      'Evoluir em metas e projetos',
    ],
  ),
  const Question(
    id: 'app_help',
    sectionTitle: 'Prioridade atual',
    sectionDescription: 'Objetivo e foco',
    question: 'O que você mais quer que o app te ajude a melhorar agora?',
    type: QuestionType.options,
    options: [
      'Clareza',
      'Organização',
      'Disciplina',
      'Foco',
      'Equilíbrio',
      'Progresso',
      'Controle emocional',
      'Controle da rotina',
    ],
  ),
  const Question(
    id: 'start_preference',
    sectionTitle: 'Prioridade atual',
    sectionDescription: 'Objetivo e foco',
    question: 'Você quer começar focando mais em quê?',
    type: QuestionType.options,
    options: [
      'No que está pior',
      'No que vai dar resultado mais rápido',
      'No básico do dia a dia',
      'Em uma área específica',
      'Em melhorar tudo aos poucos',
    ],
  ),
];
