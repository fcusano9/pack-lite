import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// Loose items get an "Uncategorized" header once a list has real categories,
/// so every group looks alike (#35) — but a list with no categories stays a
/// flat, header-less checklist. That conditional is the whole feature, so both
/// sides of it are pinned here.
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

PackingList _withCategories({bool looseItems = true, bool loosePacked = false}) =>
    PackingList(
      id: 'x',
      name: 'Trip',
      icon: '🧳',
      items: [
        if (looseItems) Item(id: 'l1', name: 'Snacks'),
        if (loosePacked) Item(id: 'l2', name: 'Passport', checked: true),
      ],
      categories: [
        PackCategory(id: 'c1', name: 'Clothes', items: [
          Item(id: 'c1i1', name: 'Socks'),
        ]),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a flat list has NO Uncategorized header', (tester) async {
    final store = await _storeWith(PackingList(
      id: 'x',
      name: 'Trip',
      icon: '🧳',
      items: [Item(id: 'l1', name: 'Snacks')],
    ));
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('UNCATEGORIZED'), findsNothing);
  });

  testWidgets('loose items get an Uncategorized header once categories exist',
      (tester) async {
    final store = await _storeWith(_withCategories());
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    expect(find.text('UNCATEGORIZED'), findsOneWidget);
    expect(find.text('CLOTHES'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);
    // It carries a count like any other section.
    expect(find.text('· 0 of 1'), findsNWidgets(2));
  });

  testWidgets('no Uncategorized header when there are no loose items',
      (tester) async {
    final store = await _storeWith(_withCategories(looseItems: false));
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    expect(find.text('CLOTHES'), findsOneWidget);
    expect(find.text('UNCATEGORIZED'), findsNothing);
  });

  testWidgets('tapping the Uncategorized header collapses its items',
      (tester) async {
    final store = await _storeWith(_withCategories());
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();
    expect(find.text('Snacks'), findsOneWidget);

    await tester.tap(find.text('UNCATEGORIZED'));
    await tester.pumpAndSettle();

    expect(find.text('Snacks'), findsNothing);
    expect(find.text('UNCATEGORIZED'), findsOneWidget); // header stays
    expect(find.text('Socks'), findsOneWidget); // the real category is unaffected
  });

  testWidgets('Collapse All collapses the Uncategorized section too',
      (tester) async {
    final store = await _storeWith(_withCategories());
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();
    expect(find.text('Snacks'), findsOneWidget); // uncategorized item
    expect(find.text('Socks'), findsOneWidget); // category item

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapse All'));
    await tester.pumpAndSettle();

    // Its key isn't in list.categories, so it was previously left expanded.
    expect(find.text('Snacks'), findsNothing);
    expect(find.text('Socks'), findsNothing);
    expect(find.text('UNCATEGORIZED'), findsOneWidget);
    expect(find.text('CLOTHES'), findsOneWidget);
  });

  testWidgets('Expand All restores the Uncategorized section', (tester) async {
    final store = await _storeWith(_withCategories());
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapse All'));
    await tester.pumpAndSettle();
    expect(find.text('Snacks'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand All'));
    await tester.pumpAndSettle();

    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('Socks'), findsOneWidget);
  });

  testWidgets('long-pressing Uncategorized opens no category menu',
      (tester) async {
    final store = await _storeWith(_withCategories());
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('UNCATEGORIZED'));
    await tester.pumpAndSettle();

    // There's no real category behind it, so rename/delete must not be offered.
    expect(find.text('Rename & icon'), findsNothing);
    expect(find.text('Delete category'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('packed loose items are labelled only when categories exist',
      (tester) async {
    final store = await _storeWith(
        _withCategories(looseItems: false, loosePacked: true));
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    // Twice: the section header (which stays even when everything in it is
    // packed, exactly as a real category header does) and the packed-group
    // label, so those items don't read as belonging to the category above.
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('UNCATEGORIZED'), findsNWidgets(2));
  });

  testWidgets('a flat list leaves its packed items unlabelled', (tester) async {
    final store = await _storeWith(PackingList(
      id: 'x',
      name: 'Trip',
      icon: '🧳',
      items: [Item(id: 'l2', name: 'Passport', checked: true)],
    ));
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('UNCATEGORIZED'), findsNothing);
  });
}
