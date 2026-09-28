import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/category_editor.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// An item row has two tap targets: the checkbox packs, the name renames in
/// place. Swiping right does nothing; only swipe-left (delete) remains.

Widget _wrap(AppStore store, Widget home) =>
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: home,
      ),
    );

/// A flat list with Toothbrush and Socks unpacked, and Hat already packed.
Future<AppStore> _store() async {
  final store = AppStore();
  await store.load();
  store.lists.insert(
    0,
    PackingList(id: 'x', name: 'Trip', icon: '🧳', items: [
      Item(id: 'Toothbrush', name: 'Toothbrush'),
      Item(id: 'Socks', name: 'Socks'),
      Item(id: 'Hat', name: 'Hat', checked: true),
    ]),
  );
  return store;
}

Item _item(AppStore store, String id) =>
    store.byId('x')!.items.firstWhere((item) => item.id == id);

/// Somewhere on the list screen below every row, so a tap there is a plain
/// "tap outside" that lands on nothing else.
const _emptySpace = Offset(400, 560);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tapping the name opens an inline field and does not pack it',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Socks'));
    // Past the 350ms check-off beat, in case a tap had packed it.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Socks');
    expect(tester.testTextInput.isVisible, isTrue);
    expect(_item(store, 'Socks').checked, isFalse);
  });

  testWidgets('submitting saves the new name', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wool socks');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_item(store, 'Socks').name, 'Wool socks');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Wool socks'), findsOneWidget);
  });

  testWidgets('tapping outside saves; an emptied name keeps the old one',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wool socks');
    await tester.tapAt(_emptySpace);
    await tester.pumpAndSettle();
    expect(_item(store, 'Socks').name, 'Wool socks');
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Wool socks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tapAt(_emptySpace);
    await tester.pumpAndSettle();
    expect(_item(store, 'Socks').name, 'Wool socks');
    expect(store.byId('x')!.items, hasLength(3), reason: 'never deletes');
  });

  testWidgets('the checkbox packs an item', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('check-Socks')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(_item(store, 'Socks').checked, isTrue);
    expect(find.text('PACKED · 2'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a packed item: checkbox unpacks, name renames', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hat'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(_item(store, 'Hat').checked, isTrue, reason: 'still packed');

    await tester.enterText(find.byType(TextField), 'Sun hat');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_item(store, 'Hat').name, 'Sun hat');

    await tester.tap(find.byKey(const ValueKey('check-Hat')));
    await tester.pumpAndSettle();
    expect(_item(store, 'Hat').checked, isFalse);
  });

  testWidgets('swiping right does nothing', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Socks'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Socks'), findsOneWidget);
    expect(_item(store, 'Socks').checked, isFalse);
    expect(store.byId('x')!.items, hasLength(3));
  });

  testWidgets('the row does not change height when the field opens',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('item-Socks'));
    final before = tester.getSize(row);
    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();

    expect(tester.getSize(row), before);
  });

  testWidgets('going back mid-rename saves the edit', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_wrap(
      store,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ListScreen(listId: 'x'))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Socks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wool socks');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ListScreen), findsNothing);
    expect(_item(store, 'Socks').name, 'Wool socks');
  });

  testWidgets('saved-category editor: tap renames in place, swipe right does '
      'nothing', (tester) async {
    final store = AppStore();
    await store.load();
    store.savedCategories.insert(
      0,
      PackCategory(id: 'c', name: 'Toiletries', icon: '🧼', items: [
        Item(id: 't', name: 'Toothpaste'),
      ]),
    );
    await tester.pumpWidget(
        _wrap(store, const CategoryEditorScreen(categoryId: 'c')));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Toothpaste'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);

    final row = find.byKey(const ValueKey('item-t'));
    final before = tester.getSize(row);
    await tester.tap(find.text('Toothpaste'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.getSize(row), before);

    await tester.enterText(find.byType(TextField), 'Travel toothpaste');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.savedCategoryById('c')!.items.single.name, 'Travel toothpaste');
  });
}
