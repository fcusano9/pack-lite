import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/screens/category_editor.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// Adding an item with Enter must keep the inline add row focused and the
/// keyboard up, so items can be typed one after another (issue #22).
Widget _wrap(AppStore store) => ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: const ListScreen(listId: 'x'),
      ),
    );

PackingList _listWith(List<String> names) => PackingList(
      id: 'x',
      name: 'Trip',
      icon: '🧳',
      items: [for (final name in names) Item(id: name, name: name)],
    );

Future<AppStore> _storeWith(List<String> names) async {
  final store = AppStore();
  await store.load();
  store.lists.insert(0, _listWith(names));
  return store;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('EMPTY list: keyboard survives adding the first item',
      (tester) async {
    final store = await _storeWith([]);
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue,
        reason: 'tapping Add item should open the keyboard');

    await tester.enterText(find.byType(TextField), 'Socks');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.byId('x')!.items.length, 1, reason: 'item should be added');
    expect(tester.testTextInput.isVisible, isTrue,
        reason: 'keyboard should stay up for the next item');
  });

  testWidgets('NON-EMPTY list: keyboard survives adding another item',
      (tester) async {
    final store = await _storeWith(['Toothbrush']);
    await tester.pumpWidget(_wrap(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(find.byType(TextField), 'Socks');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.byId('x')!.items.length, 2);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('EMPTY saved category: keyboard survives adding the first item',
      (tester) async {
    final store = AppStore();
    await store.load();
    store.savedCategories
        .insert(0, PackCategory(id: 'c', name: 'Toiletries', icon: '🧼'));

    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: const CategoryEditorScreen(categoryId: 'c'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(find.byType(TextField), 'Toothpaste');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.savedCategories.first.items.length, 1);
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
