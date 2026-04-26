// ============================================================================
// FILE: lib/features/home/presentation/tabs/profile_mutable_answers_service.dart
//
// O que faz:
// - Lê e salva as respostas mutáveis do onboarding no ProfileTab
// - Usa só os ids novos, removendo dependência do legado antigo
// - Centraliza a lógica para ProfileTab ficar menor e mais limpo
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/features/home/presentation/tabs/profile_mutable_question_ids.dart';

class ProfileMutableAnswersService {
  const ProfileMutableAnswersService();

  Future<Map<String, String>> loadAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String, String>{};

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;
    final map = <String, String>{};

    for (final id in profileMutableQuestionIds) {
      final value = (prefs.getString('$uid:$id') ?? '').trim();
      if (value.isNotEmpty) {
        map[id] = value;
      }
    }

    return map;
  }

  Future<void> saveOne(String questionId, String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;
    await prefs.setString('$uid:$questionId', value.trim());
  }

  Future<void> saveMany(Map<String, String> answers) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = user.uid;

    for (final entry in answers.entries) {
      if (!profileMutableQuestionIds.contains(entry.key)) continue;
      await prefs.setString('$uid:${entry.key}', entry.value.trim());
    }
  }
}
