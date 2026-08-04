import 'dart:math';

final _random = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

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

  /// A copy with every item unpacked. Saved categories are reusable blocks, so
  /// they must never carry last trip's ticks into the next list.
  PackCategory copyUnchecked() =>
      copy()..items.forEach((item) => item.checked = false);
}

class PackingList {
  PackingList({
    required this.id,
    required this.name,
    required this.icon,
    List<Item>? items,
    List<PackCategory>? categories,
  })  : items = items ?? [],
        categories = categories ?? [];

  final String id;
  String name;
  String icon;

  /// Loose items that belong to the list directly, not to any category.
  /// Categories are optional; a simple list is just loose items.
  final List<Item> items;
  final List<PackCategory> categories;

  int get totalItems =>
      items.length + categories.fold(0, (sum, category) => sum + category.items.length);

  int get packedItems =>
      items.where((item) => item.checked).length +
      categories.fold(0, (sum, category) => sum + category.items.where((item) => item.checked).length);

  bool get isReady => totalItems > 0 && packedItems == totalItems;

  double get progress => totalItems == 0 ? 0 : packedItems / totalItems;

  factory PackingList.fromJson(Map<String, dynamic> json) => PackingList(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? '🎒',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => PackCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'items': items.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
      };

  PackingList copy({String? newName}) => PackingList(
        id: newId(),
        name: newName ?? name,
        icon: icon,
        items: items.map((e) => e.copy()).toList(),
        categories: categories.map((e) => e.copy()).toList(),
      );

  /// Clears the packed state of every item, loose and categorised.
  void uncheckAll() {
    for (final item in items) {
      item.checked = false;
    }
    for (final category in categories) {
      for (final item in category.items) {
        item.checked = false;
      }
    }
  }
}
