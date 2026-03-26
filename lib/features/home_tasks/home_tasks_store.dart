import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum HomeTaskEffort { quick, major }

enum HomeTaskCategory { cleaning, organization, maintenance }

enum HomeTaskArea {
  wholeHouse,
  kitchen,
  bathroom,
  bedroom,
  livingRoom,
  laundry,
  outdoor,
  other,
}

String homeTaskEffortLabel(HomeTaskEffort value) {
  switch (value) {
    case HomeTaskEffort.quick:
      return 'Serviço rápido';
    case HomeTaskEffort.major:
      return 'Serviço maior';
  }
}

String homeTaskCategoryLabel(HomeTaskCategory value) {
  switch (value) {
    case HomeTaskCategory.cleaning:
      return 'Limpeza';
    case HomeTaskCategory.organization:
      return 'Organização';
    case HomeTaskCategory.maintenance:
      return 'Manutenção';
  }
}

String homeTaskAreaLabel(HomeTaskArea value) {
  switch (value) {
    case HomeTaskArea.wholeHouse:
      return 'Casa toda';
    case HomeTaskArea.kitchen:
      return 'Cozinha';
    case HomeTaskArea.bathroom:
      return 'Banheiro';
    case HomeTaskArea.bedroom:
      return 'Quarto';
    case HomeTaskArea.livingRoom:
      return 'Sala';
    case HomeTaskArea.laundry:
      return 'Lavanderia';
    case HomeTaskArea.outdoor:
      return 'Área externa';
    case HomeTaskArea.other:
      return 'Outros';
  }
}

@immutable
class HomeTaskItem {
  const HomeTaskItem({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.effort,
    required this.category,
    required this.area,
    this.notes,
  });

  final String id;
  final String title;
  final bool done;
  final int createdAtMs;
  final int updatedAtMs;
  final HomeTaskEffort effort;
  final HomeTaskCategory category;
  final HomeTaskArea area;
  final String? notes;

  HomeTaskItem copyWith({
    String? title,
    bool? done,
    int? updatedAtMs,
    HomeTaskEffort? effort,
    HomeTaskCategory? category,
    HomeTaskArea? area,
    Object? notes = _unset,
  }) {
    return HomeTaskItem(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      effort: effort ?? this.effort,
      category: category ?? this.category,
      area: area ?? this.area,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'done': done,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
      'effort': effort.name,
      'category': category.name,
      'area': area.name,
      'notes': notes,
    };
  }

  static HomeTaskItem fromMap(Map<dynamic, dynamic> map) {
    HomeTaskEffort parseEffort(String? raw) {
      return HomeTaskEffort.values.cast<HomeTaskEffort?>().firstWhere(
        (e) => e?.name == raw,
        orElse: () => HomeTaskEffort.quick,
      )!;
    }

    HomeTaskCategory parseCategory(String? raw) {
      return HomeTaskCategory.values.cast<HomeTaskCategory?>().firstWhere(
        (e) => e?.name == raw,
        orElse: () => HomeTaskCategory.cleaning,
      )!;
    }

    HomeTaskArea parseArea(String? raw) {
      return HomeTaskArea.values.cast<HomeTaskArea?>().firstWhere(
        (e) => e?.name == raw,
        orElse: () => HomeTaskArea.other,
      )!;
    }

    return HomeTaskItem(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      done: (map['done'] as bool?) ?? false,
      createdAtMs: (map['createdAtMs'] as int?) ?? 0,
      updatedAtMs: (map['updatedAtMs'] as int?) ?? 0,
      effort: parseEffort(map['effort'] as String?),
      category: parseCategory(map['category'] as String?),
      area: parseArea(map['area'] as String?),
      notes: map['notes'] as String?,
    );
  }
}

const Object _unset = Object();

class HomeTasksStore extends ChangeNotifier {
  HomeTasksStore({String boxName = _kLegacyBoxName}) : _legacyBoxName = boxName;

  static const String _kLegacyBoxName = 'home_tasks';
  static const String _boxPrefix = 'home_tasks_';
  static const String _itemsKey = 'items';
  static const String _seededKey = 'seeded';

  final String _legacyBoxName;

  bool _loaded = false;
  List<HomeTaskItem> _items = const [];

  bool get loaded => _loaded;
  List<HomeTaskItem> get items => List.unmodifiable(_items);

  int get pendingCount => _items.where((e) => !e.done).length;
  int get doneCount => _items.where((e) => e.done).length;
  int get quickPendingCount =>
      _items.where((e) => !e.done && e.effort == HomeTaskEffort.quick).length;
  int get majorPendingCount =>
      _items.where((e) => !e.done && e.effort == HomeTaskEffort.major).length;

  String _uidOrAnon() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = (user?.uid ?? 'anon').trim();
    return uid.isEmpty ? 'anon' : uid;
  }

  String get _boxName => '$_boxPrefix${_uidOrAnon()}';

  Future<Box<dynamic>> _open() => Hive.openBox<dynamic>(_boxName);

  Future<void> _migrateLegacyIfNeeded(Box<dynamic> currentBox) async {
    if (currentBox.get(_itemsKey) != null) return;

    if (!await Hive.boxExists(_legacyBoxName)) return;

    final legacy = await Hive.openBox<dynamic>(_legacyBoxName);
    final raw = legacy.get(_itemsKey);

    if (raw is List && raw.isNotEmpty) {
      await currentBox.put(_itemsKey, raw);
    }

    await legacy.delete(_itemsKey);
  }

  List<HomeTaskItem> _readItemsFromBox(Box<dynamic> box) {
    final raw = box.get(_itemsKey);
    if (raw is! List) return <HomeTaskItem>[];

    return raw
        .whereType<Map>()
        .map((e) => HomeTaskItem.fromMap(e))
        .where((e) => e.id.trim().isNotEmpty && e.title.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        if (a.effort != b.effort) {
          return a.effort.index.compareTo(b.effort.index);
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  }

  Future<void> _write(Box<dynamic> box) async {
    await box.put(
      _itemsKey,
      _items.map((e) => e.toMap()).toList(growable: false),
    );
  }

  Future<void> load() async {
    final box = await _open();
    await _migrateLegacyIfNeeded(box);

    _items = _readItemsFromBox(box);
    _loaded = true;

    final seeded = (box.get(_seededKey) as bool?) ?? false;
    if (!seeded && _items.isEmpty) {
      await seedDefaultItems();
    } else {
      notifyListeners();
    }
  }

  Future<void> seedDefaultItems() async {
    final box = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final defaults = <HomeTaskItem>[
      HomeTaskItem(
        id: 'home_${now}_1',
        title: 'Varrer a casa',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.quick,
        category: HomeTaskCategory.cleaning,
        area: HomeTaskArea.wholeHouse,
      ),
      HomeTaskItem(
        id: 'home_${now}_2',
        title: 'Arrumar a cama',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.quick,
        category: HomeTaskCategory.organization,
        area: HomeTaskArea.bedroom,
      ),
      HomeTaskItem(
        id: 'home_${now}_3',
        title: 'Limpar a pia da cozinha',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.quick,
        category: HomeTaskCategory.cleaning,
        area: HomeTaskArea.kitchen,
      ),
      HomeTaskItem(
        id: 'home_${now}_4',
        title: 'Tirar o lixo',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.quick,
        category: HomeTaskCategory.cleaning,
        area: HomeTaskArea.wholeHouse,
      ),
      HomeTaskItem(
        id: 'home_${now}_5',
        title: 'Organizar roupas fora do lugar',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.quick,
        category: HomeTaskCategory.organization,
        area: HomeTaskArea.bedroom,
      ),
      HomeTaskItem(
        id: 'home_${now}_6',
        title: 'Limpar o banheiro',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.major,
        category: HomeTaskCategory.cleaning,
        area: HomeTaskArea.bathroom,
      ),
      HomeTaskItem(
        id: 'home_${now}_7',
        title: 'Trocar torneira',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.major,
        category: HomeTaskCategory.maintenance,
        area: HomeTaskArea.kitchen,
      ),
      HomeTaskItem(
        id: 'home_${now}_8',
        title: 'Consertar vazamento do banheiro',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.major,
        category: HomeTaskCategory.maintenance,
        area: HomeTaskArea.bathroom,
      ),
      HomeTaskItem(
        id: 'home_${now}_9',
        title: 'Organizar guarda-roupa',
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: HomeTaskEffort.major,
        category: HomeTaskCategory.organization,
        area: HomeTaskArea.bedroom,
      ),
    ];

    _items = defaults;
    await _write(box);
    await box.put(_seededKey, true);
    notifyListeners();
  }

  Future<void> add({
    required String title,
    required HomeTaskEffort effort,
    required HomeTaskCategory category,
    required HomeTaskArea area,
    String? notes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final box = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    _items = [
      HomeTaskItem(
        id: 'home_$now',
        title: trimmed,
        done: false,
        createdAtMs: now,
        updatedAtMs: now,
        effort: effort,
        category: category,
        area: area,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
      ..._items,
    ];

    await _write(box);
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    final box = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    _items = _items
        .map(
          (e) => e.id == id ? e.copyWith(done: !e.done, updatedAtMs: now) : e,
        )
        .toList();

    await _write(box);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final box = await _open();
    _items = _items.where((e) => e.id != id).toList();
    await _write(box);
    notifyListeners();
  }

  Future<void> updateItem(
    String id, {
    required String title,
    required HomeTaskEffort effort,
    required HomeTaskCategory category,
    required HomeTaskArea area,
    String? notes,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final box = await _open();
    final now = DateTime.now().millisecondsSinceEpoch;

    _items = _items
        .map(
          (e) => e.id == id
              ? e.copyWith(
                  title: trimmed,
                  effort: effort,
                  category: category,
                  area: area,
                  notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
                  updatedAtMs: now,
                )
              : e,
        )
        .toList();

    await _write(box);
    notifyListeners();
  }

  Future<void> clearDone() async {
    final box = await _open();
    _items = _items.where((e) => !e.done).toList();
    await _write(box);
    notifyListeners();
  }

  Future<void> resetAndSeedAgain() async {
    final box = await _open();
    await box.delete(_itemsKey);
    await box.delete(_seededKey);
    _items = const [];
    await seedDefaultItems();
  }
}
