// lib/features/shopping/shopping_list_store.dart
import 'package:flutter/foundation.dart';
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

    _items = _sort(list);
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
      return a.createdAtMs.compareTo(b.createdAtMs);
    });
    return list;
  }
}

class ShoppingCategorizer {
  ShoppingCategorizer._();

  static ShoppingCategory guessCategory(String raw) {
    final text = _normalize(raw);

    // score por categoria
    final scores = <ShoppingCategory, int>{};

    void addScore(ShoppingCategory c, int s) {
      scores[c] = (scores[c] ?? 0) + s;
    }

    for (final entry in _keywords.entries) {
      final cat = entry.key;
      for (final kw in entry.value) {
        if (_containsWordOrPhrase(text, kw)) addScore(cat, 2);
      }
    }

    // heurísticas rápidas (ajudam “qualquer jeito”)
    if (text.contains('kg') || text.contains('quilo') || text.contains('g ')) {
      addScore(ShoppingCategory.fruits, 1);
      addScore(ShoppingCategory.vegetables, 1);
      addScore(ShoppingCategory.meats, 1);
    }
    if (text.contains('deterg') || text.contains('sabao')) {
      addScore(ShoppingCategory.cleaning, 2);
    }

    if (scores.isEmpty) return ShoppingCategory.other;

    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value >= 2 ? best.key : ShoppingCategory.other;
  }

  static bool _containsWordOrPhrase(String text, String kw) {
    final k = _normalize(kw);
    if (k.contains(' ')) return text.contains(k);
    final re = RegExp(r'(^|\s)' + RegExp.escape(k) + r'(\s|$)');
    return re.hasMatch(text);
  }

  static String _normalize(String s) {
    final lower = s.toLowerCase().trim();
    // remove acentos básico (pt-BR)
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    var out = lower;
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  static final Map<ShoppingCategory, List<String>> _keywords = {
    ShoppingCategory.fruits: [
      'banana',
      'maca',
      'maça',
      'pera',
      'uva',
      'mamao',
      'mamão',
      'melancia',
      'melao',
      'melão',
      'abacaxi',
      'laranja',
      'tangerina',
      'manga',
      'morango',
      'limao',
      'limão',
      'abacate',
      'kiwi',
    ],
    ShoppingCategory.vegetables: [
      'alface',
      'tomate',
      'cebola',
      'alho',
      'cenoura',
      'batata',
      'batata doce',
      'brocolis',
      'brócolis',
      'couve',
      'pepino',
      'pimentao',
      'pimentão',
      'abobrinha',
      'berinjela',
      'repolho',
      'beterraba',
      'cheiro verde',
      'salsa',
      'cebolinha',
    ],
    ShoppingCategory.meats: [
      'frango',
      'peito de frango',
      'carne',
      'patinho',
      'acém',
      'acem',
      'picanha',
      'linguica',
      'linguiça',
      'salsicha',
      'bacon',
      'presunto',
      'peixe',
      'tilapia',
      'tilápia',
      'camarao',
      'camarão',
      'ovo',
      'ovos',
    ],
    ShoppingCategory.dairy: [
      'leite',
      'queijo',
      'iogurte',
      'manteiga',
      'requeijao',
      'requeijão',
      'creme de leite',
    ],
    ShoppingCategory.bakery: [
      'pao',
      'pão',
      'paes',
      'pães',
      'bolo',
      'torrada',
      'biscoito',
      'bolacha',
      'farinha',
    ],
    ShoppingCategory.drinks: [
      'agua',
      'água',
      'suco',
      'refrigerante',
      'cafe',
      'café',
      'cha',
      'chá',
      'cerveja',
      'vinho',
      'energetico',
      'energético',
    ],
    ShoppingCategory.cleaning: [
      'detergente',
      'sabao',
      'sabão',
      'sabao em po',
      'sabão em pó',
      'agua sanitaria',
      'água sanitária',
      'desinfetante',
      'amaciante',
      'alvejante',
      'limpa vidro',
      'esponja',
      'saco de lixo',
      'vassoura',
      'rodo',
      'pano',
    ],
    ShoppingCategory.hygiene: [
      'shampoo',
      'condicionador',
      'sabonete',
      'pasta de dente',
      'escova de dente',
      'fio dental',
      'desodorante',
      'absorvente',
      'papel higienico',
      'papel higiênico',
      'fralda',
    ],
    ShoppingCategory.pharmacy: [
      'dipirona',
      'paracetamol',
      'ibuprofeno',
      'soro',
      'curativo',
      'band aid',
      'vitamina',
      'pomada',
      'remedio',
      'remédio',
    ],
    ShoppingCategory.home: [
      'pilha',
      'lampada',
      'lâmpada',
      'vela',
      'tomada',
      'fio',
      'extensao',
      'extensão',
      'fita',
      'cola',
    ],
    ShoppingCategory.pet: [
      'racao',
      'ração',
      'areia',
      'petisco',
      'coleira',
      'shampoo pet',
    ],

    ShoppingCategory.spices: [
      'curcuma',
      'pimenta',
      'orégano',
      'oregano',
      'canela',
      'paprica',
      'páprica',
      'cominho',
      'sal',
    ],
  };
}
