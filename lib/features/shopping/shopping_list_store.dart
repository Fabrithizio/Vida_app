// lib/features/shopping/shopping_list_store.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    required this.done,
    required this.createdAtMs,
  });

  final String id;
  final String text;
  final bool done;
  final int createdAtMs;

  ShoppingItem copyWith({String? text, bool? done}) => ShoppingItem(
    id: id,
    text: text ?? this.text,
    done: done ?? this.done,
    createdAtMs: createdAtMs,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'done': done,
    'createdAtMs': createdAtMs,
  };

  static ShoppingItem fromMap(Map map) => ShoppingItem(
    id: (map['id'] as String?) ?? '',
    text: (map['text'] as String?) ?? '',
    done: (map['done'] as bool?) ?? false,
    createdAtMs: (map['createdAtMs'] as int?) ?? 0,
  );
}

class ShoppingListStore extends ChangeNotifier {
  ShoppingListStore({String boxName = 'shopping_list'}) : _boxName = boxName;

  final String _boxName;
  static const String _itemsKey = 'items';

  bool _loaded = false;
  List<ShoppingItem> _items = const [];

  bool get loaded => _loaded;
  List<ShoppingItem> get items => List.unmodifiable(_items);

  int get pendingCount => _items.where((e) => !e.done).length;

  Future<void> load() async {
    final box = await Hive.openBox(_boxName);
    final raw = box.get(_itemsKey);

    final list = <ShoppingItem>[];
    if (raw is List) {
      for (final it in raw) {
        if (it is Map) list.add(ShoppingItem.fromMap(it));
      }
    }

    list.sort(
      (a, b) => a.done == b.done
          ? a.createdAtMs.compareTo(b.createdAtMs)
          : (a.done ? 1 : -1),
    );

    _items = list;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final box = await Hive.openBox(_boxName);
    await box.put(
      _itemsKey,
      _items.map((e) => e.toMap()).toList(growable: false),
    );
  }

  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final item = ShoppingItem(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      text: t,
      done: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    _items = [item, ..._items];
    await _save();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    _items = _items
        .map((e) => e.id == id ? e.copyWith(done: !e.done) : e)
        .toList(growable: false);

    _items.sort(
      (a, b) => a.done == b.done
          ? a.createdAtMs.compareTo(b.createdAtMs)
          : (a.done ? 1 : -1),
    );

    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items = _items.where((e) => e.id != id).toList(growable: false);
    await _save();
    notifyListeners();
  }

  Future<void> clearDone() async {
    _items = _items.where((e) => !e.done).toList(growable: false);
    await _save();
    notifyListeners();
  }
}
