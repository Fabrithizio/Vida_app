// ============================================================================
// FILE: lib/features/alerts/alerts_center_repository.dart
//
// O que este arquivo faz:
// - Guarda os alertas lidos do usuário
// - Evita reabrir tudo como novo sempre
// - Mantém o sininho com badge real do app inteiro
// ============================================================================

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/life_alert.dart';

class AlertsCenterRepository {
  static const _readIdsKey = 'alerts_center_read_ids_v1';

  String _scopedKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return _readIdsKey;
    return '$uid:$_readIdsKey';
  }

  Future<Set<String>> loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scopedKey()) ?? const <String>[];
    return raw.toSet();
  }

  Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadReadIds();
    current.add(id);
    await prefs.setStringList(_scopedKey(), current.toList());
  }

  Future<void> markAllAsRead(List<LifeAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = alerts.map((item) => item.id).toSet();
    await prefs.setStringList(_scopedKey(), ids.toList());
  }

  Future<void> clearReadState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey());
  }

  Future<String> exportSnapshot(List<LifeAlert> alerts) async {
    final payload = alerts.map((item) => item.toMap()).toList();
    return jsonEncode(payload);
  }
}
