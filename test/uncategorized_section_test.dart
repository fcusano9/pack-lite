import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// A list either has **no categories** (a flat checklist of loose items) or
/// **categories and no loose items** — the moment a flat list gains a category
/// its loose items become a real "Uncategorized" category (#46). That makes it
/// an ordinary category: renameable, reorderable, deletable, with no special
/// case anywhere in the UI.
Widget _wrap(AppStore store) => ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: const ListScreen(listId: 'x'),
      ),
    );

Future<AppStore> _storeWith(PackingList list) async {
  final store = AppStore();
  await store.load();
  store.lists
    ..clear()
    ..add(list);
  return store;
}

PackingList _flatList() => PackingList(
      id: 'x',
      name: 'Trip',
      icon: '🧳',
      items: [
        Item(id: 'l1', name: 'Snacks'),
        Item(id: 'l2', name: 'Passport', checked: true),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the invariant', () {
    test('adding the first category absorbs loose items', () async {
      final store = await _storeWith(_flatList());

      store.addCategory('x', 'Clothes', null);

      final list = store.byId('x')!;
      expect(list.items, isEmpty, reason: 'no loose items alongside categories');
      expect(list.categories.first.name, AppStore.uncategorizedName);
      expect(list.categories.first.items.map((item) => item.name),
          ['Snacks', 'Passport']);
      expect(list.categories.last.name, 'Clothes');
      // Nothing is lost or silently unpacked in the move.
      expect(list.totalItems, 2);
      expect(list.packedItems, 1);
    });

    test('a flat list is left alone', () async {
      final store = await _storeWith(_flatList());
      final list = store.byId('x')!;

      expect(list.items.length, 2);
      expect(list.categories, isEmpty);
    });

    test('a second category does not create another Uncategorized', () async {
      final store = await _storeWith(_flatList());
      store.addCategory('x', 'Clothes', null);
      store.addCategory('x', 'Tech', null);

      final list = store.byId('x')!;
      expect(
          list.categories
              .where((c) => c.name == AppStore.uncategorizedName)
              .length,
          1);
      expect(list.categories.length, 3);
    });

    test('legacy data with both is normalised on load', () async {
      // Pre-#46 documents could hold loose items *and* categories.
      SharedPreferences.setMockInitialValues({
        'flutter.packlite.data': '''
        {"v":1,"lists":[{"id":"x","name":"Trip","icon":"🧳",
          "items":[{"id":"a","name":"Loose","checked":false}],
          "categories":[{"id":"c","name":"Clothes","items":[]}]}],"presets":[]}
        '''
      });
      final store = AppStore();
      await store.load();

      final list = store.byId('x')!;
      expect(list.items, isEmpty);
      expect(list.categories.first.name, AppStore.uncategorizedName);
      expect(list.categories.first.items.single.name, 'Loose');
    });
  });

  group('it behaves like any other category', () {
    Future<AppStore> categorised() async {
      final store = await _storeWith(_flatList());
      store.addCategory('x', 'Clothes', null);
      return store;
    }

    testWidgets('it renders as a normal header', (tester) async {
      final store = await categorised();
      await tester.pumpWidget(_wrap(store));
      await tester.pumpAndSettle();

      expect(find.text('UNCATEGORIZED'), findsWidgets);
      expect(find.text('CLOTHES'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
    });

    testWidgets('it can be renamed', (tester) async {
      final store = await categorised();
      final id = store.byId('x')!.categories.first.id;

      store.updateCategory('x', id, name: 'Odds & Ends');

      expect(store.byId('x')!.categories.first.name, 'Odds & Ends');
      await tester.pumpWidget(_wrap(store));
      await tester.pumpAndSettle();
      // Twice: the section header and the packed-group label, since this list
      // has a packed item — exactly how any other category renders.
      expect(find.text('ODDS & ENDS'), findsNWidgets(2));
      expect(find.text('UNCATEGORIZED'), findsNothing);
    });

    test('it can be reordered', () async {
      final store = await categorised();
      expect(store.byId('x')!.categories.first.name, AppStore.uncategorizedName);

      store.reorderCategories('x', 0, 1);

      expect(store.byId('x')!.categories.last.name, AppStore.uncategorizedName);
    });

    test('it can be deleted', () async {
      final store = await categorised();
      final id = store.byId('x')!.categories.first.id;

      store.deleteCategory('x', id);

      final list = store.byId('x')!;
      expect(list.categories.map((c) => c.name), ['Clothes']);
      expect(list.items, isEmpty, reason: 'deleted, not dropped back to loose');
    });

    testWidgets('long-press opens the category menu', (tester) async {
      final store = await categorised();
      await tester.pumpWidget(_wrap(store));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('UNCATEGORIZED').first);
      await tester.pumpAndSettle();

      // Previously suppressed because there was no real category behind it.
      expect(find.text('Rename & icon'), findsOneWidget);
      expect(find.text('Delete category'), findsOneWidget);
    });

    testWidgets('Collapse All includes it', (tester) async {
      final store = await categorised();
      await tester.pumpWidget(_wrap(store));
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collapse All'));
      await tester.pumpAndSettle();

      expect(find.text('Snacks'), findsNothing);
    });
  });
}
