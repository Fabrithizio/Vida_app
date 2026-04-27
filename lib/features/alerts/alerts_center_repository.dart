// ============================================================================
// FILE: lib/features/alerts/alerts_center_repository.dart
//
// O que este arquivo faz:
// - Guarda os alertas lidos do usuário
// - Evita reabrir tudo como novo sempre
// - Mantém o sininho com badge real do app inteiro
//
// Ajuste importante desta versão:
// - agora a leitura é salva por readKey contextual
// - isso evita que alertas baseados em estado reaproveitem o mesmo “lido”
//   para sempre mesmo quando o cenário real mudou
// ============================================================================

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vida_app/data/models/life_alert.dart';

class AlertsCenterRepository {
  static const _readIdsKey = 'alerts_center_read_keys_v2';
  static const _maxStoredKeys = 500;

  String _scopedKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return _readIdsKey;
    return '$uid:$_readIdsKey';
  }

  Future<Set<String>> loadReadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_scopedKey()) ?? const <String>[];
    return raw.toSet();
  }

  Future<void> markAsReadKey(String key) async {
    final safeKey = key.trim();
    if (safeKey.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await loadReadKeys();
    current.add(safeKey);

    final trimmed = current.toList();
    if (trimmed.length > _maxStoredKeys) {
      final overflow = trimmed.length - _maxStoredKeys;
      trimmed.removeRange(0, overflow);
    }

    await prefs.setStringList(_scopedKey(), trimmed);
  }

  Future<void> markAsReadAlert(LifeAlert alert) {
    return markAsReadKey(alert.effectiveReadKey);
  }

  Future<void> markAllAsRead(List<LifeAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadReadKeys();
    current.addAll(alerts.map((item) => item.effectiveReadKey));

    final trimmed = current.toList();
    if (trimmed.length > _maxStoredKeys) {
      final overflow = trimmed.length - _maxStoredKeys;
      trimmed.removeRange(0, overflow);
    }

    await prefs.setStringList(_scopedKey(), trimmed);
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
