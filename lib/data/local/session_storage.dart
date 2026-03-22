import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _kTokenKey = 'session_token';
  static const _kNicknamePrefix = 'nickname_';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }

  // ===========================================================================
  // Nickname por usuário (UID)
  // ===========================================================================

  Future<void> saveNickname(String uid, String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kNicknamePrefix$uid', nickname);
  }

  Future<String?> readNickname(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_kNicknamePrefix$uid');
  }

  Future<void> clearNickname(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kNicknamePrefix$uid');
  }
}
