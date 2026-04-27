// ============================================================================
// FILE: lib/features/shopping/shopping_list_store.dart
//
// O que faz:
// - gerencia múltiplas listas de compras por usuário
// - migra dados do formato antigo de lista única
// - salva e lê listas/itens no Hive
// - mantém compatibilidade com o sistema atual e com entrada por voz
//
// Melhoria desta versão:
// - suporte a mais de uma lista
// - item com quantidade, unidade, nota e favorito
// - parser rápido para textos como "banana 2kg"
// - classificador muito mais amplo
// - recategorização melhor
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum ShoppingCategory {
  fruits,
  vegetables,
  groceries,
  meats,
  dairy,
  bakery,
  drinks,
  snacks,
  frozen,
  cleaning,
  hygiene,
  pharmacy,
  home,
  pet,
  spices,
  baby,
  paper,
  other,
}

String categoryLabel(ShoppingCategory c) {
  switch (c) {
    case ShoppingCategory.fruits:
      return 'Frutas';
    case ShoppingCategory.vegetables:
      return 'Verduras';
    case ShoppingCategory.groceries:
      return 'Mercearia';
    case ShoppingCategory.meats:
      return 'Carnes';
    case ShoppingCategory.dairy:
      return 'Laticínios';
    case ShoppingCategory.bakery:
      return 'Padaria';
    case ShoppingCategory.drinks:
      return 'Bebidas';
    case ShoppingCategory.snacks:
      return 'Lanches';
    case ShoppingCategory.frozen:
      return 'Congelados';
    case ShoppingCategory.cleaning:
      return 'Limpeza';
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
    case ShoppingCategory.baby:
      return 'Bebê';
    case ShoppingCategory.paper:
      return 'Papelaria';
    case ShoppingCategory.other:
      return 'Outros';
  }
}

enum ShoppingUnit { unit, kg, g, l, ml, pack, box, bottle, jar, bag, dozen }

String shoppingUnitLabel(ShoppingUnit unit) {
  switch (unit) {
    case ShoppingUnit.unit:
      return 'un';
    case ShoppingUnit.kg:
      return 'kg';
    case ShoppingUnit.g:
      return 'g';
    case ShoppingUnit.l:
      return 'L';
    case ShoppingUnit.ml:
      return 'mL';
    case ShoppingUnit.pack:
      return 'pct';
    case ShoppingUnit.box:
      return 'cx';
    case ShoppingUnit.bottle:
      return 'garrafa';
    case ShoppingUnit.jar:
      return 'pote';
    case ShoppingUnit.bag:
      return 'saco';
    case ShoppingUnit.dozen:
      return 'dúzia';
  }
}

@immutable
class ShoppingListModel {
  const ShoppingListModel({
    required this.id,
    required this.name,
    required this.createdAtMs,
    this.iconName = 'shopping_cart',
    this.colorValue,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final String iconName;
  final int? colorValue;

  ShoppingListModel copyWith({
    String? name,
    String? iconName,
    Object? colorValue = _unset,
  }) {
    return ShoppingListModel(
      id: id,
      name: name ?? this.name,
      createdAtMs: createdAtMs,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue == _unset ? this.colorValue : colorValue as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdAtMs': createdAtMs,
    'iconName': iconName,
    'colorValue': colorValue,
  };

  static ShoppingListModel fromMap(Map map) {
    return ShoppingListModel(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Lista',
      createdAtMs: (map['createdAtMs'] as int?) ?? 0,
      iconName: (map['iconName'] as String?) ?? 'shopping_cart',
      colorValue: map['colorValue'] as int?,
    );
  }
}

const Object _unset = Object();

@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.listId,
    required this.text,
    required this.done,
    required this.createdAtMs,
    required this.category,
    this.quantity,
    this.unit = ShoppingUnit.unit,
    this.note,
    this.favorite = false,
  });

  final String id;
  final String listId;
  final String text;
  final bool done;
  final int createdAtMs;
  final ShoppingCategory category;
  final double? quantity;
  final ShoppingUnit unit;
  final String? note;
  final bool favorite;

  String get quantityLabel {
    final q = quantity;
    if (q == null || q <= 0) return '';
    final pretty = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
    return '$pretty ${shoppingUnitLabel(unit)}';
  }

  ShoppingItem copyWith({
    String? listId,
    String? text,
    bool? done,
    ShoppingCategory? category,
    Object? quantity = _unset,
    ShoppingUnit? unit,
    Object? note = _unset,
    bool? favorite,
  }) {
    return ShoppingItem(
      id: id,
      listId: listId ?? this.listId,
      text: text ?? this.text,
      done: done ?? this.done,
      createdAtMs: createdAtMs,
      category: category ?? this.category,
      quantity: quantity == _unset ? this.quantity : quantity as double?,
      unit: unit ?? this.unit,
      note: note == _unset ? this.note : note as String?,
      favorite: favorite ?? this.favorite,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'listId': listId,
    'text': text,
    'done': done,
    'createdAtMs': createdAtMs,
    'category': category.name,
    'quantity': quantity,
    'unit': unit.name,
    'note': note,
    'favorite': favorite,
  };

  static ShoppingItem fromMap(Map map) {
    final rawCategory =
        (map['category'] as String?) ?? ShoppingCategory.other.name;
    final rawUnit = (map['unit'] as String?) ?? ShoppingUnit.unit.name;

    final cat = ShoppingCategory.values.firstWhere(
      (c) => c.name == rawCategory,
      orElse: () => ShoppingCategory.other,
    );
    final unit = ShoppingUnit.values.firstWhere(
      (u) => u.name == rawUnit,
      orElse: () => ShoppingUnit.unit,
    );

    return ShoppingItem(
      id: (map['id'] as String?) ?? '',
      listId: (map['listId'] as String?) ?? 'default',
      text: (map['text'] as String?) ?? '',
      done: (map['done'] as bool?) ?? false,
      createdAtMs: (map['createdAtMs'] as int?) ?? 0,
      category: cat,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: unit,
      note: map['note'] as String?,
      favorite: (map['favorite'] as bool?) ?? false,
    );
  }
}

class ParsedShoppingInput {
  const ParsedShoppingInput({
    required this.text,
    required this.category,
    required this.quantity,
    required this.unit,
  });

  final String text;
  final ShoppingCategory category;
  final double? quantity;
  final ShoppingUnit unit;
}

class ShoppingListStore extends ChangeNotifier {
  ShoppingListStore({String boxName = _kLegacyBoxName})
    : _legacyBoxName = boxName;

  static const String _kLegacyBoxName = 'shopping_list';
  static const String _boxPrefix = 'shopping_list_';
  static const String _itemsKey = 'items';
  static const String _listsKey = 'lists';
  static const String _selectedListIdKey = 'selected_list_id';

  final String _legacyBoxName;

  bool _loaded = false;
  List<ShoppingItem> _items = const [];
  List<ShoppingListModel> _lists = const [];
  String? _selectedListId;

  String? _loadedForBoxName;
  Box<dynamic>? _boxCache;
  Future<Box<dynamic>>? _boxFuture;

  bool get loaded => _loaded;
  List<ShoppingItem> get allItems => List.unmodifiable(_items);
  List<ShoppingListModel> get lists => List.unmodifiable(_lists);

  String get selectedListId {
    final current = (_selectedListId ?? '').trim();
    if (current.isNotEmpty && _lists.any((e) => e.id == current))
      return current;
    if (_lists.isNotEmpty) return _lists.first.id;
    return 'default';
  }

  ShoppingListModel? get selectedList {
    final id = selectedListId;
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  List<ShoppingItem> get items => itemsForList(selectedListId);

  int get pendingCount => items.where((e) => !e.done).length;

  int pendingCountForList(String listId) =>
      itemsForList(listId).where((e) => !e.done).length;

  List<ShoppingItem> itemsForList(String listId) {
    return _items.where((e) => e.listId == listId).toList(growable: false);
  }

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  String get _boxName => '$_boxPrefix${_uidOrAnon()}';

  Future<Box<dynamic>> _open() async {
    final targetBoxName = _boxName;
    final cached = _boxCache;
    if (cached != null && cached.isOpen && cached.name == targetBoxName) {
      return cached;
    }

    final pending = _boxFuture;
    if (pending != null) {
      final box = await pending;
      if (box.name == targetBoxName) return box;
    }

    final future = Hive.openBox<dynamic>(targetBoxName).then((box) {
      _boxCache = box;
      return box;
    });
    _boxFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_boxFuture, future)) {
        _boxFuture = null;
      }
    }
  }

  Future<void> _migrateLegacyIfAny() async {
    if (_legacyBoxName != _kLegacyBoxName) return;

    final legacy = await Hive.openBox<dynamic>(_kLegacyBoxName);
    final rawItems = legacy.get(_itemsKey);
    if (rawItems is! List || rawItems.isEmpty) return;

    final target = await _open();
    final already = target.get(_itemsKey);

    if (already is List && already.isNotEmpty) {
      await legacy.delete(_itemsKey);
      return;
    }

    final defaultList = ShoppingListModel(
      id: 'default',
      name: 'Casa',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      iconName: 'home',
    );

    final migratedItems = rawItems
        .map((raw) {
          if (raw is! Map) return null;
          final item = ShoppingItem.fromMap(raw);
          return item.copyWith(listId: 'default');
        })
        .whereType<ShoppingItem>()
        .map((e) => e.toMap())
        .toList(growable: false);

    await target.put(_listsKey, [defaultList.toMap()]);
    await target.put(_selectedListIdKey, 'default');
    await target.put(_itemsKey, migratedItems);
    await legacy.delete(_itemsKey);
  }

  Future<void> load({bool force = false}) async {
    final targetBoxName = _boxName;
    if (!force && _loaded && _loadedForBoxName == targetBoxName) {
      return;
    }

    await _migrateLegacyIfAny();
    final box = await _open();

    final rawLists = box.get(_listsKey);
    final rawItems = box.get(_itemsKey);
    final selected = (box.get(_selectedListIdKey) as String?)?.trim();

    final lists = <ShoppingListModel>[];
    if (rawLists is List) {
      for (final raw in rawLists) {
        if (raw is Map) {
          lists.add(ShoppingListModel.fromMap(raw));
        }
      }
    }

    if (lists.isEmpty) {
      lists.add(
        ShoppingListModel(
          id: 'default',
          name: 'Casa',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          iconName: 'home',
        ),
      );
    }

    final items = <ShoppingItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          final item = ShoppingItem.fromMap(raw);
          items.add(
            item.copyWith(
              listId: item.listId.trim().isEmpty ? lists.first.id : item.listId,
            ),
          );
        }
      }
    }

    _lists = _sortLists(lists);
    _items = _sort(items);
    _selectedListId = selected;
    _loaded = true;
    _loadedForBoxName = targetBoxName;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final box = await _open();
    await box.put(
      _listsKey,
      _lists.map((e) => e.toMap()).toList(growable: false),
    );
    await box.put(
      _itemsKey,
      _items.map((e) => e.toMap()).toList(growable: false),
    );
    await box.put(_selectedListIdKey, selectedListId);
  }

  Future<void> selectList(String listId) async {
    if (!_lists.any((e) => e.id == listId)) return;
    _selectedListId = listId;
    await _save();
    notifyListeners();
  }

  Future<String> createList(
    String name, {
    String iconName = 'shopping_cart',
    int? colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return selectedListId;

    final id = 'list_${DateTime.now().microsecondsSinceEpoch}';
    _lists = _sortLists([
      ShoppingListModel(
        id: id,
        name: trimmed,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        iconName: iconName,
        colorValue: colorValue,
      ),
      ..._lists,
    ]);
    _selectedListId = id;
    await _save();
    notifyListeners();
    return id;
  }

  Future<void> renameList(String listId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    _lists = _sortLists(
      _lists
          .map((e) => e.id == listId ? e.copyWith(name: trimmed) : e)
          .toList(growable: false),
    );
    await _save();
    notifyListeners();
  }

  Future<void> removeList(String listId) async {
    if (_lists.length <= 1) return;
    final fallback = _lists.firstWhere((e) => e.id != listId);
    _items = _items.where((e) => e.listId != listId).toList(growable: false);
    _lists = _lists.where((e) => e.id != listId).toList(growable: false);
    if (selectedListId == listId) {
      _selectedListId = fallback.id;
    }
    await _save();
    notifyListeners();
  }

  ParsedShoppingInput parseInput(String raw) {
    var text = raw.trim();
    if (text.isEmpty) {
      return const ParsedShoppingInput(
        text: '',
        category: ShoppingCategory.other,
        quantity: null,
        unit: ShoppingUnit.unit,
      );
    }

    final regex = RegExp(
      r'^(.*?)(?:\s+|\b)(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|un|und|unid|cx|caixa|pct|pacote|garrafa|pote|saco|dz|duzia|dúzia)?$',
      caseSensitive: false,
    );

    double? quantity;
    var unit = ShoppingUnit.unit;

    final match = regex.firstMatch(text);
    if (match != null) {
      final candidateText = (match.group(1) ?? '').trim();
      final qtyRaw = (match.group(2) ?? '').replaceAll(',', '.');
      final unitRaw = (match.group(3) ?? '').trim().toLowerCase();

      final parsedQty = double.tryParse(qtyRaw);
      if (candidateText.isNotEmpty && parsedQty != null) {
        text = candidateText;
        quantity = parsedQty;
        unit = _unitFromRaw(unitRaw);
      }
    }

    return ParsedShoppingInput(
      text: text,
      category: ShoppingCategorizer.guessCategory(text),
      quantity: quantity,
      unit: unit,
    );
  }

  ShoppingUnit _unitFromRaw(String raw) {
    switch (raw) {
      case 'kg':
        return ShoppingUnit.kg;
      case 'g':
        return ShoppingUnit.g;
      case 'l':
        return ShoppingUnit.l;
      case 'ml':
        return ShoppingUnit.ml;
      case 'pct':
      case 'pacote':
        return ShoppingUnit.pack;
      case 'cx':
      case 'caixa':
        return ShoppingUnit.box;
      case 'garrafa':
        return ShoppingUnit.bottle;
      case 'pote':
        return ShoppingUnit.jar;
      case 'saco':
        return ShoppingUnit.bag;
      case 'dz':
      case 'duzia':
      case 'dúzia':
        return ShoppingUnit.dozen;
      case 'und':
      case 'unid':
      case 'un':
      default:
        return ShoppingUnit.unit;
    }
  }

  Future<void> add(
    String text, {
    String? listId,
    double? quantity,
    ShoppingUnit unit = ShoppingUnit.unit,
    String? note,
    bool favorite = false,
  }) async {
    final parsed = parseInput(text);
    final finalText = parsed.text.trim();
    if (finalText.isEmpty) return;

    final item = ShoppingItem(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      listId: listId ?? selectedListId,
      text: finalText,
      done: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      category: parsed.category,
      quantity: quantity ?? parsed.quantity,
      unit: quantity != null ? unit : parsed.unit,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      favorite: favorite,
    );

    _items = _sort([item, ..._items]);
    await _save();
    notifyListeners();
  }

  Future<void> updateItem(
    String id, {
    String? text,
    double? quantity,
    bool clearQuantity = false,
    ShoppingUnit? unit,
    String? note,
    bool clearNote = false,
    ShoppingCategory? category,
    String? listId,
    bool? favorite,
  }) async {
    _items = _sort(
      _items
          .map((e) {
            if (e.id != id) return e;
            final nextText = (text ?? e.text).trim();
            final autoCategory =
                category ?? ShoppingCategorizer.guessCategory(nextText);
            return e.copyWith(
              text: nextText,
              quantity: clearQuantity ? null : (quantity ?? e.quantity),
              unit: unit ?? e.unit,
              note: clearNote ? null : (note ?? e.note),
              category: autoCategory,
              listId: listId ?? e.listId,
              favorite: favorite ?? e.favorite,
            );
          })
          .toList(growable: false),
    );
    await _save();
    notifyListeners();
  }

  Future<void> addMany(Iterable<String> texts, {String? listId}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final newItems = <ShoppingItem>[];

    for (final raw in texts) {
      final parsed = parseInput(raw);
      final text = parsed.text.trim();
      if (text.isEmpty) continue;

      newItems.add(
        ShoppingItem(
          id: 's_${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
          listId: listId ?? selectedListId,
          text: text,
          done: false,
          createdAtMs: nowMs,
          category: parsed.category,
          quantity: parsed.quantity,
          unit: parsed.unit,
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

  Future<void> toggleFavorite(String id) async {
    _items = _sort(
      _items
          .map((e) => e.id == id ? e.copyWith(favorite: !e.favorite) : e)
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
    _items = _items
        .where((e) => !(e.listId == selectedListId && e.done))
        .toList(growable: false);
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

  static List<ShoppingListModel> _sortLists(List<ShoppingListModel> list) {
    list.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return list;
  }

  static List<ShoppingItem> _sort(List<ShoppingItem> list) {
    int categoryOrder(ShoppingCategory c) => switch (c) {
      ShoppingCategory.fruits => 0,
      ShoppingCategory.vegetables => 1,
      ShoppingCategory.groceries => 2,
      ShoppingCategory.meats => 3,
      ShoppingCategory.dairy => 4,
      ShoppingCategory.bakery => 5,
      ShoppingCategory.drinks => 6,
      ShoppingCategory.snacks => 7,
      ShoppingCategory.frozen => 8,
      ShoppingCategory.cleaning => 9,
      ShoppingCategory.hygiene => 10,
      ShoppingCategory.pharmacy => 11,
      ShoppingCategory.home => 12,
      ShoppingCategory.pet => 13,
      ShoppingCategory.spices => 14,
      ShoppingCategory.baby => 15,
      ShoppingCategory.paper => 16,
      ShoppingCategory.other => 99,
    };

    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;

      final la = a.listId.compareTo(b.listId);
      if (la != 0) return la;

      final ca = categoryOrder(a.category);
      final cb = categoryOrder(b.category);
      if (ca != cb) return ca.compareTo(cb);

      return b.createdAtMs.compareTo(a.createdAtMs);
    });

    return list;
  }
}

class ShoppingCategorizer {
  static ShoppingCategory guessCategory(String text) {
    final t = text.toLowerCase().trim();

    bool hasAny(List<String> values) => values.any((v) => t.contains(v));

    if (hasAny([
      'banana',
      'maçã',
      'maca',
      'uva',
      'laranja',
      'limão',
      'limao',
      'melancia',
      'mamão',
      'mamao',
      'abacaxi',
      'pera',
      'morango',
      'kiwi',
      'manga',
      'abacate',
      'goiaba',
    ])) {
      return ShoppingCategory.fruits;
    }

    if (hasAny([
      'alface',
      'tomate',
      'cenoura',
      'batata',
      'cebola',
      'alho',
      'pepino',
      'couve',
      'repolho',
      'beterraba',
      'abobrinha',
      'brocolis',
      'brócolis',
      'pimentão',
      'pimentao',
      'mandioca',
      'inhame',
    ])) {
      return ShoppingCategory.vegetables;
    }

    if (hasAny([
      'arroz',
      'feijão',
      'feijao',
      'macarrão',
      'macarrao',
      'farinha',
      'açúcar',
      'acucar',
      'sal',
      'óleo',
      'oleo',
      'azeite',
      'molho',
      'extrato',
      'biscoito',
      'bolacha',
      'aveia',
      'granola',
      'café',
      'cafe',
    ])) {
      return ShoppingCategory.groceries;
    }

    if (hasAny([
      'frango',
      'carne',
      'peixe',
      'linguiça',
      'linguica',
      'bacon',
      'salsicha',
      'hambúrguer',
      'hamburguer',
      'filé',
      'file',
      'costela',
      'pernil',
    ])) {
      return ShoppingCategory.meats;
    }

    if (hasAny([
      'leite',
      'queijo',
      'iogurte',
      'manteiga',
      'requeijão',
      'requeijao',
      'creme de leite',
      'coalhada',
      'danone',
      'mussarela',
      'muçarela',
    ])) {
      return ShoppingCategory.dairy;
    }

    if (hasAny([
      'pão',
      'pao',
      'bolo',
      'torrada',
      'rosquinha',
      'croissant',
      'brioche',
      'sonho',
      'pão de forma',
      'pao de forma',
    ])) {
      return ShoppingCategory.bakery;
    }

    if (hasAny([
      'suco',
      'refrigerante',
      'água',
      'agua',
      'café pronto',
      'cafe pronto',
      'chá',
      'cha',
      'energético',
      'energetico',
      'isotônico',
      'isotonico',
      'cerveja sem',
    ])) {
      return ShoppingCategory.drinks;
    }

    if (hasAny([
      'salgadinho',
      'chocolate',
      'bombom',
      'doce',
      'barra de cereal',
      'paçoca',
      'pacoca',
      'amendoim',
      'bala',
      'pirulito',
      'snack',
    ])) {
      return ShoppingCategory.snacks;
    }

    if (hasAny([
      'congelado',
      'lasanha',
      'pizza',
      'hambúrguer congelado',
      'hamburguer congelado',
      'sorvete',
      'polpa',
      'nugget',
    ])) {
      return ShoppingCategory.frozen;
    }

    if (hasAny([
      'sabão',
      'sabao',
      'detergente',
      'desinfetante',
      'amaciante',
      'água sanitária',
      'agua sanitaria',
      'limpa',
      'esponja',
      'vassoura',
      'rodo',
      'multiuso',
      'alvejante',
    ])) {
      return ShoppingCategory.cleaning;
    }

    if (hasAny([
      'shampoo',
      'condicionador',
      'sabonete',
      'pasta de dente',
      'escova de dente',
      'desodorante',
      'papel higiênico',
      'papel higienico',
      'absorvente',
      'higiene',
      'barbeador',
      'fio dental',
    ])) {
      return ShoppingCategory.hygiene;
    }

    if (hasAny([
      'remédio',
      'remedio',
      'vitamina',
      'farm',
      'dipirona',
      'paracetamol',
      'ibuprofeno',
      'bandagem',
      'curativo',
      'pomada',
      'termômetro',
      'termometro',
    ])) {
      return ShoppingCategory.pharmacy;
    }

    if (hasAny([
      'copo',
      'prato',
      'panela',
      'talher',
      'lâmpada',
      'lampada',
      'pilha',
      'bateria',
      'toalha',
      'lençol',
      'lencol',
      'cabide',
    ])) {
      return ShoppingCategory.home;
    }

    if (hasAny([
      'ração',
      'racao',
      'pet',
      'areia de gato',
      'tapete higiênico',
      'tapete higienico',
      'osso',
      'brinquedo pet',
    ])) {
      return ShoppingCategory.pet;
    }

    if (hasAny([
      'pimenta',
      'tempero',
      'orégano',
      'oregano',
      'colorau',
      'cominho',
      'canela',
      'paprica',
      'páprica',
      'vinagre',
    ])) {
      return ShoppingCategory.spices;
    }

    if (hasAny([
      'fralda',
      'lenço umedecido',
      'lenco umedecido',
      'mamadeira',
      'pomada para assadura',
      'papinha',
    ])) {
      return ShoppingCategory.baby;
    }

    if (hasAny([
      'caderno',
      'caneta',
      'lápis',
      'lapis',
      'borracha',
      'cola',
      'papel a4',
      'cartolina',
      'marca-texto',
      'marca texto',
    ])) {
      return ShoppingCategory.paper;
    }

    return ShoppingCategory.other;
  }
}
