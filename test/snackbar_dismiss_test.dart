import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

// A SnackBar that has a SnackBarAction ignores its `duration` in this Flutter
// version and won't auto-dismiss; _deleteItem works around that with a
// cancelable close timer. These guard that behaviour.

Widget _wrap(AppStore store, Widget child) {
  return ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: harborTheme(Harbor.light, Brightness.light),
      home: child,
    ),
  );
}

PackingList _listWith(List<String> names) => PackingList(
      id: 'x',
      name: 'Trip',
      icon: '🧳',
      items: [for (final name in names) Item(id: name, name: name)],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('delete-undo snackbar auto-dismisses after ~4s', (tester) async {
    final store = AppStore();
    await store.load();
    store.lists.insert(0, _listWith(['Toothbrush', 'Socks']));
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Toothbrush'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Item deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Item deleted'), findsNothing);
  });

  testWidgets('Undo restores the item and does not trip the close timer',
      (tester) async {
    final store = AppStore();
    await store.load();
    store.lists.insert(0, _listWith(['Toothbrush', 'Socks']));
    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'x')));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Toothbrush'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(store.byId('x')!.totalItems, 1); // deleted

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(store.byId('x')!.totalItems, 2); // restored

    // The auto-close timer was cancelled when the bar closed, so nothing
    // should fire (and crash) after the original 4s.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
