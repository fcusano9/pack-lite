import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/category_editor.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// Saved categories replaced presets in #13: a reusable block of items is now
/// an ordinary [PackCategory] living outside any list. These pin the merge
/// rule, the unchecked guarantee, and the JSON key.
Future<AppStore> _store() async {
  final store = AppStore();
  await store.load();
  store.lists.clear();
  store.savedCategories.clear();
  return store;
}

PackCategory _saved(String id, String name, List<String> items,
        {String? icon}) =>
    PackCategory(
      id: id,
      name: name,
      icon: icon,
      items: [for (final item in items) Item(id: '$id-$item', name: item)],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('addSavedCategoryToList', () {
    test('appends a category a list does not have', () async {
      final store = await _store();
      store.savedCategories.add(_saved('s', 'Toiletries', ['Floss'], icon: '🧴'));
      final list = store.addList('Trip', '🧳');

      store.addSavedCategoryToList(list.id, 's');

      expect(list.categories.length, 1);
      expect(list.categories.first.name, 'Toiletries');
      expect(list.categories.first.icon, '🧴');
      expect(list.categories.first.items.map((item) => item.name), ['Floss']);
      // A copy, not the saved category itself — editing the list must not
      // reach back into the library.
      expect(list.categories.first.id, isNot('s'));
    });

    test('merges into a same-name category, skipping duplicate item names',
        () async {
      final store = await _store();
      store.savedCategories
          .add(_saved('s', 'Toiletries', ['Floss', 'Razor', 'Soap']));
      final list = store.addList('Trip', '🧳');
      final existing = store.addCategory(list.id, 'toiletries', null);
      store.addItem(list.id, existing.id, 'Razor');

      store.addSavedCategoryToList(list.id, 's');

      expect(list.categories.length, 1, reason: 'case-insensitive name match');
      expect(existing.items.map((item) => item.name),
          ['Razor', 'Floss', 'Soap']);
    });

    test('a flat list absorbs its loose items when it gains the first category',
        () async {
      final store = await _store();
      store.savedCategories.add(_saved('s', 'Toiletries', ['Floss']));
      final list = store.addList('Trip', '🧳');
      store.addItem(list.id, null, 'Passport');

      store.addSavedCategoryToList(list.id, 's');

      // The #46 invariant: categories and loose items never coexist.
      expect(list.items, isEmpty);
      expect(list.categories.map((category) => category.name),
          [AppStore.uncategorizedName, 'Toiletries']);
    });

    test('arrives unpacked even if the saved copy carries ticks', () async {
      final store = await _store();
      final saved = _saved('s', 'Toiletries', ['Floss']);
      saved.items.first.checked = true;
      store.savedCategories.add(saved);
      final list = store.addList('Trip', '🧳');

      store.addSavedCategoryToList(list.id, 's');

      expect(list.categories.first.items.first.checked, isFalse);
    });
  });

  test('addListFromSavedCategories seeds a new list', () async {
    final store = await _store();
    store.savedCategories
      ..add(_saved('a', 'Toiletries', ['Floss']))
      ..add(_saved('b', 'Electronics', ['Charger', 'Power bank']));

    final list = store.addListFromSavedCategories('Trip', '🧳', ['a', 'b']);

    expect(store.lists.first, same(list));
    expect(list.categories.map((category) => category.name),
        ['Toiletries', 'Electronics']);
    expect(list.totalItems, 3);
  });

  test('saveCategoryToLibrary copies a list category, unchecked', () async {
    final store = await _store();
    final list = store.addList('Trip', '🧳');
    final category = store.addCategory(list.id, 'Toiletries', '🧴');
    final item = store.addItem(list.id, category.id, 'Floss');
    store.setItemChecked(list.id, category.id, item.id, true);

    final saved = store.saveCategoryToLibrary(list.id, category.id)!;

    expect(store.savedCategories, [saved]);
    expect(saved.name, 'Toiletries');
    expect(saved.icon, '🧴');
    expect(saved.items.single.checked, isFalse,
        reason: 'a reusable block must not carry this trip\'s ticks');
    // Independent copy: renaming the list's category leaves the saved one be.
    store.updateCategory(list.id, category.id, name: 'Bathroom');
    expect(saved.name, 'Toiletries');
  });

  testWidgets('the editor reorders items to where they were dropped',
      (tester) async {
    // `onReorderItem` already accounts for the removed item, unlike the
    // deprecated `onReorder`. Shifting newIndex again lands items one slot
    // short, which is invisible in a store-level test.
    final store = await _store();
    // Four items, dropped mid-list: landing on the *last* index would clamp
    // under either formula and hide the off-by-one.
    store.savedCategories.add(_saved('s', 'Toiletries', ['A', 'B', 'C', 'D']));

    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: const CategoryEditorScreen(categoryId: 's'),
      ),
    ));
    await tester.pumpAndSettle();

    final rowHeight = tester.getCenter(find.text('B')).dy -
        tester.getCenter(find.text('A')).dy;
    final drag = await tester.startGesture(tester.getCenter(find.text('A')));
    await tester.pump(kLongPressTimeout + kPressTimeout);
    // Incrementally, so the list re-evaluates the drop slot as the other rows
    // shift up to fill the gap the lifted item left behind.
    for (var step = 0; step < 4; step++) {
      await drag.moveBy(Offset(0, rowHeight / 2));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(store.savedCategoryById('s')!.items.map((item) => item.name),
        ['B', 'C', 'A', 'D']);
  });

  test('saved categories round-trip through the document', () async {
    final store = await _store();
    store.savedCategories
        .add(_saved('s', 'Toiletries', ['Floss', 'Razor'], icon: '🧴'));
    store.addList('Trip', '🧳');

    final reloaded = AppStore();
    final counts = reloaded.importJson(store.exportJson(), replace: true);

    expect(counts, (1, 1));
    expect(reloaded.savedCategories.single.name, 'Toiletries');
    expect(reloaded.savedCategories.single.icon, '🧴');
    expect(reloaded.savedCategories.single.items.map((item) => item.name),
        ['Floss', 'Razor']);
  });
}
