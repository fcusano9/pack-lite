import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptics.dart';
import 'models.dart';
import 'seed.dart';

const _dataKey = 'packlite.data';
const _themeKey = 'packlite.theme';
const _vibrationKey = 'packlite.vibration';

/// Single source of truth for all app data. The full model is tiny (a few KB
/// of text even for heavy users), so it lives in memory and is persisted as
/// one JSON document on every mutation.
class AppStore extends ChangeNotifier {
  final List<PackingList> lists = [];
  final List<Preset> presets = [];
  ThemeMode themeMode = ThemeMode.system;
  VibrationLevel vibration = VibrationLevel.medium;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final theme = _prefs!.getString(_themeKey);
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final vibrationName = _prefs!.getString(_vibrationKey);
    vibration = VibrationLevel.values.asNameMap()[vibrationName] ?? VibrationLevel.medium;
    Haptics.level = vibration;

    final raw = _prefs!.getString(_dataKey);
    if (raw == null) {
      lists.addAll(buildSeedLists());
      presets.addAll(buildSeedPresets());
      await _persist();
    } else {
      _loadFrom(raw, replace: true);
    }
  }

  /// Parses a data document into memory. Used for first load and for import.
  /// Returns (listCount, presetCount) applied, or null if the document is
  /// unreadable.
  (int, int)? _loadFrom(String raw, {required bool replace}) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final newLists = (json['lists'] as List<dynamic>? ?? [])
          .map((e) => PackingList.fromJson(e as Map<String, dynamic>))
          .toList();
      final newPresets = (json['presets'] as List<dynamic>? ?? [])
          .map((e) => Preset.fromJson(e as Map<String, dynamic>))
          .toList();
      if (replace) {
        lists
          ..clear()
          ..addAll(newLists);
        presets
          ..clear()
          ..addAll(newPresets);
      } else {
        lists.insertAll(0, newLists);
        presets.addAll(newPresets);
      }
      return (newLists.length, newPresets.length);
    } catch (_) {
      return null;
    }
  }

  String exportJson() => jsonEncode({
        'v': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'lists': lists.map((e) => e.toJson()).toList(),
        'presets': presets.map((e) => e.toJson()).toList(),
      });

  /// Imports a document. When [replace] is false, imported lists/presets are
  /// added alongside existing ones. Returns counts, or null on parse failure.
  (int, int)? importJson(String raw, {required bool replace}) {
    final result = _loadFrom(raw, replace: replace);
    if (result != null) {
      notifyListeners();
      _persist();
    }
    return result;
  }

  Future<void> deleteAllData() async {
    lists.clear();
    presets.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs?.setString(_dataKey, exportJson());
  }

  void _mutate(void Function() change) {
    change();
    notifyListeners();
    _persist();
  }

  // ---- theme ----

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
    _prefs?.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  void setVibration(VibrationLevel level) {
    vibration = level;
    Haptics.level = level;
    notifyListeners();
    _prefs?.setString(_vibrationKey, level.name);
  }

  // ---- lists ----

  PackingList addList(String name, String icon) {
    final list = PackingList(id: newId(), name: name, icon: icon);
    _mutate(() => lists.insert(0, list));
    return list;
  }

  void updateList(String id, {String? name, String? icon}) {
    _mutate(() {
      final list = byId(id);
      if (list == null) return;
      if (name != null) list.name = name;
      if (icon != null) list.icon = icon;
    });
  }

  void deleteList(String id) {
    _mutate(() => lists.removeWhere((list) => list.id == id));
  }

  PackingList? duplicateList(String id) {
    final index = lists.indexWhere((list) => list.id == id);
    if (index == -1) return null;
    final copy = lists[index].copy(newName: '${lists[index].name} copy');
    _mutate(() => lists.insert(index + 1, copy));
    return copy;
  }

  void reorderLists(int oldIndex, int newIndex) {
    _mutate(() {
      final list = lists.removeAt(oldIndex);
      lists.insert(newIndex, list);
    });
  }

  PackingList? byId(String id) {
    for (final list in lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  // ---- categories ----

  PackCategory? _category(String listId, String categoryId) {
    final list = byId(listId);
    if (list == null) return null;
    for (final category in list.categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  PackCategory addCategory(String listId, String name, String? icon) {
    final category = PackCategory(id: newId(), name: name, icon: icon);
    _mutate(() => byId(listId)?.categories.add(category));
    return category;
  }

  void updateCategory(String listId, String categoryId,
      {String? name, String? icon, bool clearIcon = false}) {
    _mutate(() {
      final category = _category(listId, categoryId);
      if (category == null) return;
      if (name != null) category.name = name;
      if (clearIcon) {
        category.icon = null;
      } else if (icon != null) {
        category.icon = icon;
      }
    });
  }

  void deleteCategory(String listId, String categoryId) {
    _mutate(() => byId(listId)?.categories.removeWhere((category) => category.id == categoryId));
  }

  // ---- items ----
  //
  // Category is optional: a null [categoryId] targets the list's loose items,
  // a non-null [categoryId] targets that named category.

  /// Resolves the item bucket for a list: the loose list when [categoryId] is null,
  /// otherwise the named category's items (or null if not found).
  List<Item>? _itemsIn(String listId, String? categoryId) {
    final list = byId(listId);
    if (list == null) return null;
    if (categoryId == null) return list.items;
    return _category(listId, categoryId)?.items;
  }

  Item addItem(String listId, String? categoryId, String name) {
    final item = Item(id: newId(), name: name);
    _mutate(() => _itemsIn(listId, categoryId)?.add(item));
    return item;
  }

  void insertItem(String listId, String? categoryId, int index, Item item) {
    _mutate(() {
      final items = _itemsIn(listId, categoryId);
      if (items == null) return;
      items.insert(index.clamp(0, items.length), item);
    });
  }

  void renameItem(String listId, String? categoryId, String itemId, String name) {
    _mutate(() {
      final item =
          _itemsIn(listId, categoryId)?.where((item) => item.id == itemId).firstOrNull;
      if (item != null) item.name = name;
    });
  }

  void deleteItem(String listId, String? categoryId, String itemId) {
    _mutate(() => _itemsIn(listId, categoryId)?.removeWhere((item) => item.id == itemId));
  }

  void setItemChecked(
      String listId, String? categoryId, String itemId, bool checked) {
    _mutate(() {
      final item =
          _itemsIn(listId, categoryId)?.where((item) => item.id == itemId).firstOrNull;
      if (item != null) item.checked = checked;
    });
  }

  /// Moves an item into [toCategoryId] (null = loose) at [toIndex] within that bucket.
  void moveItem(String listId, String? fromCategoryId, String itemId,
      String? toCategoryId, int toIndex) {
    _mutate(() {
      final from = _itemsIn(listId, fromCategoryId);
      final to = _itemsIn(listId, toCategoryId);
      if (from == null || to == null) return;
      final index = from.indexWhere((item) => item.id == itemId);
      if (index == -1) return;
      final item = from.removeAt(index);
      to.insert(toIndex.clamp(0, to.length), item);
    });
  }

  void uncheckAll(String listId) {
    _mutate(() {
      final list = byId(listId);
      if (list == null) return;
      for (final item in list.items) {
        item.checked = false;
      }
      for (final category in list.categories) {
        for (final item in category.items) {
          item.checked = false;
        }
      }
    });
  }

  void setHidePacked(String listId, bool hide) {
    _mutate(() => byId(listId)?.hidePacked = hide);
  }

  // ---- presets ----

  Preset? presetById(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  Preset addPreset(String name, String icon) {
    final preset = Preset(id: newId(), name: name, icon: icon);
    _mutate(() => presets.add(preset));
    return preset;
  }

  Preset saveListAsPreset(String listId) {
    final list = byId(listId)!;
    final preset = Preset.fromList(list);
    _mutate(() => presets.add(preset));
    return preset;
  }

  Preset saveCategoryAsPreset(String listId, String categoryId) {
    final list = byId(listId)!;
    final category = _category(listId, categoryId)!;
    final preset = Preset.fromCategory(category, icon: list.icon);
    _mutate(() => presets.add(preset));
    return preset;
  }

  void updatePreset(String id, {String? name, String? icon}) {
    _mutate(() {
      final preset = presetById(id);
      if (preset == null) return;
      if (name != null) preset.name = name;
      if (icon != null) preset.icon = icon;
    });
  }

  void deletePreset(String id) {
    _mutate(() => presets.removeWhere((preset) => preset.id == id));
  }

  void reorderPresets(int oldIndex, int newIndex) {
    _mutate(() => presets.insert(newIndex, presets.removeAt(oldIndex)));
  }

  // preset editor operations (reuse category/item ops against a preset)

  PackCategory? _presetCategory(String presetId, String categoryId) {
    final preset = presetById(presetId);
    if (preset == null) return null;
    for (final category in preset.categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  void presetAddCategory(String presetId, String name, String? icon) {
    _mutate(() => presetById(presetId)
        ?.categories
        .add(PackCategory(id: newId(), name: name, icon: icon)));
  }

  void presetUpdateCategory(String presetId, String categoryId,
      {String? name, String? icon, bool clearIcon = false}) {
    _mutate(() {
      final category = _presetCategory(presetId, categoryId);
      if (category == null) return;
      if (name != null) category.name = name;
      if (clearIcon) {
        category.icon = null;
      } else if (icon != null) {
        category.icon = icon;
      }
    });
  }

  void presetDeleteCategory(String presetId, String categoryId) {
    _mutate(() =>
        presetById(presetId)?.categories.removeWhere((category) => category.id == categoryId));
  }

  /// Loose preset items when [categoryId] is null, else the preset category's items.
  List<Item>? _presetItemsIn(String presetId, String? categoryId) {
    final preset = presetById(presetId);
    if (preset == null) return null;
    if (categoryId == null) return preset.items;
    return _presetCategory(presetId, categoryId)?.items;
  }

  void presetAddItem(String presetId, String? categoryId, String name) {
    _mutate(() =>
        _presetItemsIn(presetId, categoryId)?.add(Item(id: newId(), name: name)));
  }

  void presetInsertItem(String presetId, String? categoryId, int index, Item item) {
    _mutate(() {
      final items = _presetItemsIn(presetId, categoryId);
      if (items == null) return;
      items.insert(index.clamp(0, items.length), item);
    });
  }

  void presetRenameItem(
      String presetId, String? categoryId, String itemId, String name) {
    _mutate(() {
      final item = _presetItemsIn(presetId, categoryId)
          ?.where((item) => item.id == itemId)
          .firstOrNull;
      if (item != null) item.name = name;
    });
  }

  void presetDeleteItem(String presetId, String? categoryId, String itemId) {
    _mutate(() =>
        _presetItemsIn(presetId, categoryId)?.removeWhere((item) => item.id == itemId));
  }

  /// Pours a preset into a list. Loose preset items merge into the list's loose
  /// items; categories whose name matches an existing category (case-insensitive)
  /// merge into it. In both buckets, items whose name already exists there are
  /// skipped so nothing duplicates.
  void addPresetToList(String listId, String presetId) {
    final preset = presetById(presetId);
    final list = byId(listId);
    if (preset == null || list == null) return;
    _mutate(() {
      // Loose items → list's loose items.
      final looseHave = list.items.map((item) => item.name.toLowerCase()).toSet();
      for (final item in preset.items) {
        if (looseHave.add(item.name.toLowerCase())) {
          list.items.add(Item(id: newId(), name: item.name));
        }
      }
      // Categories → matching category or appended.
      for (final presetCategory in preset.categories) {
        final existing = list.categories
            .where((category) => category.name.toLowerCase() == presetCategory.name.toLowerCase())
            .firstOrNull;
        if (existing == null) {
          list.categories.add(presetCategory.copy());
        } else {
          final have =
              existing.items.map((item) => item.name.toLowerCase()).toSet();
          for (final item in presetCategory.items) {
            if (have.add(item.name.toLowerCase())) {
              existing.items.add(Item(id: newId(), name: item.name));
            }
          }
        }
      }
    });
  }

  /// Creates a new list seeded from the given presets (used by the new-list
  /// sheet's optional "start from presets" step).
  PackingList addListFromPresets(
      String name, String icon, List<String> presetIds) {
    final list = PackingList(id: newId(), name: name, icon: icon);
    _mutate(() => lists.insert(0, list));
    for (final id in presetIds) {
      addPresetToList(list.id, id);
    }
    return list;
  }
}
