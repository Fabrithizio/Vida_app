class Question {
  final String id;
  final String question;
  final List<String> options;

  Question({required this.id, required this.question, required this.options});
}

final onboardingQuestions = [
  Question(id: "gender", question: "Você é:", options: ["Homem", "Mulher"]),

  Question(
    id: "focus",
    question: "Qual área da vida você quer melhorar primeiro?",
    options: ["Saúde", "Finanças", "Produtividade", "Mental"],
  ),

  Question(
    id: "goal",
    question: "Qual seu objetivo principal?",
    options: [
      "Organizar minha vida",
      "Ganhar dinheiro",
      "Melhorar saúde",
      "Evoluir pessoalmente",
    ],
  ),
];
