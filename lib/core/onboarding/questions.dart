// lib/core/onboarding/questions.dart

enum QuestionType { options, text, number, date }

enum OnboardingStage { personal, life }

class Question {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options;
  final bool optional;
  final String? helper;

  const Question({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.optional = false,
    this.helper,
  });
}

/// Etapa 1: dados pessoais (perfil)
final personalQuestions = <Question>[
  const Question(
    id: 'nickname',
    question: 'Como você quer ser chamado(a) no app?',
    type: QuestionType.text,
    helper: 'Pode ser um apelido. Você pode mudar depois no Perfil.',
  ),
  const Question(
    id: 'gender',
    question: 'Você é:',
    type: QuestionType.options,
    options: ['Homem', 'Mulher', 'Prefiro não dizer'],
  ),
  const Question(
    id: 'dob',
    question: 'Qual sua data de nascimento?',
    type: QuestionType.date,
    helper: 'Formato: DD/MM/AAAA',
  ),
  const Question(
    id: 'cpf',
    question: 'Quer adicionar CPF para liberar recursos no futuro?',
    type: QuestionType.text,
    optional: true,
    helper: 'Opcional. Pode pular. (11 dígitos)',
  ),
];

/// Etapa 2: perguntas sobre a vida (pra personalizar as áreas)
final lifeQuestions = <Question>[
  const Question(
    id: 'focus',
    question: 'Qual área da vida você quer melhorar primeiro?',
    type: QuestionType.options,
    options: [
      'Saúde',
      'Finanças',
      'Produtividade',
      'Mental',
      'Relacionamentos',
    ],
  ),
  const Question(
    id: 'goal',
    question: 'Qual seu objetivo principal?',
    type: QuestionType.options,
    options: [
      'Organizar minha vida',
      'Ganhar dinheiro',
      'Melhorar saúde',
      'Evoluir pessoalmente',
      'Reduzir ansiedade/estresse',
    ],
  ),
  const Question(
    id: 'last_checkup',
    question: 'Quando foi seu último check-up/exame?',
    type: QuestionType.date,
    optional: true,
    helper: 'Opcional. Se não souber, pode pular. (DD/MM/AAAA)',
  ),
  const Question(
    id: 'sleep_hours',
    question: 'Quantas horas você dorme em média por noite?',
    type: QuestionType.number,
    optional: true,
    helper: 'Opcional. Ex: 7',
  ),
  const Question(
    id: 'screen_time',
    question: 'Quanto tempo de tela por dia (aprox.)?',
    type: QuestionType.options,
    optional: true,
    options: ['< 2h', '2–4h', '4–6h', '6–8h', '8h+'],
  ),
  const Question(
    id: 'study_work',
    question: 'Onde você passa mais tempo?:',
    type: QuestionType.options,
    optional: true,
    options: ['Estudos', 'Trabalho', 'Ambos', 'Outro'],
  ),
];
