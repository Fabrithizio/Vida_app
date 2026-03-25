import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const String _kTokenKey = 'session_token';
  static const String _kNicknamePrefix = 'nickname_';
  static const String _kBirthDatePrefix = 'birth_date_';

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

  Future<void> saveBirthDate(String uid, DateTime birthDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kBirthDatePrefix$uid',
      DateTime(
        birthDate.year,
        birthDate.month,
        birthDate.day,
      ).toIso8601String(),
    );
  }

  Future<DateTime?> readBirthDate(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    final raw =
        prefs.getString('$_kBirthDatePrefix$uid') ??
        prefs.getString('$uid:birthDate') ??
        prefs.getString('$uid:birthdate') ??
        prefs.getString('$uid:dateOfBirth') ??
        prefs.getString('$uid:dob');

    if (raw == null || raw.trim().isEmpty) return null;

    return DateTime.tryParse(raw.trim());
  }

  Future<void> clearBirthDate(String uid) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('$_kBirthDatePrefix$uid');
    await prefs.remove('$uid:birthDate');
    await prefs.remove('$uid:birthdate');
    await prefs.remove('$uid:dateOfBirth');
    await prefs.remove('$uid:dob');
  }
}
