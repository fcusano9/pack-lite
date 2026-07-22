import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/screens/preset_editor.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

Widget _wrap(AppStore store, Widget child) {
  return ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: harborTheme(Harbor.light, Brightness.light),
      home: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('list with loose items + a category renders without error',
      (tester) async {
    final store = AppStore();
    await store.load();
    store.lists.insert(
      0,
      PackingList(
        id: 't',
        name: 'Road Trip',
        icon: '🚗',
        items: [
          Item(id: 'i1', name: 'Snacks'),
          Item(id: 'i2', name: 'Sunglasses'),
          Item(id: 'i3', name: 'Passport', checked: true),
        ],
        categories: [
          PackCategory(
            id: 'c1',
            name: 'Clothes',
            items: [
              Item(id: 'i4', name: 'Swimsuit'),
              Item(id: 'i5', name: 'Socks', checked: true),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 't')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Loose items render.
    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('Sunglasses'), findsOneWidget);
    // Category and its item render. CLOTHES appears twice: the category header
    // and the Packed-section label (since a category item is checked).
    expect(find.text('CLOTHES'), findsNWidgets(2));
    expect(find.text('Swimsuit'), findsOneWidget);
    // Loose "Add item" affordance is present.
    expect(find.text('Add item'), findsWidgets);
    // Packed section shows the checked loose + category items.
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('Socks'), findsOneWidget);
  });

  testWidgets('flat empty list shows item-first empty state', (tester) async {
    final store = AppStore();
    await store.load();
    store.lists.insert(
      0,
      PackingList(id: 'e', name: 'New Trip', icon: '🧳'),
    );

    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'e')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Start your list'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
  });

  testWidgets('preset with loose items renders in the editor', (tester) async {
    final store = AppStore();
    await store.load();
    store.presets.insert(
      0,
      Preset(
        id: 'p',
        name: 'Toiletries',
        icon: '🧴',
        items: [
          Item(id: 'pi1', name: 'Toothbrush'),
          Item(id: 'pi2', name: 'Floss'),
        ],
        categories: [
          PackCategory(
              id: 'pc1',
              name: 'Extras',
              items: [Item(id: 'pi3', name: 'Nail clippers')]),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(store, const PresetEditorScreen(presetId: 'p')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Toothbrush'), findsOneWidget); // loose preset item
    expect(find.text('Floss'), findsOneWidget);
    expect(find.text('EXTRAS'), findsOneWidget); // category
    expect(find.text('Nail clippers'), findsOneWidget);
  });

  test('loose items round-trip through JSON', () {
    final list = PackingList(
      id: 'r',
      name: 'Round',
      icon: '🚗',
      items: [Item(id: 'a', name: 'Loose one', checked: true)],
      categories: [
        PackCategory(id: 'c', name: 'Cat', items: [Item(id: 'b', name: 'In cat')])
      ],
    );
    final back = PackingList.fromJson(list.toJson());
    expect(back.items.length, 1);
    expect(back.items.first.name, 'Loose one');
    expect(back.items.first.checked, isTrue);
    expect(back.categories.first.items.first.name, 'In cat');
    expect(back.totalItems, 2);
    expect(back.packedItems, 1);
  });
}
