import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/finance_transaction.dart';
import 'finance_repository.dart';
import 'finance_transaction_codec.dart';

class HiveFinanceRepository implements FinanceRepository {
  HiveFinanceRepository({
    FinanceTransactionCodec codec = const FinanceTransactionCodec(),
  }) : _codec = codec;

  static const String _boxPrefix = 'finance_box_';
  static const String _globalBox = 'finance_box_global_backup';
  static const String _anonId = 'anon';
  static const String _key = 'transactions';

  final FinanceTransactionCodec _codec;

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? _anonId).trim();
    return uid.isEmpty ? _anonId : uid;
  }

  Future<Box<dynamic>> _openUserBox(String uid) {
    return Hive.openBox<dynamic>('$_boxPrefix$uid');
  }

  Future<Box<dynamic>> _openGlobalBox() {
    return Hive.openBox<dynamic>(_globalBox);
  }

  Future<List<FinanceTransaction>> _readBox(Box<dynamic> box) async {
    final raw = box.get(_key);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => _codec.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<FinanceTransaction> _mergeById(
    Iterable<List<FinanceTransaction>> groups,
  ) {
    final byId = <String, FinanceTransaction>{};
    for (final group in groups) {
      for (final transaction in group) {
        byId[transaction.id] = transaction;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  @override
  Future<List<FinanceTransaction>> loadAll() async {
    final uid = _uidOrAnon();
    final activeBox = await _openUserBox(uid);
    final globalBox = await _openGlobalBox();
    final anonBox = uid == _anonId ? activeBox : await _openUserBox(_anonId);

    final merged = _mergeById([
      await _readBox(globalBox),
      await _readBox(anonBox),
      await _readBox(activeBox),
    ]);

    if (merged.isNotEmpty) {
      await saveAll(merged);
    }

    return merged;
  }

  @override
  Future<void> saveAll(List<FinanceTransaction> items) async {
    final uid = _uidOrAnon();
    final payload = items.map(_codec.toMap).toList();
    final activeBox = await _openUserBox(uid);
    final globalBox = await _openGlobalBox();

    await activeBox.put(_key, payload);
    await globalBox.put(_key, payload);
  }
}
