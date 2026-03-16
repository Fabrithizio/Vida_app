import 'package:flutter/material.dart';
import '../../core/onboarding/questions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int currentQuestion = 0;
  Map<String, String> answers = {};

  void selectAnswer(String answer) async {
    answers[onboardingQuestions[currentQuestion].id] = answer;

    if (currentQuestion < onboardingQuestions.length - 1) {
      setState(() {
        currentQuestion++;
      });
    } else {
      final prefs = await SharedPreferences.getInstance();

      answers.forEach((key, value) {
        prefs.setString(key, value);
      });

      prefs.setBool("onboarding_done", true);

      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = onboardingQuestions[currentQuestion];

    return Scaffold(
      backgroundColor: Colors.black,

      body: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Text(
              question.question,
              style: const TextStyle(color: Colors.white, fontSize: 26),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            ...question.options.map((option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),

                child: ElevatedButton(
                  onPressed: () {
                    selectAnswer(option);
                  },

                  child: Text(option),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
