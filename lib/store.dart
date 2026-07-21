import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptics.dart';
import 'models.dart';
import 'seed.dart';

const _dataKey = 'packlite.data';
const _themeKey = 'packlite.theme';
const _vibKey = 'packlite.vibration';

/// Single source of truth for all app data. The full model is tiny (a few KB
/// of text even for heavy users), so it lives in memory and is persisted as
/// one JSON document on every mutation.
class AppStore extends ChangeNotifier {
  final List<PackingList> lists = [];
  final List<Preset> presets = [];
  ThemeMode themeMode = ThemeMode.system;
  VibLevel vibration = VibLevel.medium;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final theme = _prefs!.getString(_themeKey);
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final vib = _prefs!.getString(_vibKey);
    vibration = VibLevel.values.asNameMap()[vib] ?? VibLevel.medium;
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

  void setVibration(VibLevel level) {
    vibration = level;
    Haptics.level = level;
    notifyListeners();
    _prefs?.setString(_vibKey, level.name);
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
    _mutate(() => lists.removeWhere((l) => l.id == id));
  }

  PackingList? duplicateList(String id) {
    final index = lists.indexWhere((l) => l.id == id);
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
    for (final l in lists) {
      if (l.id == id) return l;
    }
    return null;
  }

  // ---- categories ----

  PackCategory? _cat(String listId, String catId) {
    final list = byId(listId);
    if (list == null) return null;
    for (final c in list.categories) {
      if (c.id == catId) return c;
    }
    return null;
  }

  PackCategory addCategory(String listId, String name, String? icon) {
    final cat = PackCategory(id: newId(), name: name, icon: icon);
    _mutate(() => byId(listId)?.categories.add(cat));
    return cat;
  }

  void updateCategory(String listId, String catId,
      {String? name, String? icon, bool clearIcon = false}) {
    _mutate(() {
      final cat = _cat(listId, catId);
      if (cat == null) return;
      if (name != null) cat.name = name;
      if (clearIcon) {
        cat.icon = null;
      } else if (icon != null) {
        cat.icon = icon;
      }
    });
  }

  void deleteCategory(String listId, String catId) {
    _mutate(() => byId(listId)?.categories.removeWhere((c) => c.id == catId));
  }

  // ---- items ----

  Item addItem(String listId, String catId, String name) {
    final item = Item(id: newId(), name: name);
    _mutate(() => _cat(listId, catId)?.items.add(item));
    return item;
  }

  void insertItem(String listId, String catId, int index, Item item) {
    _mutate(() {
      final cat = _cat(listId, catId);
      if (cat == null) return;
      cat.items.insert(index.clamp(0, cat.items.length), item);
    });
  }

  void renameItem(String listId, String catId, String itemId, String name) {
    _mutate(() {
      final cat = _cat(listId, catId);
      final item = cat?.items.where((i) => i.id == itemId).firstOrNull;
      if (item != null) item.name = name;
    });
  }

  void deleteItem(String listId, String catId, String itemId) {
    _mutate(() => _cat(listId, catId)?.items.removeWhere((i) => i.id == itemId));
  }

  void setItemChecked(String listId, String catId, String itemId, bool checked) {
    _mutate(() {
      final cat = _cat(listId, catId);
      final item = cat?.items.where((i) => i.id == itemId).firstOrNull;
      if (item != null) item.checked = checked;
    });
  }

  /// Moves an item into [toCatId] at [toIndex] among that category's items.
  void moveItem(String listId, String fromCatId, String itemId, String toCatId,
      int toIndex) {
    _mutate(() {
      final from = _cat(listId, fromCatId);
      final to = _cat(listId, toCatId);
      if (from == null || to == null) return;
      final index = from.items.indexWhere((i) => i.id == itemId);
      if (index == -1) return;
      final item = from.items.removeAt(index);
      to.items.insert(toIndex.clamp(0, to.items.length), item);
    });
  }

  void uncheckAll(String listId) {
    _mutate(() {
      final list = byId(listId);
      if (list == null) return;
      for (final c in list.categories) {
        for (final i in c.items) {
          i.checked = false;
        }
      }
    });
  }

  void setHidePacked(String listId, bool hide) {
    _mutate(() => byId(listId)?.hidePacked = hide);
  }

  // ---- presets ----

  Preset? presetById(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
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

  Preset saveCategoryAsPreset(String listId, String catId) {
    final list = byId(listId)!;
    final cat = _cat(listId, catId)!;
    final preset = Preset.fromCategory(cat, icon: list.icon);
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
    _mutate(() => presets.removeWhere((p) => p.id == id));
  }

  void reorderPresets(int oldIndex, int newIndex) {
    _mutate(() => presets.insert(newIndex, presets.removeAt(oldIndex)));
  }

  // preset editor operations (reuse category/item ops against a preset)

  PackCategory? _presetCat(String presetId, String catId) {
    final preset = presetById(presetId);
    if (preset == null) return null;
    for (final c in preset.categories) {
      if (c.id == catId) return c;
    }
    return null;
  }

  void presetAddCategory(String presetId, String name, String? icon) {
    _mutate(() => presetById(presetId)
        ?.categories
        .add(PackCategory(id: newId(), name: name, icon: icon)));
  }

  void presetUpdateCategory(String presetId, String catId,
      {String? name, String? icon, bool clearIcon = false}) {
    _mutate(() {
      final cat = _presetCat(presetId, catId);
      if (cat == null) return;
      if (name != null) cat.name = name;
      if (clearIcon) {
        cat.icon = null;
      } else if (icon != null) {
        cat.icon = icon;
      }
    });
  }

  void presetDeleteCategory(String presetId, String catId) {
    _mutate(() =>
        presetById(presetId)?.categories.removeWhere((c) => c.id == catId));
  }

  void presetAddItem(String presetId, String catId, String name) {
    _mutate(() =>
        _presetCat(presetId, catId)?.items.add(Item(id: newId(), name: name)));
  }

  void presetInsertItem(String presetId, String catId, int index, Item item) {
    _mutate(() {
      final cat = _presetCat(presetId, catId);
      if (cat == null) return;
      cat.items.insert(index.clamp(0, cat.items.length), item);
    });
  }

  void presetRenameItem(String presetId, String catId, String itemId, String name) {
    _mutate(() {
      final item = _presetCat(presetId, catId)
          ?.items
          .where((i) => i.id == itemId)
          .firstOrNull;
      if (item != null) item.name = name;
    });
  }

  void presetDeleteItem(String presetId, String catId, String itemId) {
    _mutate(() =>
        _presetCat(presetId, catId)?.items.removeWhere((i) => i.id == itemId));
  }

  /// Pours a preset into a list. Categories with a name matching an existing
  /// category (case-insensitive) merge into it; items whose name already
  /// exists anywhere in that category are skipped so nothing duplicates.
  void addPresetToList(String listId, String presetId) {
    final preset = presetById(presetId);
    final list = byId(listId);
    if (preset == null || list == null) return;
    _mutate(() {
      for (final presetCat in preset.categories) {
        final existing = list.categories
            .where((c) => c.name.toLowerCase() == presetCat.name.toLowerCase())
            .firstOrNull;
        if (existing == null) {
          list.categories.add(presetCat.copy());
        } else {
          final have =
              existing.items.map((i) => i.name.toLowerCase()).toSet();
          for (final item in presetCat.items) {
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
