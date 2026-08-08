import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_sync.dart';
import 'haptics.dart';
import 'models.dart';
import 'seed.dart';

const _dataKey = 'packlite.data';
const _themeKey = 'packlite.theme';
const _vibrationKey = 'packlite.vibration';
const _collapsedKey = 'packlite.collapsed';

/// Single source of truth for all app data. The full model is tiny (a few KB
/// of text even for heavy users), so it lives in memory and is persisted as
/// one JSON document on every mutation.
class AppStore extends ChangeNotifier {
  final List<PackingList> lists = [];

  /// Reusable categories the user can drop into any list — "Toiletries",
  /// "Electronics". Just [PackCategory] objects that live outside a list; there
  /// is no separate template type (#13).
  final List<PackCategory> savedCategories = [];
  ThemeMode themeMode = ThemeMode.system;
  VibrationLevel vibration = VibrationLevel.medium;

  /// Which sections each list has collapsed, keyed by list id (#61). Values are
  /// category ids plus [packedSectionKey].
  ///
  /// This is view state, not list data, so it lives in its own preferences key
  /// rather than in the `v2` document — an export describes what you're packing,
  /// not which headers you happened to have folded shut.
  final Map<String, Set<String>> _collapsed = {};

  /// Stands in for the Packed section, which is rendered from every list's
  /// checked items rather than being a [PackCategory], so it has no id of its
  /// own. [newId] produces base-36 digits only, so this can never collide.
  static const packedSectionKey = 'packed-section';

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

    _loadCollapsed(_prefs!.getString(_collapsedKey));

    final raw = _prefs!.getString(_dataKey);
    if (raw == null) {
      lists.addAll(buildSeedLists());
      savedCategories.addAll(buildSeedCategories());
      await _persist();
    } else {
      _loadFrom(raw, replace: true);
    }
    _pruneCollapsed();
  }

  // ---- collapsed sections ----

  void _loadCollapsed(String? raw) {
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in json.entries) {
        final keys = (entry.value as List<dynamic>).cast<String>().toSet();
        if (keys.isNotEmpty) _collapsed[entry.key] = keys;
      }
    } catch (_) {
      // Only view state: an unreadable document just means every section
      // starts expanded, which is the same as a first run.
      _collapsed.clear();
    }
  }

  /// Drops collapse state for lists that no longer exist, so deleting and
  /// re-importing can't leave the map growing forever.
  void _pruneCollapsed() {
    final live = lists.map((list) => list.id).toSet();
    _collapsed.removeWhere((listId, _) => !live.contains(listId));
  }

  Future<void> _persistCollapsed() async {
    await _prefs?.setString(
        _collapsedKey,
        jsonEncode(
            _collapsed.map((listId, keys) => MapEntry(listId, keys.toList()))));
  }

  bool isCollapsed(String listId, String key) =>
      _collapsed[listId]?.contains(key) ?? false;

  void setCollapsed(String listId, String key, bool collapsed) {
    final keys = _collapsed.putIfAbsent(listId, () => <String>{});
    final changed = collapsed ? keys.add(key) : keys.remove(key);
    if (keys.isEmpty) _collapsed.remove(listId);
    if (!changed) return;
    notifyListeners();
    _persistCollapsed();
  }

  /// Sets a list's collapsed sections wholesale — the ··· menu's Collapse All
  /// and Expand All. An empty [keys] expands everything.
  void setCollapsedAll(String listId, Set<String> keys) {
    if (keys.isEmpty) {
      _collapsed.remove(listId);
    } else {
      _collapsed[listId] = {...keys};
    }
    notifyListeners();
    _persistCollapsed();
  }

  /// Parses a data document into memory. Used for first load and for import.
  /// Returns (listCount, categoryCount) applied, or null if the document is
  /// unreadable.
  (int, int)? _loadFrom(String raw, {required bool replace}) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final newLists = (json['lists'] as List<dynamic>? ?? [])
          .map((e) => PackingList.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCategories = (json['categories'] as List<dynamic>? ?? [])
          .map((e) => PackCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      if (replace) {
        lists
          ..clear()
          ..addAll(newLists);
        savedCategories
          ..clear()
          ..addAll(newCategories);
      } else {
        lists.insertAll(0, newLists);
        savedCategories.addAll(newCategories);
      }
      // Stored or imported data predating #46 can hold both loose items and
      // categories; normalise it so the rest of the app can rely on the
      // invariant rather than re-checking for it.
      for (final list in lists) {
        _absorbLooseItems(list);
      }
      return (newLists.length, newCategories.length);
    } catch (_) {
      return null;
    }
  }

  String exportJson() => jsonEncode({
        // v2 dropped the `presets` key for `categories` (#13). Nothing reads
        // this field; it's here so a document says what shape it is.
        'v': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'lists': lists.map((e) => e.toJson()).toList(),
        'categories': savedCategories.map((e) => e.toJson()).toList(),
      });

  /// Imports a document. When [replace] is false, imported lists/categories are
  /// added alongside existing ones. Returns counts, or null on parse failure.
  (int, int)? importJson(String raw, {required bool replace}) {
    final result = _loadFrom(raw, replace: replace);
    if (result != null) {
      // A replacing import retires the old lists, and with them their collapse
      // state; imported lists arrive with every section expanded.
      _pruneCollapsed();
      _persistCollapsed();
      notifyListeners();
      _persist();
    }
    return result;
  }

  Future<void> deleteAllData() async {
    lists.clear();
    savedCategories.clear();
    _collapsed.clear();
    notifyListeners();
    await _persist();
    await _persistCollapsed();
    // Ask Android to replace its cloud snapshot now that everything is gone,
    // so reinstalling can't restore the lists the user just deleted.
    await BackupSync.dataChanged();
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
    if (_collapsed.remove(id) != null) _persistCollapsed();
  }

  PackingList? duplicateList(String id) {
    final index = lists.indexWhere((list) => list.id == id);
    if (index == -1) return null;
    final copy = lists[index].copy(newName: '${lists[index].name} copy');
    // A duplicate exists to be packed again, so it starts fully unpacked.
    // Inheriting last trip's ticks would mean hunting them down by hand.
    copy.uncheckAll();
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

  /// The name given to loose items when a flat list gains its first category.
  static const uncategorizedName = 'Uncategorized';

  /// Enforces the invariant that a list either has **no categories** (a flat
  /// checklist of loose items) or **has categories and no loose items**.
  ///
  /// The moment a flat list gains a category, its loose items are absorbed into
  /// a real category named [uncategorizedName]. That makes "Uncategorized" an
  /// ordinary category — renameable, reorderable, deletable (#46) — instead of
  /// a special case the UI has to model separately.
  ///
  /// Call inside a `_mutate`; it doesn't notify on its own.
  void _absorbLooseItems(PackingList? list) {
    if (list == null || list.items.isEmpty || list.categories.isEmpty) return;
    final existing = list.categories
        .where((category) =>
            category.name.toLowerCase() == uncategorizedName.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      existing.items.addAll(list.items);
    } else {
      // First, so the items stay where the user last saw them: above the
      // categories, in their original order.
      list.categories.insert(
          0,
          PackCategory(
              id: newId(), name: uncategorizedName, items: [...list.items]));
    }
    list.items.clear();
  }

  PackCategory addCategory(String listId, String name, String? icon) {
    final category = PackCategory(id: newId(), name: name, icon: icon);
    _mutate(() {
      final list = byId(listId);
      if (list == null) return;
      list.categories.add(category);
      _absorbLooseItems(list);
    });
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

  void reorderCategories(String listId, int oldIndex, int newIndex) {
    _mutate(() {
      final list = byId(listId);
      if (list == null) return;
      final category = list.categories.removeAt(oldIndex);
      list.categories.insert(newIndex, category);
    });
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
    _mutate(() => byId(listId)?.uncheckAll());
  }

  // ---- saved categories ----
  //
  // A saved category is an ordinary [PackCategory] that lives outside any list.
  // Because it's the same type, these operations are the list ones with the
  // bucket swapped — there's no loose/categorised split to double up on.

  PackCategory? savedCategoryById(String id) {
    for (final category in savedCategories) {
      if (category.id == id) return category;
    }
    return null;
  }

  PackCategory addSavedCategory(String name, String? icon) {
    final category = PackCategory(id: newId(), name: name, icon: icon);
    _mutate(() => savedCategories.add(category));
    return category;
  }

  /// Copies one of a list's categories into the library. Unchecked, so the
  /// block arrives ready to pack rather than carrying this trip's ticks.
  PackCategory? saveCategoryToLibrary(String listId, String categoryId) {
    final category = _category(listId, categoryId);
    if (category == null) return null;
    final saved = category.copyUnchecked();
    _mutate(() => savedCategories.add(saved));
    return saved;
  }

  void updateSavedCategory(String id,
      {String? name, String? icon, bool clearIcon = false}) {
    _mutate(() {
      final category = savedCategoryById(id);
      if (category == null) return;
      if (name != null) category.name = name;
      if (clearIcon) {
        category.icon = null;
      } else if (icon != null) {
        category.icon = icon;
      }
    });
  }

  void deleteSavedCategory(String id) {
    _mutate(() => savedCategories.removeWhere((category) => category.id == id));
  }

  void reorderSavedCategories(int oldIndex, int newIndex) {
    _mutate(() =>
        savedCategories.insert(newIndex, savedCategories.removeAt(oldIndex)));
  }

  void savedCategoryAddItem(String categoryId, String name) {
    _mutate(() =>
        savedCategoryById(categoryId)?.items.add(Item(id: newId(), name: name)));
  }

  void savedCategoryInsertItem(String categoryId, int index, Item item) {
    _mutate(() {
      final items = savedCategoryById(categoryId)?.items;
      if (items == null) return;
      items.insert(index.clamp(0, items.length), item);
    });
  }

  void savedCategoryRenameItem(String categoryId, String itemId, String name) {
    _mutate(() {
      final item = savedCategoryById(categoryId)
          ?.items
          .where((item) => item.id == itemId)
          .firstOrNull;
      if (item != null) item.name = name;
    });
  }

  void savedCategoryDeleteItem(String categoryId, String itemId) {
    _mutate(() =>
        savedCategoryById(categoryId)?.items.removeWhere((item) => item.id == itemId));
  }

  /// Pours a saved category into a list. A list category with the same name
  /// (case-insensitive) absorbs the items; otherwise the category is appended.
  /// Either way, item names already present are skipped so nothing duplicates.
  void addSavedCategoryToList(String listId, String savedCategoryId) {
    final saved = savedCategoryById(savedCategoryId);
    final list = byId(listId);
    if (saved == null || list == null) return;
    _mutate(() {
      final existing = list.categories
          .where((category) =>
              category.name.toLowerCase() == saved.name.toLowerCase())
          .firstOrNull;
      if (existing == null) {
        list.categories.add(saved.copyUnchecked());
      } else {
        final have = existing.items.map((item) => item.name.toLowerCase()).toSet();
        for (final item in saved.items) {
          if (have.add(item.name.toLowerCase())) {
            existing.items.add(Item(id: newId(), name: item.name));
          }
        }
      }
      // This can hand a flat list its first category.
      _absorbLooseItems(list);
    });
  }

  /// Creates a new list seeded from the given saved categories (used by the
  /// new-list sheet's optional "start with categories" step).
  PackingList addListFromSavedCategories(
      String name, String icon, List<String> savedCategoryIds) {
    final list = PackingList(id: newId(), name: name, icon: icon);
    _mutate(() => lists.insert(0, list));
    for (final id in savedCategoryIds) {
      addSavedCategoryToList(list.id, id);
    }
    return list;
  }
}
