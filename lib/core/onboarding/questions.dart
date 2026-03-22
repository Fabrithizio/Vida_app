// lib/core/onboarding/questions.dart

enum QuestionType { options, text }

class Question {
  final String id;
  final String question;
  final QuestionType type;
  final List<String> options;

  const Question({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
  });
}

final onboardingQuestions = [
  // ✅ NOVO: apelido/nome
  const Question(
    id: "nickname",
    question: "Como você quer ser chamado(a)?",
    type: QuestionType.text,
  ),

  const Question(
    id: "gender",
    question: "Você é:",
    type: QuestionType.options,
    options: ["Homem", "Mulher"],
  ),

  const Question(
    id: "focus",
    question: "Qual área da vida você quer melhorar primeiro?",
    type: QuestionType.options,
    options: ["Saúde", "Finanças", "Produtividade", "Mental"],
  ),

  const Question(
    id: "goal",
    question: "Qual seu objetivo principal?",
    type: QuestionType.options,
    options: [
      "Organizar minha vida",
      "Ganhar dinheiro",
      "Melhorar saúde",
      "Evoluir pessoalmente",
    ],
  ),
];
