import 'dart:math';

final _rnd = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 20).toRadixString(36)}';

class Item {
  Item({required this.id, required this.name, this.checked = false});

  final String id;
  String name;
  bool checked;

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        name: json['name'] as String,
        checked: json['checked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'checked': checked};

  Item copy() => Item(id: newId(), name: name, checked: checked);
}

class PackCategory {
  PackCategory({required this.id, required this.name, this.icon, List<Item>? items})
      : items = items ?? [];

  final String id;
  String name;
  String? icon;
  final List<Item> items;

  factory PackCategory.fromJson(Map<String, dynamic> json) => PackCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        'items': items.map((e) => e.toJson()).toList(),
      };

  PackCategory copy() => PackCategory(
        id: newId(),
        name: name,
        icon: icon,
        items: items.map((e) => e.copy()).toList(),
      );
}

/// A reusable, pre-made set of categories/items that can be poured into a
/// packing list. Structurally like a list but without checked state or a
/// packed section — it's a template.
class Preset {
  Preset({
    required this.id,
    required this.name,
    required this.icon,
    List<PackCategory>? categories,
  }) : categories = categories ?? [];

  final String id;
  String name;
  String icon;
  final List<PackCategory> categories;

  int get totalItems => categories.fold(0, (sum, c) => sum + c.items.length);

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? '🎒',
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => PackCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'categories': categories.map((e) => e.toJson()).toList(),
      };

  Preset copy({String? newName}) => Preset(
        id: newId(),
        name: newName ?? name,
        icon: icon,
        categories: categories.map((e) => e.copy()).toList(),
      );

  /// Builds a preset from a live list, dropping checked state.
  factory Preset.fromList(PackingList list, {String? name}) => Preset(
        id: newId(),
        name: name ?? list.name,
        icon: list.icon,
        categories: list.categories.map((c) => c.copy()).toList()
          ..forEach((c) {
            for (final i in c.items) {
              i.checked = false;
            }
          }),
      );

  /// Builds a single-category preset from one category of a list.
  factory Preset.fromCategory(PackCategory cat, {required String icon}) {
    final copied = cat.copy();
    for (final i in copied.items) {
      i.checked = false;
    }
    return Preset(
      id: newId(),
      name: cat.name,
      icon: icon,
      categories: [copied],
    );
  }
}

class PackingList {
  PackingList({
    required this.id,
    required this.name,
    required this.icon,
    this.hidePacked = false,
    List<PackCategory>? categories,
  }) : categories = categories ?? [];

  final String id;
  String name;
  String icon;
  bool hidePacked;
  final List<PackCategory> categories;

  int get totalItems => categories.fold(0, (sum, c) => sum + c.items.length);

  int get packedItems => categories.fold(
      0, (sum, c) => sum + c.items.where((i) => i.checked).length);

  bool get isReady => totalItems > 0 && packedItems == totalItems;

  double get progress => totalItems == 0 ? 0 : packedItems / totalItems;

  factory PackingList.fromJson(Map<String, dynamic> json) => PackingList(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? '🎒',
        hidePacked: json['hidePacked'] as bool? ?? false,
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => PackCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        if (hidePacked) 'hidePacked': true,
        'categories': categories.map((e) => e.toJson()).toList(),
      };

  PackingList copy({String? newName}) => PackingList(
        id: newId(),
        name: newName ?? name,
        icon: icon,
        categories: categories.map((e) => e.copy()).toList(),
      );
}
