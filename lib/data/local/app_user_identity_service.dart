// ============================================================================
// FILE: lib/data/local/app_user_identity_service.dart
//
// O que faz:
// - Centraliza a regra de nome exibido do usuário dentro do app
// - Prioriza o apelido salvo no app antes do nome da conta
// - Mantém o nome do Google/Firebase intacto, usando ele só como fallback
//
// Regra:
// 1. apelido salvo no app
// 2. displayName da conta
// 3. parte do email antes do @
// 4. "Usuário"
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:vida_app/data/local/session_storage.dart';

class AppUserIdentityService {
  AppUserIdentityService({SessionStorage? storage})
    : _storage = storage ?? SessionStorage();

  final SessionStorage _storage;

  Future<String> displayNameForUser(User? user) async {
    if (user == null) return 'Usuário';

    final nick = (await _storage.readNickname(user.uid))?.trim() ?? '';
    if (nick.isNotEmpty) return nick;

    final display = (user.displayName ?? '').trim();
    if (display.isNotEmpty) return display;

    final email = (user.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;

    return 'Usuário';
  }

  Future<String> displayNameForCurrentUser() async {
    return displayNameForUser(FirebaseAuth.instance.currentUser);
  }

  Future<bool> hasNickname(User? user) async {
    if (user == null) return false;
    final nick = (await _storage.readNickname(user.uid))?.trim() ?? '';
    return nick.isNotEmpty;
  }
}
