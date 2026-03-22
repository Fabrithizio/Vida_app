// lib/features/shopping/shopping_list_store.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum ShoppingCategory {
  fruits,
  vegetables,
  cleaning,
  meats,
  dairy,
  bakery,
  drinks,
  hygiene,
  pharmacy,
  home,
  pet,
  spices,
  other,
}

String categoryLabel(ShoppingCategory c) {
  switch (c) {
    case ShoppingCategory.fruits:
      return 'Frutas';
    case ShoppingCategory.vegetables:
      return 'Verduras';
    case ShoppingCategory.cleaning:
      return 'Limpeza';
    case ShoppingCategory.meats:
      return 'Carnes';
    case ShoppingCategory.dairy:
      return 'Laticínios';
    case ShoppingCategory.bakery:
      return 'Padaria';
    case ShoppingCategory.drinks:
      return 'Bebidas';
    case ShoppingCategory.hygiene:
      return 'Higiene';
    case ShoppingCategory.pharmacy:
      return 'Farmácia';
    case ShoppingCategory.home:
      return 'Casa';
    case ShoppingCategory.pet:
      return 'Pet';
    case ShoppingCategory.spices:
      return 'Temperos';
    case ShoppingCategory.other:
      return 'Outros';
  }
}

@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.text,
    required this.done,
    required this.createdAtMs,
    required this.category,
  });

  final String id;
  final String text;
  final bool done;
  final int createdAtMs;
  final ShoppingCategory category;

  ShoppingItem copyWith({
    String? text,
    bool? done,
    ShoppingCategory? category,
  }) => ShoppingItem(
    id: id,
    text: text ?? this.text,
    done: done ?? this.done,
    createdAtMs: createdAtMs,
    category: category ?? this.category,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'done': done,
    'createdAtMs': createdAtMs,
    'category': category.name,
  };

  static ShoppingItem fromMap(Map map) {
    final raw = (map['category'] as String?) ?? ShoppingCategory.other.name;
    final cat = ShoppingCategory.values.cast<ShoppingCategory?>().firstWhere(
      (c) => c?.name == raw,
      orElse: () => ShoppingCategory.other,
    )!;

    return ShoppingItem(
      id: (map['id'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      done: (map['done'] as bool?) ?? false,
      createdAtMs: (map['createdAtMs'] as int?) ?? 0,
      category: cat,
    );
  }
}

class ShoppingListStore extends ChangeNotifier {
  ShoppingListStore({String boxName = _kLegacyBoxName})
    : _legacyBoxName = boxName;

  static const String _kLegacyBoxName = 'shopping_list';
  static const String _boxPrefix = 'shopping_list_';
  static const String _itemsKey = 'items';

  final String _legacyBoxName;

  bool _loaded = false;
  List<ShoppingItem> _items = const [];

  bool get loaded => _loaded;
  List<ShoppingItem> get items => List.unmodifiable(_items);
  int get pendingCount => _items.where((e) => !e.done).length;

  String _uidOrAnon() {
    final u = FirebaseAuth.instance.currentUser;
    final uid = (u?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  /// Box por usuário. Mantém o legacy apenas como fallback de migração (não usado no write).
  String get _boxName => '$_boxPrefix${_uidOrAnon()}';

  Future<Box<dynamic>> _open() => Hive.openBox<dynamic>(_boxName);

  /// Migra itens do box antigo global ('shopping_list') para o box do usuário atual,
  /// e apaga o legado para parar de vazar entre contas.
  Future<void> _migrateLegacyIfAny() async {
    if (_legacyBoxName != _kLegacyBoxName) return;

    final legacy = await Hive.openBox<dynamic>(_kLegacyBoxName);
    final raw = legacy.get(_itemsKey);

    if (raw is! List || raw.isEmpty) return;

    final target = await _open();
    final already = target.get(_itemsKey);
    if (already is List && already.isNotEmpty) {
      await legacy.delete(_itemsKey);
      return;
    }

    await target.put(_itemsKey, raw);
    await legacy.delete(_itemsKey);
  }

  Future<void> load() async {
    await _migrateLegacyIfAny();

    final box = await _open();
    final raw = box.get(_itemsKey);

    final list = <ShoppingItem>[];
    if (raw is List) {
      for (final it in raw) {
        if (it is Map) list.add(ShoppingItem.fromMap(it));
      }
    }

    _items = _sort(list);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final box = await _open();
    await box.put(
      _itemsKey,
      _items.map((e) => e.toMap()).toList(growable: false),
    );
  }

  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final cat = ShoppingCategorizer.guessCategory(t);

    final item = ShoppingItem(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      text: t,
      done: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      category: cat,
    );

    _items = _sort([item, ..._items]);
    await _save();
    notifyListeners();
  }

  Future<void> addMany(Iterable<String> texts) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final newItems = <ShoppingItem>[];
    for (final raw in texts) {
      final t = raw.trim();
      if (t.isEmpty) continue;

      newItems.add(
        ShoppingItem(
          id: 's_${DateTime.now().microsecondsSinceEpoch}',
          text: t,
          done: false,
          createdAtMs: nowMs,
          category: ShoppingCategorizer.guessCategory(t),
        ),
      );
    }

    if (newItems.isEmpty) return;

    _items = _sort([...newItems, ..._items]);
    await _save();
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    _items = _sort(
      _items
          .map((e) => e.id == id ? e.copyWith(done: !e.done) : e)
          .toList(growable: false),
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

  Future<void> recategorizeAll() async {
    _items = _sort(
      _items
          .map(
            (e) =>
                e.copyWith(category: ShoppingCategorizer.guessCategory(e.text)),
          )
          .toList(growable: false),
    );
    await _save();
    notifyListeners();
  }

  static List<ShoppingItem> _sort(List<ShoppingItem> list) {
    int categoryOrder(ShoppingCategory c) => switch (c) {
      ShoppingCategory.fruits => 0,
      ShoppingCategory.vegetables => 1,
      ShoppingCategory.meats => 2,
      ShoppingCategory.dairy => 3,
      ShoppingCategory.bakery => 4,
      ShoppingCategory.drinks => 5,
      ShoppingCategory.cleaning => 6,
      ShoppingCategory.hygiene => 7,
      ShoppingCategory.pharmacy => 8,
      ShoppingCategory.home => 9,
      ShoppingCategory.pet => 10,
      ShoppingCategory.spices => 11,
      ShoppingCategory.other => 99,
    };

    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ca = categoryOrder(a.category);
      final cb = categoryOrder(b.category);
      if (ca != cb) return ca.compareTo(cb);
      return b.createdAtMs.compareTo(a.createdAtMs);
    });

    return list;
  }
}

/// Mantive como estava no seu arquivo (você já tinha esse util em algum lugar).
/// Se der erro "ShoppingCategorizer not found", me manda esse arquivo que eu ajusto.
class ShoppingCategorizer {
  static ShoppingCategory guessCategory(String text) {
    final t = text.toLowerCase();

    if (t.contains('banana') || t.contains('maç') || t.contains('uva')) {
      return ShoppingCategory.fruits;
    }
    if (t.contains('alface') || t.contains('tomate') || t.contains('cenoura')) {
      return ShoppingCategory.vegetables;
    }
    if (t.contains('sabão') || t.contains('detergente') || t.contains('limp')) {
      return ShoppingCategory.cleaning;
    }
    if (t.contains('frango') || t.contains('carne') || t.contains('peixe')) {
      return ShoppingCategory.meats;
    }
    if (t.contains('leite') || t.contains('queijo') || t.contains('iogurte')) {
      return ShoppingCategory.dairy;
    }
    if (t.contains('pão') || t.contains('bolo')) {
      return ShoppingCategory.bakery;
    }
    if (t.contains('suco') ||
        t.contains('refrigerante') ||
        t.contains('água')) {
      return ShoppingCategory.drinks;
    }
    if (t.contains('shampoo') ||
        t.contains('sabonete') ||
        t.contains('higiene')) {
      return ShoppingCategory.hygiene;
    }
    if (t.contains('remédio') || t.contains('vitamina') || t.contains('farm')) {
      return ShoppingCategory.pharmacy;
    }
    if (t.contains('ração') || t.contains('pet')) {
      return ShoppingCategory.pet;
    }
    if (t.contains('sal') || t.contains('pimenta') || t.contains('temper')) {
      return ShoppingCategory.spices;
    }

    return ShoppingCategory.other;
  }
}
